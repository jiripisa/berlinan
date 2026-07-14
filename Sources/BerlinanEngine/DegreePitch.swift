/// Degree-based pitch — the engine's load-bearing representation (spec §6.2).
/// Notes are stored as scale degrees, never MIDI numbers, so diatonic
/// transposition (M §7.1) is an integer add and Law 2 (everything in scale)
/// is structurally unbreakable: an out-of-key note cannot even be expressed
/// without the explicit `accidental` field (tension budget, M §4.4).
public struct DegreePitch: Codable, Hashable, Sendable {
    /// 0-based index into the scale; may exceed the scale length or be
    /// negative — overflow carries into octaves.
    public var degree: Int
    /// Octaves relative to the voice's reference octave.
    public var octave: Int
    /// Raw semitone offset. Non-zero ONLY via the tension-budget mechanism
    /// (FR-H-7); everything else in the engine leaves it at 0.
    public var accidental: Int

    public init(degree: Int, octave: Int = 0, accidental: Int = 0) {
        self.degree = degree
        self.octave = octave
        self.accidental = accidental
    }
}

/// Floored division/modulo (Swift's `%` truncates toward zero, which breaks
/// negative-degree math).
@inline(__always)
func floorDiv(_ a: Int, _ b: Int) -> Int {
    let q = a / b
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
}

@inline(__always)
func floorMod(_ a: Int, _ b: Int) -> Int {
    let r = a % b
    return (r != 0 && (r < 0) != (b < 0)) ? r + b : r
}

extension Key {

    /// The ONLY place degrees become MIDI numbers (spec §6.2, §7.1).
    /// `referenceC` is the MIDI note of the voice's reference C (typically 60,
    /// adjusted by the voice's reference octave). Register folding is the
    /// caller's job (`RegisterWindow.fold`).
    public func resolve(_ pitch: DegreePitch, referenceC: Int) -> Int {
        let count = scale.count
        let d = floorMod(pitch.degree, count)
        let carry = floorDiv(pitch.degree, count)
        return referenceC
            + 12 * (pitch.octave + carry)
            + root
            + scale.offsets[d]
            + pitch.accidental
    }

    /// Quantize a chromatic MIDI note into the key: the nearest scale tone,
    /// with equidistant ties resolving DOWNWARD (spec §7.1 — the darker
    /// resolution suits the style's minor-mode default). The result always has
    /// `accidental == 0` and resolves to a pitch at most 6 semitones away.
    public func quantize(midi: Int, referenceC: Int) -> DegreePitch {
        let count = scale.count
        // Center the candidate search on the octave containing `midi`.
        let rel = midi - referenceC - root
        let centerOctave = floorDiv(rel, 12)

        var best: (pitch: DegreePitch, resolved: Int)? = nil
        for octave in (centerOctave - 1)...(centerOctave + 1) {
            for d in 0..<count {
                let p = DegreePitch(degree: d, octave: octave)
                let r = resolve(p, referenceC: referenceC)
                if let b = best {
                    let (dNew, dBest) = (abs(r - midi), abs(b.resolved - midi))
                    // Strictly closer wins; a tie goes to the LOWER pitch.
                    if dNew < dBest || (dNew == dBest && r < b.resolved) {
                        best = (p, r)
                    }
                } else {
                    best = (p, r)
                }
            }
        }
        return best!.pitch   // candidate set is never empty
    }
}
