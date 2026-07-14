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
    }

    public struct VoiceState: Sendable {
        public internal(set) var voice: Voice
        var segmentStart: Tick = 0
        var generation: Int = 1
        var blankActive = false
        var blankRequestTick: Tick? = nil
        var regenerateRequestTick: Tick? = nil

        public var pattern: Pattern { voice.pattern }
    }

    private let project: Project
    private let legit: Legitimizer.Config
    private let velocity: VelocityPolicy
    private var schedule: TranspositionSchedule
    private var states: [VoiceState]           // stable order = project order
    private var renderedUpTo: Tick = 0

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
                                   blankActive: $0.blankActive)
        }, scheduleEvents: schedule.events)
    }

    /// Current transposition offset for a bar — includes live-enqueued events.
    public func transpositionOffset(atBar bar: Int) -> Int {
        schedule.offset(atBar: bar)
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
        }
    }

    private mutating func withState(_ id: String, _ body: (inout VoiceState) -> Void) {
        guard let idx = states.firstIndex(where: { $0.voice.id == id }) else { return }
        body(&states[idx])
    }

    // MARK: - Pull-model render

    /// Produce all events in the half-open window. Windows must be
    /// consecutive and non-overlapping; any sizes are fine (seam-safe).
    public mutating func render(range: Range<Tick>) -> [RenderedNote] {
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
                    notes += segment.map { n in
                        var out = n
                        let local = Tick(floorMod(Int(n.at + startOffset), Int(length)))
                        out.velocity = velocity.apply(velocity: n.velocity,
                                                      accent: n.accent,
                                                      patternSeed: humanSeed,
                                                      localPosition: local)
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
        }
    }
}
