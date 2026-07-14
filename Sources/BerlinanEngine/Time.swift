/// Musical time. The engine never sees wall-clock time — only ticks
/// (spec §5.1). 960 PPQN [spec §2, design decision].
public typealias Tick = Int64

public enum Time {
    /// Pulses per quarter note.
    public static let ppqn: Tick = 960
}

/// Time signature with the manual's accent groupings (M §9.3).
/// Meter changes bind only at bar boundaries (FR-GS-4) — enforced by the
/// scheduler, not here.
public struct Meter: Codable, Equatable, Sendable {
    /// Number of beats per bar (the numerator).
    public var beatsPerBar: Int
    /// The note value of one beat (the denominator): 4 = quarter, 8 = eighth.
    public var beatUnit: Int
    /// Accent grouping in beats, e.g. [4, 3] for 7/8. Empty = default accents.
    public var grouping: [Int]

    public init(beatsPerBar: Int, beatUnit: Int, grouping: [Int] = []) {
        precondition(beatsPerBar > 0, "beatsPerBar must be positive")
        precondition(beatUnit == 4 || beatUnit == 8, "beatUnit must be 4 or 8")
        precondition(grouping.isEmpty || grouping.reduce(0, +) == beatsPerBar,
                     "grouping must sum to beatsPerBar")
        self.beatsPerBar = beatsPerBar
        self.beatUnit = beatUnit
        self.grouping = grouping
    }

    public var ticksPerBeat: Tick { Time.ppqn * 4 / Tick(beatUnit) }
    public var ticksPerBar: Tick { Tick(beatsPerBar) * ticksPerBeat }

    /// The default working meter (M §3.2).
    public static let fourFour = Meter(beatsPerBar: 4, beatUnit: 4)
}
