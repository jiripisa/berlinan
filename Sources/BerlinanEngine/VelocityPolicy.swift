/// Velocity semantics (FR-MOD-1, M §11.1): accents = baseline + boost;
/// humanization = a bounded offset that is CONSTANT across the verbatim
/// repeats of one legitimization cycle and re-rolls only when the pattern
/// mutates (Law 1 — randomness never re-rolls per render). The offset is
/// keyed on (pattern generation seed, local note position).
public struct VelocityPolicy: Codable, Equatable, Sendable {
    /// Added to accented notes (M §16: accent = velocity + brightness).
    public var accentBoost: Int
    /// Uniform humanization range ± (manual's documented window is ±20 max;
    /// default ±10 keeps the mechanical character).
    public var humanizeRange: Int

    public init(accentBoost: Int = 20, humanizeRange: Int = 10) {
        precondition((0...64).contains(accentBoost))
        precondition((0...20).contains(humanizeRange))
        self.accentBoost = accentBoost
        self.humanizeRange = humanizeRange
    }

    public func apply(velocity: UInt8, accent: Bool, patternSeed: UInt64,
                      localPosition: Tick) -> UInt8 {
        var v = Int(velocity)
        if accent { v += accentBoost }
        if humanizeRange > 0 {
            let roll = SeedStream.derive(master: patternSeed, "humanize",
                                         String(localPosition))
            v += Int(roll % UInt64(2 * humanizeRange + 1)) - humanizeRange
        }
        return UInt8(max(1, min(127, v)))
    }
}
