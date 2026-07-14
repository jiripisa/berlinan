/// Deterministic RNG (NFR-4). SplitMix64 is implemented in-package because
/// `SystemRandomNumberGenerator` is not stable across runs, and stability is
/// the whole point: same project + same seed ⇒ identical MIDI output
/// (FR-UX-1, golden-master tests).
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Named seed streams (spec §5.3): every module derives its own stream from
/// the master seed and stable string labels, so regenerating one voice never
/// disturbs another voice's randomness.
public enum SeedStream {

    /// FNV-1a 64-bit — used instead of `String.hashValue`, which is randomly
    /// seeded per process and would break cross-run determinism.
    private static func fnv1a(_ text: String, into hash: inout UInt64) {
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        // Separator byte so ("ab","c") and ("a","bc") hash differently.
        hash ^= 0x1F
        hash = hash &* 0x0000_0100_0000_01B3
    }

    public static func derive(master: UInt64, _ labels: String...) -> UInt64 {
        derive(master: master, labels: labels)
    }

    public static func derive(master: UInt64, labels: [String]) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325   // FNV offset basis
        for label in labels {
            fnv1a(label, into: &hash)
        }
        // Mix the master seed through one SplitMix64 round so master=0 still
        // produces well-distributed streams.
        var mixer = SplitMix64(seed: master ^ hash)
        return mixer.next()
    }
}
