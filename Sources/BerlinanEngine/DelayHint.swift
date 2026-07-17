/// Delay hints (FR-MOD-8): the "ducka-ducka" groove is an AUDIO delay the
/// app cannot produce — instead it tells the producer exactly what to dial in
/// (M §9.1), with milliseconds recomputed from the live tempo.

public enum DelayDivision: String, Codable, Sendable {
    case dotted8th, eighth, quarter

    /// Fraction of one beat (quarter note).
    var beats: Double {
        switch self {
        case .dotted8th: return 0.75
        case .eighth:    return 0.5
        case .quarter:   return 1.0
        }
    }

    public var label: String {
        switch self {
        case .dotted8th: return "dotted 8th"
        case .eighth:    return "8th"
        case .quarter:   return "quarter"
        }
    }
}

public struct DelayHint: Equatable, Sendable {
    public let division: DelayDivision
    public let milliseconds: Double
    public let feedback: Double = 0.5
    public let wet: Double = 0.5
    public let pingPong: Bool = true
    public let filterRepeats: Bool = true

    /// Division per role (M §9.1): dotted 8th on the bed, plain 8th on the
    /// bass ("don't over-duck"), quarter on sustained voices. Alternating
    /// voices (FR-MEL-3): slot A keeps the role's color, slot B answers on
    /// quarters so call and answer echo differently (M §8.3).
    public static func compute(role: VoiceRole, bpm: Double,
                               alternationSlot: Int? = nil) -> DelayHint {
        if alternationSlot == 1 {
            return DelayHint(division: .quarter,
                             milliseconds: 60000 / bpm * DelayDivision.quarter.beats)
        }
        let division: DelayDivision
        switch role {
        case .bedPluck1, .bedPluck2, .rhythm, .aux: division = .dotted8th
        case .bass, .drone:                         division = .eighth
        case .pad, .lead:                           division = .quarter
        }
        let beatMs = 60_000.0 / bpm
        return DelayHint(division: division, milliseconds: beatMs * division.beats)
    }

    private init(division: DelayDivision, milliseconds: Double) {
        self.division = division
        self.milliseconds = milliseconds
    }

    /// Copyable one-liner for the cheat sheet. (No Foundation in the engine —
    /// hand-rolled formatting.)
    public var summary: String {
        "\(division.label) ≈ \(Int(milliseconds.rounded())) ms · feedback 50% · wet 50% · ping-pong · filtered repeats"
    }
}
