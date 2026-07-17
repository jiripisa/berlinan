/// Standalone pattern operators (FR-P-5/6) — the manual's variation moves,
/// exposed for the editor (phase 19) and the arrangement machine (M5).
/// Like the generators, pure functions of (input, seed).
public enum PatternOps {

    /// "Duplicate and tweak" (M §5.7): replicate a pattern ×N; the first half
    /// stays verbatim, 1–2 constrained mutations land only in the later
    /// repetitions — the variation recurs every Nth loop instead of every one.
    public static func duplicateAndTweak(_ pattern: Pattern, times: Int = 4,
                                         key: Key, meter: Meter,
                                         seed: UInt64) -> Pattern {
        precondition(times >= 2)
        precondition(pattern.gateCycle == nil, "grow plain patterns only")
        var rng = SplitMix64(seed: seed)

        var notes: [PatternNote] = []
        for rep in 0..<times {
            notes += pattern.notes.map { note in
                var copy = note
                copy.position += Tick(rep) * pattern.length
                return copy
            }
        }
        let newLength = Tick(times) * pattern.length
        let laterStart = Tick(times / 2) * pattern.length
        let stepTicks = meter.ticksPerBeat / 4

        for _ in 0..<Int.random(in: 1...2, using: &rng) {
            let candidates = notes.indices.filter { notes[$0].position >= laterStart }
            guard let idx = candidates.randomElement(using: &rng) else { continue }
            if Bool.random(using: &rng) {
                // Degree move, span-guarded (FR-P-2).
                var candidate = notes[idx]
                candidate.pitch.degree += [-2, -1, 1, 2].randomElement(using: &rng)!
                var probe = notes
                probe[idx] = candidate
                let resolved = probe.map { key.resolve($0.pitch, referenceC: 60) }
                if resolved.max()! - resolved.min()! <= 24 { notes[idx] = candidate }
            } else {
                // Time nudge within the later half, collision-safe.
                let target = notes[idx].position
                    + Tick([-1, 1].randomElement(using: &rng)!) * stepTicks
                if target >= laterStart, target < newLength,
                   !notes.contains(where: { $0.position == target }) {
                    notes[idx].position = target
                }
            }
        }

        return Pattern(
            id: "\(pattern.id)/x\(times)",
            length: newLength,
            startOffset: pattern.startOffset,
            notes: notes,
            provenance: Provenance(generator: pattern.provenance.generator,
                                   version: pattern.provenance.version,
                                   seed: seed),
            locked: pattern.locked)
    }

    /// "Keep the notes, move the accents" (M §5.8): relocate one accent to a
    /// different note; pitches, times, velocities and gates stay untouched.
    /// Density cap (FR-A-3, M §13.1): keep `ceil(count·density)` notes,
    /// ranked accents first, then beat-aligned onsets, then loop order. A
    /// deterministic filter — no dice, Law 1 intact; density 1 is identity.
    public static func densityCap(_ pattern: Pattern, density: Double,
                                  meter: Meter) -> Pattern {
        let clamped = max(0, min(1, density))
        guard clamped < 1, !pattern.notes.isEmpty else { return pattern }
        var out = pattern
        let keep = Int((Double(pattern.notes.count) * clamped).rounded(.up))
        guard keep > 0 else { out.notes = []; return out }
        let ranked = pattern.notes.enumerated().sorted { a, b in
            let beatTicks = meter.ticksPerBeat
            func rank(_ n: PatternNote) -> (Int, Int, Tick) {
                (n.accent ? 0 : 1, n.position % beatTicks == 0 ? 0 : 1, n.position)
            }
            return rank(a.element) < rank(b.element)
        }
        let keptIndices = Set(ranked.prefix(keep).map(\.offset))
        out.notes = pattern.notes.enumerated()
            .filter { keptIndices.contains($0.offset) }
            .map(\.element)
        return out
    }

    /// Ending move (M §12.4, FR-A-1): keep only root-degree notes; a pattern
    /// with no root retunes its first note instead. Arrives locked and
    /// established — the piece is over, nothing may mutate it further.
    public static func thinToRoots(_ pattern: Pattern) -> Pattern {
        var out = pattern
        let roots = out.notes.filter { $0.pitch.degree == 0 }
        if roots.isEmpty, var first = out.notes.first {
            first.pitch.degree = 0
            out.notes = [first]
        } else {
            out.notes = roots
        }
        out.locked = true
        out.lifecycle = .established
        return out
    }

    public static func moveAccents(_ pattern: Pattern, seed: UInt64) -> Pattern {
        var rng = SplitMix64(seed: seed)
        var out = pattern
        if let from = out.notes.indices.first(where: { out.notes[$0].accent }),
           let to = out.notes.indices.filter({ !out.notes[$0].accent })
               .randomElement(using: &rng) {
            out.notes[from].accent = false
            out.notes[to].accent = true
        } else if let idx = out.notes.indices.randomElement(using: &rng) {
            out.notes[idx].accent.toggle()
        }
        return out
    }
}
