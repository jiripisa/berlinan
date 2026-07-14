/// Per-voice register window with the octave-fold rule (FR-V-3, M §5.1):
/// a note outside the window wraps by octaves into it — it is never clamped
/// and never dropped, so wide arpeggios stay harmonically valid.
public struct RegisterWindow: Codable, Equatable, Sendable {
    public var low: UInt8
    public var high: UInt8

    public init(low: UInt8, high: UInt8) {
        precondition(low <= high, "low must not exceed high")
        // A span below one octave could make folding oscillate; the spec
        // requires fold-never-clamp, which needs a full octave of room.
        precondition(Int(high) - Int(low) >= 11, "window must span at least one octave (11 semitones)")
        self.low = low
        self.high = high
    }

    /// Fold by octaves into the window. Accepts out-of-MIDI-range inputs
    /// (transposition intermediate values) and always returns a valid note
    /// inside the window.
    public func fold(_ note: Int) -> UInt8 {
        var n = note
        while n > Int(high) { n -= 12 }
        while n < Int(low)  { n += 12 }
        return UInt8(n)
    }
}
