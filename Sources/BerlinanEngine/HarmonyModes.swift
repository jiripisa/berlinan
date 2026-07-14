/// The manual's harmony mechanisms as configuration (M §7; FR-H-4/5/6).
/// Every mode materializes deterministically into a `TranspositionSchedule`,
/// so the render pipeline (phase 07) needs no changes.

public struct ProgressionStep: Codable, Equatable, Sendable {
    /// Diatonic degree offset (0 = home/root).
    public var degreeOffset: Int
    /// How long the step holds, in bars.
    public var bars: Int

    public init(degreeOffset: Int, bars: Int) {
        precondition(bars > 0, "a progression step must last at least one bar")
        self.degreeOffset = degreeOffset
        self.bars = bars
    }
}

/// A progression = degree numbers over time (M §7.1 — "progressions as
/// transposition sequences").
public struct Progression: Codable, Equatable, Sendable {
    public var name: String
    public var steps: [ProgressionStep]
    public var loop: Bool

    public init(name: String, steps: [ProgressionStep], loop: Bool) {
        precondition(!steps.isEmpty)
        self.name = name
        self.steps = steps
        self.loop = loop
    }

    /// The documented walks (M §7.1), 4 bars per step, looped.
    public static let presets: [Progression] = [
        preset("i-iv-v-i",  [0, 3, 4, 0]),
        preset("1-7-6-5",   [0, 6, 5, 4]),
        preset("1-5-6-7",   [0, 4, 5, 6]),
        preset("1-6-4-7",   [0, 5, 3, 6]),
        preset("1-6-4-1",   [0, 5, 3, 0]),
        preset("7-5-6",     [6, 4, 5]),
        preset("1-b7-6-#5", [0, 6, 5, 4]),   // walk-down variant [M §7.1, Day 04]
        preset("6-5-4-1",   [5, 4, 3, 0]),
    ]

    private static func preset(_ name: String, _ offsets: [Int]) -> Progression {
        Progression(name: name,
                    steps: offsets.map { ProgressionStep(degreeOffset: $0, bars: 4) },
                    loop: true)
    }
}

/// Project-level harmony mode. nil on `Project.harmony` = legacy behavior
/// (the hand-written `transposition` schedule) — 0.2.0 files stay valid.
public enum HarmonyModeConfig: Codable, Equatable, Sendable {
    /// Unrolled from bar 0 (FR-H-4).
    case progression(Progression)
    /// Deterministic surprise every `minPeriodBars...maxPeriodBars` bars,
    /// targets drawn from the weight table (FR-H-5, M §13.6).
    case weightedRandom(weights: [Int: Double], minPeriodBars: Int, maxPeriodBars: Int)
    /// Upper voices frozen; only the bass re-roots (FR-H-6, M §7.2).
    case bassReharm(Progression)

    /// The manual's "sweet vs dark" default table (M §7.1/§13.6): home is
    /// likeliest, 5th/6th sweet, 4th solid, 3rd/7th darker spice.
    public static let defaultWeights: [Int: Double] =
        [0: 0.30, 4: 0.20, 5: 0.18, 3: 0.14, 2: 0.10, 6: 0.08]
}

public enum HarmonyScheduler {

    /// Materialization horizon for open-ended modes: 1024 bars (≈ 45 min at
    /// 90 BPM). Renders beyond it hold the last offset.
    public static let horizonBars = 1024

    /// Resolve a project's harmony into a concrete schedule.
    /// `bassOnly` = true means only the bass voice participates in
    /// transposition (bass-reharm participation mask).
    public static func resolve(project: Project) -> (schedule: TranspositionSchedule,
                                                     bassOnly: Bool) {
        switch project.harmony {
        case nil:
            return (project.transposition, false)

        case .progression(let progression):
            return (unroll(progression), false)

        case let .weightedRandom(weights, minPeriod, maxPeriod):
            precondition(!weights.isEmpty && minPeriod >= 1 && maxPeriod >= minPeriod)
            var rng = SplitMix64(seed: SeedStream.derive(master: project.masterSeed,
                                                         "harmony", "weighted"))
            let keys = weights.keys.sorted()
            let total = keys.reduce(0.0) { $0 + weights[$1]! }
            var events: [TranspositionEvent] = []
            var bar = Int.random(in: minPeriod...maxPeriod, using: &rng)
            while bar <= horizonBars {
                var roll = Double.random(in: 0..<total, using: &rng)
                var offset = keys[0]
                for key in keys {
                    roll -= weights[key]!
                    if roll < 0 { offset = key; break }
                }
                events.append(TranspositionEvent(bar: bar, degreeOffset: offset))
                bar += Int.random(in: minPeriod...maxPeriod, using: &rng)
            }
            return (TranspositionSchedule(events: events), false)

        case .bassReharm(let progression):
            return (unroll(progression), true)
        }
    }

    private static func unroll(_ progression: Progression) -> TranspositionSchedule {
        var events: [TranspositionEvent] = []
        var bar = 0
        let cycleBars = progression.steps.reduce(0) { $0 + $1.bars }
        let repeats = progression.loop ? max(1, horizonBars / cycleBars + 1) : 1
        for _ in 0..<repeats {
            for step in progression.steps {
                if bar > horizonBars { break }
                events.append(TranspositionEvent(bar: bar, degreeOffset: step.degreeOffset))
                bar += step.bars
            }
        }
        return TranspositionSchedule(events: events)
    }
}
