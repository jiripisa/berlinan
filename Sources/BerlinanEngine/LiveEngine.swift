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

        public var pattern: Pattern { voice.pattern }
    }

    private let project: Project
    private let legit: Legitimizer.Config
    private let velocity: VelocityPolicy
    private var schedule: TranspositionSchedule
    private var states: [VoiceState]           // stable order = project order
    private var renderedUpTo: Tick = 0
    private var pendingRecall: (tick: Tick, snapshot: StateSnapshot)? = nil
    /// Live-toggleable MIDI-delay state (FR-MOD-7), seeded from the project.
    private var delayConfigs: [String: MIDIDelayConfig] = [:]

    /// True when only the bass participates in transposition (bass reharm).
    private let bassOnly: Bool

    public init(project: Project) {
        self.project = project
        self.legit = project.legitimization ?? .default
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
        }
        public let voices: [VoiceSnapshot]
        /// The effective transposition timeline (incl. live-enqueued events)
        /// — for the harmony strip (FR-H-9).
        public let scheduleEvents: [TranspositionEvent]
    }

    public func snapshot() -> Snapshot {
        Snapshot(voices: states.map {
            Snapshot.VoiceSnapshot(id: $0.voice.id, role: $0.voice.role,
                                   pattern: $0.voice.pattern,
                                   blankActive: $0.blankActive,
                                   midiDelayEnabled: delayConfigs[$0.voice.id]?.enabled ?? false)
        }, scheduleEvents: schedule.events)
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
            let tick = max(requestTick, renderedUpTo)
            let bar = HarmonyEngine.quantizedEventBar(requestTick: tick,
                                                      meter: project.meter)
            pendingRecall = (tick: Tick(bar) * project.meter.ticksPerBar, snapshot)
        case .replacePattern(let voiceID, let pattern):
            withState(voiceID) { $0.replaceRequest = (tick: requestTick, pattern: pattern) }
        case .setMIDIDelay(let voiceID, let enabled):
            guard let role = states.first(where: { $0.voice.id == voiceID })?.voice.role
            else { return }
            var config = delayConfigs[voiceID] ?? MIDIDelayConfig(
                division: DelayHint.compute(role: role, bpm: project.bpm).division)
            config.enabled = enabled
            delayConfigs[voiceID] = config
        }
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
        }
    }

    private mutating func withState(_ id: String, _ body: (inout VoiceState) -> Void) {
        guard let idx = states.firstIndex(where: { $0.voice.id == id }) else { return }
        body(&states[idx])
    }

    // MARK: - Pull-model render

    /// Produce all events in the half-open window. Windows must be
    /// consecutive and non-overlapping; any sizes are fine (seam-safe).
    /// A pending snapshot recall splits the window at its (bar-quantized)
    /// bind tick.
    public mutating func render(range: Range<Tick>) -> [RenderedNote] {
        if let recall = pendingRecall, recall.tick < range.upperBound {
            var notes: [RenderedNote] = []
            if recall.tick > range.lowerBound {
                notes = renderWindow(range.lowerBound..<recall.tick)
            }
            applyRecall(recall.snapshot, at: recall.tick)
            pendingRecall = nil
            notes += render(range: max(recall.tick, range.lowerBound)..<range.upperBound)
            return notes
        }
        return renderWindow(range)
    }

    private mutating func renderWindow(_ range: Range<Tick>) -> [RenderedNote] {
        guard range.lowerBound < range.upperBound else { return [] }
        var notes: [RenderedNote] = []
        for idx in states.indices {
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
                    let segment = HarmonyEngine.render(voices: [state.voice],
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
