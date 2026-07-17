/// Pattern and note value types (spec §6.3).

/// One note of a pattern. Pitch is degree-based (spec §6.2); `velocity` is
/// the pre-policy baseline — accents and humanization are applied by the
/// ModulationEngine (M §11.1).
public struct PatternNote: Codable, Equatable, Sendable {
    /// Onset within the loop, 0..<pattern.length.
    public var position: Tick
    public var pitch: DegreePitch
    /// 1–127.
    public var velocity: UInt8
    /// Sounding duration in ticks; > 0. Short by default (M §5.1).
    public var gate: Tick
    public var accent: Bool
    /// 1 = normal; 2–3 = intermittent ratchet (M §13.5).
    public var ratchet: Int

    public init(position: Tick, pitch: DegreePitch, velocity: UInt8 = 100,
                gate: Tick, accent: Bool = false, ratchet: Int = 1) {
        precondition(position >= 0, "position must be non-negative")
        precondition((1...127).contains(Int(velocity)), "velocity must be 1–127")
        precondition(gate > 0, "gate must be positive")
        precondition((1...3).contains(ratchet), "ratchet must be 1–3")
        self.position = position
        self.pitch = pitch
        self.velocity = velocity
        self.gate = gate
        self.accent = accent
        self.ratchet = ratchet
    }
}

/// One step of a decoupled gate cycle (M §6.4, FR-P-4).
public struct GateStep: Codable, Equatable, Sendable {
    public var on: Bool
    /// Fraction of the step that sounds, 0.4–0.99 (M §5.1).
    public var width: Double

    public init(on: Bool, width: Double) {
        precondition((0.4...0.99).contains(width), "gate width must be 0.4–0.99")
        self.on = on
        self.width = width
    }
}

/// Which algorithm produced a pattern (spec §5.3: enough to regenerate it
/// bit-identically and display "what made this").
public enum GeneratorID: String, Codable, Sendable {
    case seedProcedure      // M §5.2
    case highMidLow         // M §5.3
    case pulsingBass        // M §5.5
    case drunkardsWalk      // M §13.2 (P2)
    case stagedPluck        // M §5.6 (P2)
    case arpeggiator        // M §5.9 (P2)
    case bassMelody         // M §8.4 (P3, FR-MEL-5)
    case handEdited         // producer edits (FR-P-7)
}

public struct Provenance: Codable, Equatable, Sendable {
    public var generator: GeneratorID
    public var version: Int
    public var seed: UInt64

    public init(generator: GeneratorID, version: Int, seed: UInt64) {
        self.generator = generator
        self.version = version
        self.seed = seed
    }
}

/// Legitimization lifecycle (M Law 1). Transitions are the Legitimizer's job
/// (phase 06); this is only the persisted state.
public enum Lifecycle: Codable, Equatable, Sendable {
    /// Fresh/mutated material with `remaining` verbatim plays left before it
    /// becomes mutable. A fresh pattern starts at N (default 4 — "generate
    /// once + repeat 3× = 4 total plays").
    case repeating(remaining: Int)
    /// Played its N verbatim plays; eligible for mutation.
    case established
}

/// A short repeating figure owned by a voice (M §5).
public struct Pattern: Codable, Equatable, Sendable {
    /// Stable identifier, e.g. "bedPluck1/gen3". Deliberately NOT a random
    /// UUID — random ids would break render determinism (NFR-4); the spec
    /// §6.3 sketch is amended by this (recorded in STATE.md decisions).
    public var id: String
    /// Loop length in ticks — free-form, including non-power-of-two (FR-P-3).
    public var length: Tick
    /// Rotation (M §6.2): localTick = (globalTick + startOffset) mod length.
    /// Normalized into 0..<length.
    public var startOffset: Tick
    public var notes: [PatternNote]
    /// Decoupled gate cycle (M §6.4) — used from phase M3 on; carried here so
    /// the document format is stable.
    public var gateCycle: [GateStep]?
    public var gateCycleLength: Tick?
    public var provenance: Provenance
    /// Locked patterns are exempt from all mutation/regeneration (FR-V-4).
    public var locked: Bool
    public var lifecycle: Lifecycle

    public init(id: String, length: Tick, startOffset: Tick = 0,
                notes: [PatternNote], gateCycle: [GateStep]? = nil,
                gateCycleLength: Tick? = nil, provenance: Provenance,
                locked: Bool = false,
                lifecycle: Lifecycle = .repeating(remaining: 4)) {
        precondition(length > 0, "pattern length must be positive")
        precondition(notes.allSatisfy { $0.position < length },
                     "note positions must lie within the loop")
        precondition((gateCycle == nil) == (gateCycleLength == nil),
                     "gateCycle and gateCycleLength come together")
        self.id = id
        self.length = length
        self.startOffset = Tick(floorMod(Int(startOffset), Int(length)))
        self.notes = notes
        self.gateCycle = gateCycle
        self.gateCycleLength = gateCycleLength
        self.provenance = provenance
        self.locked = locked
        self.lifecycle = lifecycle
    }

    // MARK: Decoupled gate/pitch mode (FR-P-4, M §6.4)

    /// Build a decoupled pattern: independent pitch and gate cycles that BOTH
    /// advance every step; a gate-off step is silent while the pitch cycle
    /// keeps moving (the manual's 8v6 → re-sync-at-24 model). The loop length
    /// is the full composite period.
    public static func decoupled(id: String, pitches: [DegreePitch],
                                 gates: [GateStep], stepTicks: Tick,
                                 provenance: Provenance) -> Pattern {
        precondition(!pitches.isEmpty && !gates.isEmpty && stepTicks > 0)
        let steps = lcm(Tick(pitches.count), Tick(gates.count))
        let notes = pitches.enumerated().map { index, pitch in
            PatternNote(position: Tick(index) * stepTicks, pitch: pitch,
                        velocity: 100, gate: max(1, stepTicks / 2))
        }
        return Pattern(id: id, length: steps * stepTicks, notes: notes,
                       gateCycle: gates, gateCycleLength: Tick(gates.count) * stepTicks,
                       provenance: provenance)
    }

    /// In decoupled mode `notes` is the pitch cycle; expand both cycles into
    /// concrete per-step notes across one composite period. Plain patterns
    /// return `notes` unchanged.
    var effectiveNotes: [PatternNote] {
        guard let gates = gateCycle, let gateLength = gateCycleLength else { return notes }
        let stepTicks = gateLength / Tick(gates.count)
        var expanded: [PatternNote] = []
        for index in 0..<Int(length / stepTicks) {
            let gate = gates[index % gates.count]
            guard gate.on else { continue }
            let base = notes[index % notes.count]
            expanded.append(PatternNote(
                position: Tick(index) * stepTicks,
                pitch: base.pitch,
                velocity: base.velocity,
                gate: max(1, Tick(Double(stepTicks) * gate.width)),
                accent: base.accent,
                ratchet: base.ratchet))
        }
        return expanded
    }

    // MARK: Loop-cursor math

    /// All note onsets sounding within the half-open global tick range.
    /// A note at loop position `p` sounds at global ticks g where
    /// (g + startOffset) mod length == p, i.e. g = p − startOffset + k·length.
    /// Result is sorted by time.
    public func occurrences(in range: Range<Tick>) -> [(at: Tick, note: PatternNote)] {
        let notes = effectiveNotes
        guard !notes.isEmpty, range.lowerBound < range.upperBound else { return [] }
        var result: [(at: Tick, note: PatternNote)] = []
        for note in notes {
            let base = note.position - startOffset
            // Smallest k with base + k*length >= lowerBound (floored division
            // handles negatives).
            let k0 = Tick(floorDiv(Int(range.lowerBound - base + length - 1), Int(length)))
            var g = base + k0 * length
            while g < range.upperBound {
                if g >= range.lowerBound { result.append((at: g, note: note)) }
                g += length
            }
        }
        result.sort { $0.at < $1.at || ($0.at == $1.at && $0.note.position < $1.note.position) }
        return result
    }

    /// True when something sounds exactly at the given global tick.
    public func hasOnset(atGlobalTick tick: Tick) -> Bool {
        let local = Tick(floorMod(Int(tick + startOffset), Int(length)))
        return effectiveNotes.contains { $0.position == local }
    }

    // MARK: Invariant helpers (FR-P-2)

    /// The earliest sounding note (patterns may start with a rest, M §5.1).
    public var firstSoundingNote: PatternNote? {
        notes.min { $0.position < $1.position }
    }

    /// M §5.1: the first sounding note must be the root — any octave, no
    /// accidental.
    public func firstSoundingIsRoot(scaleCount: Int) -> Bool {
        guard let first = firstSoundingNote else { return false }
        return floorMod(first.pitch.degree, scaleCount) == 0 && first.pitch.accidental == 0
    }
}
