/// Modes documented in the manual (M §4.2). `custom` allows user-defined
/// offset lists (FR-GS-2, P3).
public enum ModeID: String, Codable, CaseIterable, Sendable {
    case naturalMinor, dorian, phrygian, mixolydian, lydian
    case lydianDominant, harmonicMinor, minorPentatonic, locrian, major
    case custom
}

/// A scale is a list of semitone offsets from the root (M §4.1).
public struct Scale: Codable, Equatable, Sendable {
    public var mode: ModeID
    /// Normalized: starts at 0, strictly ascending, all within 0...11.
    public var offsets: [Int]

    public init(mode: ModeID, offsets: [Int]) {
        precondition(!offsets.isEmpty, "scale must have at least one offset")
        precondition(offsets.first == 0, "scale must start at the root (offset 0)")
        precondition(offsets == offsets.sorted() && Set(offsets).count == offsets.count,
                     "offsets must be strictly ascending")
        precondition(offsets.allSatisfy { (0...11).contains($0) },
                     "offsets must be within one octave")
        self.mode = mode
        self.offsets = offsets
    }

    public var count: Int { offsets.count }

    /// Preset offset lists per manual §4.2.
    public static func preset(_ mode: ModeID) -> Scale {
        switch mode {
        case .naturalMinor:    return Scale(mode: mode, offsets: [0, 2, 3, 5, 7, 8, 10])
        case .dorian:          return Scale(mode: mode, offsets: [0, 2, 3, 5, 7, 9, 10])
        case .phrygian:        return Scale(mode: mode, offsets: [0, 1, 3, 5, 7, 8, 10])
        case .mixolydian:      return Scale(mode: mode, offsets: [0, 2, 4, 5, 7, 9, 10])
        case .lydian:          return Scale(mode: mode, offsets: [0, 2, 4, 6, 7, 9, 11])
        case .lydianDominant:  return Scale(mode: mode, offsets: [0, 2, 4, 6, 7, 9, 10])
        case .harmonicMinor:   return Scale(mode: mode, offsets: [0, 2, 3, 5, 7, 8, 11])
        case .minorPentatonic: return Scale(mode: mode, offsets: [0, 3, 5, 7, 10])
        case .locrian:         return Scale(mode: mode, offsets: [0, 1, 3, 5, 6, 8, 10])
        case .major:           return Scale(mode: mode, offsets: [0, 2, 4, 5, 7, 9, 11])
        case .custom:
            preconditionFailure("custom scales are constructed directly, not via preset()")
        }
    }
}

/// Working key: root pitch class + scale. Default per M §16: C natural minor.
public struct Key: Codable, Equatable, Sendable {
    /// Pitch class 0–11 (C = 0).
    public var root: Int
    public var scale: Scale

    public init(root: Int, scale: Scale) {
        precondition((0...11).contains(root), "root must be a pitch class 0–11")
        self.root = root
        self.scale = scale
    }

    public static let `default` = Key(root: 0, scale: .preset(.naturalMinor))
}
