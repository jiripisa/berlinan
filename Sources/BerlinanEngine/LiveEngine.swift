/// The pull-model live engine (spec §5.2): the scheduler asks for consecutive
/// tick windows; the engine deterministically produces events and consumes
/// quantized actions at their binding points. Wall-clock time never enters —
/// the Runtime owns that mapping.
public struct LiveEngine: Sendable {

    /// User actions the engine binds at quantized musical points. Runtime
    /// mute/solo is deliberately NOT here — it is a post-render gate in the
    /// Runtime layer (spec §8.2) so it can act in ≤ 20 ms.
    public enum Action: Equatable, Sendable {
        /// Global diatonic transposition; binds at the next bar (FR-H-3).
        case transpose(degreeOffset: Int)
        /// New pattern for the voice; binds at its next loop boundary.
        case regenerate(voiceID: String)
        /// One silent loop; the voice re-enters automatically (FR-V-4).
        case blankCycle(voiceID: String)
        /// Freeze/unfreeze against all mutation and regeneration; immediate.
        case setLock(voiceID: String, on: Bool)
        /// Restore a captured state; binds at the next bar — all loops
        /// re-align there (FR-L-6).
        case recallSnapshot(StateSnapshot)
        /// Hand-edited pattern (FR-P-7); binds at the voice's next loop
        /// boundary and arrives locked + established.
        case replacePattern(voiceID: String, pattern: Pattern)
        /// Toggle the MIDI delay (FR-MOD-7); binds at the render head
        /// (≤ lookahead latency).
        case setMIDIDelay(voiceID: String, enabled: Bool)
        /// Runtime key change (FR-GS-5); binds at the next bar. Degree-space
        /// patterns re-root instantly; sounding notes keep their offs.
        case setKey(Key)
        /// Arrangement autopilot on/off (FR-A-6); binds at the next bar.
        /// Enabling mid-play adopts the running ensemble.
        case setArrangementEnabled(Bool)
        /// Fire the arranger's next change at the next bar ("advance now",
        /// FR-A-6). No-op while the autopilot is off.
        case advancePhase
        /// Density macro 0–1 (FR-A-3); binds at the next bar.
        case setDensity(Double)
        /// The S4 move (FR-A-5): progression + bass swap (+ bed drop) as one
        /// event; binds at the next bar. Uses `Project.bPart` (or defaults).
        case fireBPart
        /// Engine-level voice on/off (FR-A-6 manual override of the
        /// arranger's activation); binds at the next bar.
        case setVoiceActive(voiceID: String, on: Bool)
        /// Melody extraction toggle (FR-MEL-1); binds at the voice's next
        /// loop boundary. On: mute-all + 3–4 curated accents, evolving on
        /// the manual's clock. Off: the source pattern returns verbatim.
        case extractMelody(voiceID: String)
        /// Copy the voice's current melody to the lead voice as a locked
        /// legato line (FR-MEL-2); binds at the next bar. No lead → no-op.
        case promoteToLead(voiceID: String)
    }

    /// Bar-quantized global changes that split the render window.
    private enum GlobalChange: Sendable {
        case recall(StateSnapshot)
        case key(Key)
        case density(Double)
        case bPart
        case voiceActive(String, Bool)
        case promoteToLead(String)
    }

    /// The complete recallable generative state (FR-L-6): patterns (inside
    /// their voices), generation counters, and the transposition timeline.
    /// Codable — phase 19 persists these into documents.
    public struct StateSnapshot: Codable, Equatable, Sendable {
        public var voices: [Voice]
        public var generations: [String: Int]
        public var schedule: TranspositionSchedule
    }

    public struct VoiceState: Sendable {
        public internal(set) var voice: Voice
        var segmentStart: Tick = 0
        var generation: Int = 1
        var blankActive = false
        var blankRequestTick: Tick? = nil
        var regenerateRequestTick: Tick? = nil
        var replaceRequest: (tick: Tick, pattern: Pattern)? = nil
        var accumBase: Int? = nil
        var accumCycle = 0
        /// Arrangement activation (FR-A-1/2): inactive voices render nothing
        /// and their loop position freezes; activation restarts the loop at
        /// the activation bar.
        var active = true
        /// Arrangement pattern requests (FR-A-1) bind at the next loop
        /// boundary after their bar — like every user action.
        var nudgeRequestTick: Tick? = nil
        var accentMoveRequestTick: Tick? = nil
        /// Melody extraction (FR-MEL-1): the running technique's state.
        struct MelodyState: Sendable {
            var source: Pattern
            var picks: Set<Int>
            var startTick: Tick
            /// 0 = initial pick · 1 = inverted · 2+ = growth count + 1.
            var stage: Int
        }
        var melody: MelodyState? = nil
        var melodyToggleRequestTick: Tick? = nil

        public var melodyActive: Bool { melody != nil }

        public var pattern: Pattern { voice.pattern }
    }

    /// Mutable: runtime key changes (FR-GS-5) rewrite `project.key` so every
    /// downstream consumer (resolution, mutation, regeneration) follows.
    private var project: Project
    private let legit: Legitimizer.Config
    /// Density macro (FR-A-3): a deterministic per-loop note cap, 0–1.
    private var density: Double
    private let velocity: VelocityPolicy
    private var schedule: TranspositionSchedule
    private var states: [VoiceState]           // stable order = project order
    private var renderedUpTo: Tick = 0
    /// Bar-quantized global changes, ordered by bind tick (stable insertion).
    private var pendingChanges: [(tick: Tick, change: GlobalChange)] = []
    /// Live-toggleable MIDI-delay state (FR-MOD-7), seeded from the project.
    private var delayConfigs: [String: MIDIDelayConfig] = [:]

    // MARK: Arrangement (FR-A-1/2/6, phase 26)

    /// The autopilot; nil = performance mode (the default).
    private var arrangement: ArrangementSM? = nil
    /// First bar-boundary tick not yet processed (chunk-safety cursor).
    private var arrangementCursor: Tick = 0
    /// Bar-quantized "advance now" bind ticks, sorted.
    private var pendingAdvances: [Tick] = []
    /// Bar-quantized enable/disable requests, sorted by bind tick.
    private var pendingArrangementEnables: [(tick: Tick, on: Bool)] = []
    /// Set when the arranger's ending fires: nothing renders at/after this
    /// bar-aligned tick — the Runtime stops the transport there.
    public private(set) var pendingStopTick: Tick? = nil

    /// True when only the bass participates in transposition (bass reharm).
    private let bassOnly: Bool

    public init(project: Project) {
        var project = project
        if let arrangement = project.arrangement, arrangement.enabled,
           arrangement.ambientMode {
            // Ambient (FR-A-4): the slow world — patterns earn much longer.
            // Scaled at the PROJECT level so materialization (initial
            // lifecycle) and every mutate reset see the same 16/32 counts.
            let base = project.legitimization ?? .default
            project.legitimization = Legitimizer.Config(
                repeats: min(32, base.repeats * 4),
                ratchetProbability: base.ratchetProbability)
        }
        self.project = project
        self.legit = project.legitimization ?? .default
        self.density = max(0, min(1, project.density ?? 1))
        self.velocity = project.velocity ?? VelocityPolicy()
        let resolved = HarmonyScheduler.resolve(project: project)
        self.schedule = resolved.schedule
        self.bassOnly = resolved.bassOnly
        self.states = project.voices.map {
            VoiceState(voice: OfflineRenderer.materialize($0, project: project))
        }
        for config in project.voices {
            if let delay = config.midiDelay {
                delayConfigs[config.id] = delay
            }
        }
        if let config = project.arrangement, config.enabled {
            let sm = ArrangementSM(
                config: config, voices: project.voices,
                seed: SeedStream.derive(master: project.masterSeed, "arrangement"),
                ambientPeriodBars: Self.ambientPeriodBars(project: project))
            arrangement = sm
            let active = Set(sm.activeVoices)
            for idx in states.indices where !active.contains(states[idx].voice.id) {
                states[idx].active = false
            }
        }
    }

    public func voiceState(id: String) -> VoiceState? {
        states.first { $0.voice.id == id }
    }

    // MARK: - UI snapshot (spec §5.4 — read-only mirror for the app layer)

    public struct Snapshot: Sendable {
        public struct VoiceSnapshot: Sendable {
            public let id: String
            public let role: VoiceRole
            public let pattern: Pattern
            public let blankActive: Bool
            public let midiDelayEnabled: Bool
            /// Melody extraction running on this voice (FR-MEL-1).
            public let melodyActive: Bool
        }
        public let voices: [VoiceSnapshot]
        /// The effective transposition timeline (incl. live-enqueued events)
        /// — for the harmony strip (FR-H-9).
        public let scheduleEvents: [TranspositionEvent]
        /// The effective key (tracks runtime key changes, FR-GS-5).
        public let key: Key
        /// Arrangement autopilot mirror (FR-A-1); nil = performance mode.
        public let arrangement: ArrangementStatus?
        /// Density macro in force (FR-A-3), 0–1.
        public let density: Double
    }

    public struct ArrangementStatus: Equatable, Sendable {
        public let phase: ArrangementPhase
        public let barsInPhase: Int
        public let activeVoices: [String]
    }

    public func snapshot() -> Snapshot {
        Snapshot(voices: states.map {
            Snapshot.VoiceSnapshot(id: $0.voice.id, role: $0.voice.role,
                                   pattern: $0.voice.pattern,
                                   blankActive: $0.blankActive,
                                   midiDelayEnabled: delayConfigs[$0.voice.id]?.enabled ?? false,
                                   melodyActive: $0.melodyActive)
        }, scheduleEvents: schedule.events, key: project.key,
           arrangement: arrangement.map {
               ArrangementStatus(phase: $0.phase, barsInPhase: $0.barsInPhase,
                                 activeVoices: $0.activeVoices)
           },
           density: density)
    }

    /// Current transposition offset for a bar — includes live-enqueued events.
    public func transpositionOffset(atBar bar: Int) -> Int {
        schedule.offset(atBar: bar)
    }

    /// CC lanes for a window (FR-MOD-3/4). Stateless and chunk-safe — the
    /// scheduler calls it alongside `render` with the same windows.
    public func renderCC(range: Range<Tick>) -> [RenderedCC] {
        project.voices.flatMap { config in
            ModulationEngine.render(
                lanes: config.ccLanes ?? [], ccMap: config.ccMap ?? [:],
                voiceID: config.id, in: range, meter: project.meter,
                seed: SeedStream.derive(master: project.masterSeed,
                                        "voice", config.id, "cc"))
        }
    }

    // MARK: - Actions

    public mutating func enqueue(_ action: Action, atTick requestTick: Tick) {
        switch action {
        case .transpose(let degreeOffset):
            // Bind at the next bar; never rewrite bars that already rendered.
            let tick = max(requestTick, renderedUpTo)
            let bar = HarmonyEngine.quantizedEventBar(requestTick: tick,
                                                      meter: project.meter)
            schedule = TranspositionSchedule(
                events: schedule.events + [TranspositionEvent(bar: bar,
                                                              degreeOffset: degreeOffset)])
        case .regenerate(let voiceID):
            withState(voiceID) { $0.regenerateRequestTick = requestTick }
        case .blankCycle(let voiceID):
            withState(voiceID) { $0.blankRequestTick = requestTick }
        case .setLock(let voiceID, let on):
            withState(voiceID) { $0.voice.pattern.locked = on }
        case .recallSnapshot(let snapshot):
            enqueueGlobalChange(.recall(snapshot), requestTick: requestTick)
        case .setKey(let key):
            enqueueGlobalChange(.key(key), requestTick: requestTick)
        case .replacePattern(let voiceID, let pattern):
            withState(voiceID) { $0.replaceRequest = (tick: requestTick, pattern: pattern) }
        case .setDensity(let value):
            enqueueGlobalChange(.density(value), requestTick: requestTick)
        case .fireBPart:
            enqueueGlobalChange(.bPart, requestTick: requestTick)
        case .setVoiceActive(let voiceID, let on):
            enqueueGlobalChange(.voiceActive(voiceID, on), requestTick: requestTick)
        case .extractMelody(let voiceID):
            withState(voiceID) { $0.melodyToggleRequestTick = requestTick }
        case .promoteToLead(let voiceID):
            enqueueGlobalChange(.promoteToLead(voiceID), requestTick: requestTick)
        case .setArrangementEnabled(let on):
            let tick = barBindTick(requestTick)
            let index = pendingArrangementEnables.firstIndex { $0.tick > tick }
                ?? pendingArrangementEnables.count
            pendingArrangementEnables.insert((tick: tick, on: on), at: index)
        case .advancePhase:
            let tick = barBindTick(requestTick)
            let index = pendingAdvances.firstIndex { $0 > tick } ?? pendingAdvances.count
            pendingAdvances.insert(tick, at: index)
        case .setMIDIDelay(let voiceID, let enabled):
            guard let role = states.first(where: { $0.voice.id == voiceID })?.voice.role
            else { return }
            var config = delayConfigs[voiceID] ?? MIDIDelayConfig(
                division: DelayHint.compute(role: role, bpm: project.bpm).division)
            config.enabled = enabled
            delayConfigs[voiceID] = config
        }
    }

    /// Next-bar bind tick, never rewriting bars that already rendered.
    private func barBindTick(_ requestTick: Tick) -> Tick {
        let tick = max(requestTick, renderedUpTo)
        let bar = HarmonyEngine.quantizedEventBar(requestTick: tick,
                                                  meter: project.meter)
        return Tick(bar) * project.meter.ticksPerBar
    }

    private mutating func enqueueGlobalChange(_ change: GlobalChange,
                                              requestTick: Tick) {
        let bindTick = barBindTick(requestTick)
        let index = pendingChanges.firstIndex { $0.tick > bindTick }
            ?? pendingChanges.count
        pendingChanges.insert((tick: bindTick, change: change), at: index)
    }

    /// Capture the complete generative state (FR-L-6).
    public func captureState() -> StateSnapshot {
        StateSnapshot(
            voices: states.map(\.voice),
            generations: Dictionary(uniqueKeysWithValues:
                states.map { ($0.voice.id, $0.generation) }),
            schedule: schedule)
    }

    private mutating func applyRecall(_ snapshot: StateSnapshot, at tick: Tick) {
        schedule = snapshot.schedule
        for idx in states.indices {
            let id = states[idx].voice.id
            if let voice = snapshot.voices.first(where: { $0.id == id }) {
                states[idx].voice = voice
            }
            states[idx].generation = snapshot.generations[id] ?? states[idx].generation
            states[idx].segmentStart = tick        // all loops re-align (bar-quantized)
            states[idx].blankActive = false
            states[idx].blankRequestTick = nil
            states[idx].regenerateRequestTick = nil
            states[idx].accumBase = nil
            states[idx].accumCycle = 0
            states[idx].melody = nil               // recall exits the technique
            states[idx].melodyToggleRequestTick = nil
        }
    }

    private mutating func withState(_ id: String, _ body: (inout VoiceState) -> Void) {
        guard let idx = states.firstIndex(where: { $0.voice.id == id }) else { return }
        body(&states[idx])
    }

    // MARK: - Pull-model render

    /// Produce all events in the half-open window. Windows must be
    /// consecutive and non-overlapping; any sizes are fine (seam-safe).
    /// With the arrangement autopilot on (or pending), the window splits at
    /// every bar boundary so the SM ticks exactly once per bar — and nothing
    /// renders at/after a requested stop (FR-A-1 ending).
    public mutating func render(range: Range<Tick>) -> [RenderedNote] {
        var range = range
        if let stop = pendingStopTick {
            guard range.lowerBound < stop else { return [] }
            range = range.lowerBound..<min(range.upperBound, stop)
        }
        guard arrangement != nil || !pendingArrangementEnables.isEmpty else {
            return renderResolvingChanges(range)
        }
        let barTicks = project.meter.ticksPerBar
        var notes: [RenderedNote] = []
        var t = range.lowerBound
        while t < range.upperBound {
            if t % barTicks == 0 { processArrangementBoundary(at: t) }
            if let stop = pendingStopTick, t >= stop { break }
            var end = min(range.upperBound, (t / barTicks + 1) * barTicks)
            if let stop = pendingStopTick { end = min(end, stop) }
            notes += renderResolvingChanges(t..<end)
            t = end
        }
        return notes
    }

    /// Pending global changes (recall, key) split the window at their
    /// bar-quantized bind ticks, in queue order.
    private mutating func renderResolvingChanges(_ range: Range<Tick>) -> [RenderedNote] {
        if let next = pendingChanges.first, next.tick < range.upperBound {
            var notes: [RenderedNote] = []
            if next.tick > range.lowerBound {
                notes = renderWindow(range.lowerBound..<next.tick)
            }
            pendingChanges.removeFirst()
            switch next.change {
            case .recall(let snapshot):
                applyRecall(snapshot, at: next.tick)
            case .key(let key):
                project.key = key       // everything downstream follows
            case .density(let value):
                density = max(0, min(1, value))
            case .bPart:
                applyBPart(at: next.tick)
            case .voiceActive(let id, let on):
                withState(id) {
                    $0.active = on
                    if on { $0.segmentStart = next.tick; $0.blankActive = false }
                }
            case .promoteToLead(let id):
                applyPromotion(from: id, at: next.tick)
            }
            notes += renderResolvingChanges(
                max(next.tick, range.lowerBound)..<range.upperBound)
            return notes
        }
        return renderWindow(range)
    }

    // MARK: - Arrangement boundary (FR-A-1/2/6)

    /// Runs once per bar-boundary tick (the cursor guards against chunked
    /// windows revisiting a boundary): consume due enable/disable requests,
    /// then due manual advances, then the SM's own bar clock.
    private mutating func processArrangementBoundary(at tick: Tick) {
        guard tick >= arrangementCursor else { return }
        arrangementCursor = tick + 1
        var createdHere = false
        while let first = pendingArrangementEnables.first, first.tick <= tick {
            pendingArrangementEnables.removeFirst()
            if first.on && arrangement == nil {
                var config = project.arrangement ?? ArrangementConfig()
                config.enabled = true
                arrangement = ArrangementSM(
                    config: config, voices: project.voices,
                    seed: SeedStream.derive(master: project.masterSeed, "arrangement"),
                    adoptingActive: Set(states.filter(\.active).map(\.voice.id)),
                    ambientPeriodBars: Self.ambientPeriodBars(project: project))
                createdHere = true
            } else if !first.on {
                arrangement = nil       // voices keep their current activity
            }
        }
        guard var sm = arrangement else { return }
        let locked = Set(states.filter { $0.voice.pattern.locked }.map(\.voice.id))
        while let first = pendingAdvances.first, first <= tick {
            pendingAdvances.removeFirst()
            applyDirectives(sm.advance(locked: locked), at: tick)
        }
        if tick > 0 && !createdHere {
            applyDirectives(sm.tickBar(locked: locked), at: tick)
        }
        arrangement = sm
    }

    /// ≈ bars per minute at the project tempo (FR-A-4), floored at 8.
    private static func ambientPeriodBars(project: Project) -> Int {
        let barsPerMinute = project.bpm / Double(project.meter.beatsPerBar)
        return max(8, Int(barsPerMinute.rounded()))
    }

    /// The S4 move (FR-A-5): append the progression walk from the fire bar,
    /// regenerate the bass at its next loop boundary, optionally drop the
    /// second bed (manual reactivation via `setVoiceActive`, or the
    /// arranger's payoff re-add).
    private mutating func applyBPart(at tick: Tick) {
        let config = project.bPart ?? .default
        let fireBar = Int(tick / project.meter.ticksPerBar)
        var events = schedule.events
        for (index, step) in config.progressionSteps.enumerated() {
            events.append(TranspositionEvent(bar: fireBar + index * config.barsPerStep,
                                             degreeOffset: step))
        }
        schedule = TranspositionSchedule(events: events)
        if config.swapBass {
            for idx in states.indices where states[idx].voice.role == .bass {
                states[idx].regenerateRequestTick = tick
            }
        }
        if config.dropBed {
            for idx in states.indices where states[idx].voice.role == .bedPluck2 {
                states[idx].active = false
            }
        }
    }

    /// Lead promotion (FR-MEL-2): the source voice's current melody becomes
    /// the lead's pattern via the replace path (locked + established at the
    /// lead's next loop boundary).
    private mutating func applyPromotion(from voiceID: String, at tick: Tick) {
        guard let source = states.first(where: { $0.voice.id == voiceID }),
              let melody = source.melody,
              let leadIdx = states.firstIndex(where: { $0.voice.role == .lead })
        else { return }
        let lead = Melody.leadPattern(from: melody.source, picks: melody.picks,
                                      meter: project.meter)
        states[leadIdx].replaceRequest = (tick: tick, pattern: lead)
    }

    private mutating func applyDirectives(_ directives: [ArrangementDirective],
                                          at tick: Tick) {
        for directive in directives {
            switch directive {
            case .activate(let id):
                withState(id) {
                    $0.active = true
                    $0.segmentStart = tick     // the loop restarts on the bar
                    $0.blankActive = false
                }
            case .deactivate(let id):
                withState(id) { $0.active = false }
            case .nudgeMutation(let id):
                withState(id) { $0.nudgeRequestTick = tick }
            case .accentMove(let id):
                withState(id) { $0.accentMoveRequestTick = tick }
            case .blankCycle(let id):
                withState(id) { $0.blankRequestTick = tick }
            case .setDensity(let value):
                density = max(0, min(1, value))
            case .fireBPart:
                applyBPart(at: tick)
            case .thinToRoots(let id):
                // Immediate: the directive already fires exactly on the bar
                // the ending begins — roots sound from this tick on.
                withState(id) {
                    $0.voice.pattern = PatternOps.thinToRoots($0.voice.pattern)
                }
            case .requestStop:
                pendingStopTick = tick
            }
        }
    }

    private mutating func renderWindow(_ range: Range<Tick>) -> [RenderedNote] {
        guard range.lowerBound < range.upperBound else { return [] }
        var notes: [RenderedNote] = []
        for idx in states.indices {
            guard states[idx].active else { continue }   // arrangement (FR-A-1)
            var state = states[idx]
            notes += renderVoice(&state, range: range)
            states[idx] = state
        }
        renderedUpTo = max(renderedUpTo, range.upperBound)
        notes.sort {
            if $0.at != $1.at { return $0.at < $1.at }
            if $0.voiceID != $1.voiceID { return $0.voiceID < $1.voiceID }
            return $0.midiNote < $1.midiNote
        }
        return notes
    }

    private func renderVoice(_ state: inout VoiceState,
                             range: Range<Tick>) -> [RenderedNote] {
        var notes: [RenderedNote] = []
        while state.segmentStart < range.upperBound {
            let length = state.voice.pattern.length
            let segmentEnd = state.segmentStart + length

            if !state.blankActive {
                let lower = max(state.segmentStart, range.lowerBound)
                let upper = min(segmentEnd, range.upperBound)
                if lower < upper {
                    let humanSeed = state.voice.pattern.provenance.seed
                    let startOffset = state.voice.pattern.startOffset
                    var renderSource = state.voice
                    if density < 1 {                       // FR-A-3 note cap
                        renderSource.pattern = PatternOps.densityCap(
                            renderSource.pattern, density: density,
                            meter: project.meter)
                    }
                    let segment = HarmonyEngine.render(voices: [renderSource],
                                                       schedule: schedule,
                                                       key: project.key,
                                                       meter: project.meter,
                                                       in: lower..<upper)
                    let stretchBassGates = bassOnly && state.voice.role == .bass
                    let gateRamp = project.voices
                        .first { $0.id == state.voice.id }?.gateRamp
                    notes += segment.map { n in
                        var out = n
                        let local = Tick(floorMod(Int(n.at + startOffset), Int(length)))
                        out.velocity = velocity.apply(velocity: n.velocity,
                                                      accent: n.accent,
                                                      patternSeed: humanSeed,
                                                      localPosition: local)
                        if let ramp = gateRamp {
                            let barIndex = Int(n.at / project.meter.ticksPerBar)
                            let multiplier = ramp.profile[barIndex % ramp.profile.count]
                            out.gate = max(1, Tick(Double(out.gate) * multiplier))
                        }
                        if stretchBassGates {
                            out.gate = max(out.gate, project.meter.ticksPerBeat)
                        }
                        return out
                    }
                }
            }

            guard segmentEnd <= range.upperBound else { break }
            processBoundary(&state, at: segmentEnd)
            state.segmentStart = segmentEnd
        }
        // Output boundary: MIDI-delay echoes (FR-MOD-7).
        if let delay = delayConfigs[state.voice.id], delay.enabled {
            notes = MIDIDelay.process(notes, config: delay)
        }
        return notes
    }

    /// Loop-boundary bookkeeping — the ONLY place patterns change (spec §7.4).
    private func processBoundary(_ state: inout VoiceState, at tick: Tick) {
        let wasBlank = state.blankActive
        state.blankActive = false

        // 1. The finished segment counts toward legitimization only if it was
        //    audible — an unheard play must not legitimize anything.
        if !wasBlank {
            state.voice.pattern = Legitimizer.advanceAtLoopBoundary(state.voice.pattern)
        }

        // 2. A due blank cycle freezes everything else at this boundary.
        if let request = state.blankRequestTick, tick >= request {
            state.blankRequestTick = nil
            state.blankActive = true
            return
        }

        // 2b. Hand-edited replacement (FR-P-7) takes top priority: it arrives
        //     locked and established — the producer's word is final.
        if let request = state.replaceRequest, tick >= request.tick {
            state.replaceRequest = nil
            state.regenerateRequestTick = nil
            var pattern = request.pattern
            pattern.locked = true
            pattern.lifecycle = .established
            state.voice.pattern = pattern
            state.accumBase = nil
            state.accumCycle = 0
            return
        }

        // 2c'. Melody extraction toggle (FR-MEL-1): on = curated accents
        //      only (locked; the melody engine owns evolution); off = the
        //      stored source returns verbatim.
        if let request = state.melodyToggleRequestTick, tick >= request {
            state.melodyToggleRequestTick = nil
            if let melody = state.melody {
                state.voice.pattern = melody.source
                state.melody = nil
            } else {
                let seed = SeedStream.derive(master: project.masterSeed,
                                             "voice", state.voice.id,
                                             "melody", String(state.generation))
                let picks = Melody.selectAccents(pattern: state.voice.pattern,
                                                 key: project.key,
                                                 meter: project.meter, seed: seed)
                state.melody = VoiceState.MelodyState(
                    source: state.voice.pattern, picks: picks,
                    startTick: tick, stage: 0)
                state.voice.pattern = Melody.extraction(
                    from: state.voice.pattern, picks: picks, stage: 0)
            }
            return
        }

        // 2c''. Melody evolution (M §8.1): 2-bar inversion, then one growth
        //       note every 4 bars — the manual's clock, exempt from Law 1.
        if var melody = state.melody {
            let barsSince = Int((tick - melody.startTick) / project.meter.ticksPerBar)
            if melody.stage == 0 && barsSince >= 2 {
                let seed = SeedStream.derive(master: project.masterSeed,
                                             "voice", state.voice.id,
                                             "melody-invert")
                melody.picks = Melody.invertAccents(pattern: melody.source,
                                                    previous: melody.picks,
                                                    meter: project.meter, seed: seed)
                melody.stage = 1
                state.voice.pattern = Melody.extraction(from: melody.source,
                                                        picks: melody.picks, stage: 1)
                state.melody = melody
                return
            }
            if melody.stage >= 1, barsSince >= 4 * melody.stage,
               let addition = Melody.growthPick(pattern: melody.source,
                                                current: melody.picks,
                                                meter: project.meter) {
                melody.picks.insert(addition)
                melody.stage += 1
                state.voice.pattern = Melody.extraction(from: melody.source,
                                                        picks: melody.picks,
                                                        stage: melody.stage)
                state.melody = melody
                return
            }
        }

        // 2c. Arrangement accent move (FR-A-1 variation): counts as the
        //     cycle's one change — lifecycle restarts like any mutation.
        if let request = state.accentMoveRequestTick, tick >= request {
            state.accentMoveRequestTick = nil
            if !state.voice.pattern.locked {
                let seed = SeedStream.derive(master: project.masterSeed,
                                             "voice", state.voice.id,
                                             "accentMove", String(state.generation))
                var pattern = PatternOps.moveAccents(state.voice.pattern, seed: seed)
                pattern.lifecycle = .repeating(remaining: legit.repeats - 1)
                state.voice.pattern = pattern
                state.generation += 1
                return
            }
        }

        // 2d. Arrangement mutation nudge (FR-A-1 bed): fast-forward the
        //     remaining verbatim plays so step 4 mutates at this boundary.
        //     The arranger waited 8–16 bars — legitimization is served.
        if let request = state.nudgeRequestTick, tick >= request {
            state.nudgeRequestTick = nil
            if !state.voice.pattern.locked {
                state.voice.pattern.lifecycle = .established
            }
        }

        // 3. Regenerate (user action) beats auto-mutation; ignored while locked.
        if let request = state.regenerateRequestTick, tick >= request {
            state.regenerateRequestTick = nil
            if !state.voice.pattern.locked {
                let config = project.voices.first { $0.id == state.voice.id }!
                state.voice.pattern = OfflineRenderer.makePattern(
                    config, project: project,
                    seedLabels: ["voice", config.id, "regen", String(state.generation)],
                    idSuffix: "regen\(state.generation)")
                state.generation += 1
                return
            }
        }

        // 4. Auto-mutation, exactly as the offline renderer does it.
        if Legitimizer.isMutable(state.voice.pattern) {
            let seed = SeedStream.derive(master: project.masterSeed,
                                         "voice", state.voice.id,
                                         "mut", String(state.generation))
            state.voice = Legitimizer.mutate(state.voice, key: project.key,
                                             meter: project.meter, seed: seed,
                                             config: legit)
            state.generation += 1
            state.accumBase = nil            // drift restarts on new material
            state.accumCycle = 0
        }

        // 5. Accumulator drift (FR-L-4) — mirrors the offline renderer.
        if let accumulator = project.voices
            .first(where: { $0.id == state.voice.id })?.accumulator {
            if state.accumBase == nil {
                state.accumBase = Legitimizer.accumulatorBase(of: state.voice.pattern)
                state.accumCycle = 0
            }
            state.accumCycle += 1
            Legitimizer.applyAccumulatorDrift(&state.voice.pattern,
                                              base: state.accumBase!,
                                              cycle: state.accumCycle,
                                              config: accumulator)
        }
    }
}
