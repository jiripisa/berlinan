/// The arrangement state machine (FR-A-1/2/6, M §12, spec §7.8): an advisory
/// autopilot that walks `build → bed → variation → bPart → payoff → subtract
/// → ending`, emitting directives the LiveEngine already knows how to obey
/// (voice activation, mutation nudges, blank cycles, root thinning, stop).
/// Pure and deterministic: change periods come from a SplitMix64 stream
/// derived off the master seed, so live and offline renders stay identical.

public enum ArrangementPhase: String, Codable, Sendable, CaseIterable {
    case build, bed, variation, bPart, payoff, subtract, ending
}

public struct ArrangementConfig: Codable, Equatable, Sendable {
    /// OFF by default — performance mode is the first-run experience
    /// (user decision 2026-07-17; FR-A-6).
    public var enabled: Bool
    /// Voice ids in additive build order; nil = derive from roles (FR-A-2).
    public var buildOrder: [String]?
    /// Timed change period range in bars (M §12.1: 8–16 by default).
    public var minPeriodBars: Int
    public var maxPeriodBars: Int
    /// ~1 change/minute + scaled legitimization — wired in phase 27 (FR-A-4).
    public var ambientMode: Bool

    public init(enabled: Bool = false, buildOrder: [String]? = nil,
                minPeriodBars: Int = 8, maxPeriodBars: Int = 16,
                ambientMode: Bool = false) {
        precondition(minPeriodBars >= 1 && minPeriodBars <= maxPeriodBars,
                     "period range must be 1 ≤ min ≤ max")
        self.enabled = enabled
        self.buildOrder = buildOrder
        self.minPeriodBars = minPeriodBars
        self.maxPeriodBars = maxPeriodBars
        self.ambientMode = ambientMode
    }
}

/// One bar-quantized instruction to the engine. The SM never touches
/// patterns itself — it only asks for things the engine can already do.
public enum ArrangementDirective: Equatable, Sendable {
    case activate(voiceID: String)
    case deactivate(voiceID: String)
    /// Let the voice's next loop boundary mutate (Law 1 still gates it).
    case nudgeMutation(voiceID: String)
    case accentMove(voiceID: String)
    case blankCycle(voiceID: String)
    /// Ending: strip the survivor to root notes only (M §12.4).
    case thinToRoots(voiceID: String)
    /// Ending: stop the transport at the next bar boundary.
    case requestStop
}

public struct ArrangementSM: Sendable {

    public private(set) var phase: ArrangementPhase
    /// Bars elapsed since entering the current phase (UI display).
    public private(set) var barsInPhase: Int = 0
    /// Currently active voices, in build order.
    public private(set) var activeVoices: [String]

    private let config: ArrangementConfig
    private let buildOrder: [String]
    private var rng: SplitMix64
    private var barsUntilChange: Int = 0
    /// Change events consumed inside the current phase (dwell bookkeeping).
    private var eventsInPhase = 0
    private var roundRobin = 0
    private var stopRequested = false

    /// Default additive order (FR-A-2): beds → pad → bass → lead, then any
    /// remaining roles in declaration order.
    public static func deriveBuildOrder(from voices: [VoiceConfig]) -> [String] {
        let rank: [VoiceRole: Int] = [.bedPluck1: 0, .bedPluck2: 1, .pad: 2,
                                      .bass: 3, .lead: 4]
        return voices.enumerated()
            .sorted { a, b in
                let ra = rank[a.element.role] ?? (5 + a.offset)
                let rb = rank[b.element.role] ?? (5 + b.offset)
                return ra != rb ? ra < rb : a.offset < b.offset
            }
            .map(\.element.id)
    }

    public init(config: ArrangementConfig, voices: [VoiceConfig], seed: UInt64,
                adoptingActive: Set<String>? = nil) {
        self.config = config
        self.buildOrder = config.buildOrder
            ?? ArrangementSM.deriveBuildOrder(from: voices)
        self.rng = SplitMix64(seed: seed)
        if let adopted = adoptingActive {
            // Enabling mid-play adopts the running state (FR-A-6): nothing
            // restarts; with everything already sounding there is no intro
            // left to build — settle into the bed.
            self.activeVoices = buildOrder.filter(adopted.contains)
            self.phase = activeVoices.count == buildOrder.count ? .bed : .build
        } else {
            self.activeVoices = Array(buildOrder.prefix(1))
            self.phase = .build
        }
        self.barsUntilChange = nextPeriod()
    }

    // MARK: - Clocking

    /// Called once per bar boundary. Returns directives when a timed change
    /// period elapses (usually none).
    public mutating func tickBar(locked: Set<String> = []) -> [ArrangementDirective] {
        guard config.enabled, !stopRequested else { return [] }
        barsInPhase += 1
        barsUntilChange -= 1
        guard barsUntilChange <= 0 else { return [] }
        barsUntilChange = nextPeriod()
        return changeEvent(locked: locked)
    }

    /// The "advance now" button / MIDI macro (FR-A-6): fire the next change
    /// immediately and restart the period clock.
    public mutating func advance(locked: Set<String> = []) -> [ArrangementDirective] {
        guard !stopRequested else { return [] }
        barsUntilChange = nextPeriod()
        return changeEvent(locked: locked)
    }

    private mutating func nextPeriod() -> Int {
        Int.random(in: config.minPeriodBars...config.maxPeriodBars, using: &rng)
    }

    // MARK: - Change events (spec §7.8 advance())

    /// Dwell per phase, in change events.
    private static let dwell: [ArrangementPhase: Int] = [
        .bed: 3, .variation: 3, .bPart: 1, .payoff: 1,
    ]

    private mutating func changeEvent(locked: Set<String>) -> [ArrangementDirective] {
        switch phase {
        case .build:
            if let next = buildOrder.first(where: { !activeVoices.contains($0) }) {
                activeVoices.append(next)
                return [.activate(voiceID: next)]
            }
            return enter(.bed, locked: locked)

        case .bed:
            if eventsInPhase >= Self.dwell[.bed]! {
                return enter(.variation, locked: locked)
            }
            eventsInPhase += 1
            guard let target = nextTarget(locked: locked) else { return [] }
            return [.nudgeMutation(voiceID: target)]

        case .variation, .bPart:
            // bPart acts like variation until the B-bundle lands (phase 27).
            if eventsInPhase >= Self.dwell[phase]! {
                return enter(phase == .variation ? .bPart : .payoff, locked: locked)
            }
            eventsInPhase += 1
            guard let target = nextTarget(locked: locked) else { return [] }
            switch eventsInPhase % 3 {
            case 1: return [.nudgeMutation(voiceID: target)]
            case 2: return [.accentMove(voiceID: target)]
            default: return [.blankCycle(voiceID: target)]
            }

        case .payoff:
            if eventsInPhase >= Self.dwell[.payoff]! {
                return enter(.subtract, locked: locked)
            }
            eventsInPhase += 1
            // Re-add everything (additive repetition, M §12.3 S6–S8); the
            // density raise arrives with FR-A-3 in phase 27. With nothing to
            // re-add, still make an audible change — M §12.1 promises one
            // every period.
            let missing = buildOrder.filter { !activeVoices.contains($0) }
            activeVoices = buildOrder
            if missing.isEmpty {
                guard let target = nextTarget(locked: locked) else { return [] }
                return [.nudgeMutation(voiceID: target)]
            }
            return missing.map { .activate(voiceID: $0) }

        case .subtract:
            if activeVoices.count > 1 {
                let last = activeVoices.removeLast()
                return [.deactivate(voiceID: last)]
            }
            return enter(.ending, locked: locked)

        case .ending:
            if eventsInPhase == 0 {
                eventsInPhase = 1
                return [.thinToRoots(voiceID: activeVoices.first ?? buildOrder[0])]
            }
            stopRequested = true
            return [.requestStop]
        }
    }

    /// Entering a phase immediately performs its first change event — the
    /// transition IS the change the listener hears.
    private mutating func enter(_ next: ArrangementPhase,
                                locked: Set<String>) -> [ArrangementDirective] {
        phase = next
        barsInPhase = 0
        eventsInPhase = 0
        return changeEvent(locked: locked)
    }

    /// Round-robin over active, unlocked voices in build order (spec §7.8).
    private mutating func nextTarget(locked: Set<String>) -> String? {
        let eligible = buildOrder.filter {
            activeVoices.contains($0) && !locked.contains($0)
        }
        guard !eligible.isEmpty else { return nil }
        let target = eligible[roundRobin % eligible.count]
        roundRobin += 1
        return target
    }
}
