/// Velocity-accent melody extraction (FR-MEL-1, M §8.1): mute all, raise
/// 3–4 curated accents, then evolve — 2-bar accent inversion, 4-bar
/// single-change growth. The melody engine owns its evolution clock (the
/// manual prescribes it), so extracted patterns arrive locked against the
/// Legitimizer, like accumulators are exempt from the verbatim rule.

/// Alternating phrase scheduler (FR-MEL-3, M §8.3): two voices own
/// complementary phrase slots and are guaranteed never to sound together —
/// onsets filter by slot, gates clamp at the slot edge.
public struct AlternatingConfig: Codable, Equatable, Sendable {
    public var voiceA: String
    public var voiceB: String
    public var phraseBars: Int

    public init(voiceA: String, voiceB: String, phraseBars: Int = 4) {
        precondition(phraseBars >= 1)
        self.voiceA = voiceA
        self.voiceB = voiceB
        self.phraseBars = phraseBars
    }
}

/// The manual's interval tension table (M §4.4, FR-MEL-4): 0 = rest,
/// 10 = maximum pull. Intervals fold to one octave.
public enum TensionTable {
    public static func score(semitones: Int) -> Int {
        switch ((semitones % 12) + 12) % 12 {
        case 0:      return 0    // unison / octave — home
        case 7:      return 1    // perfect fifth — stable
        case 5:      return 2    // perfect fourth
        case 3, 4:   return 3    // thirds — mild color
        case 9:      return 4    // major sixth
        case 2, 8:   return 5    // major second / minor sixth
        case 10:     return 6    // minor seventh
        case 6, 11:  return 9    // tritone / major seventh — tense
        default:     return 10   // minor second — maximum pull
        }
    }
}

public enum Melody {

    /// Curated accent picks (M §8.1 steps 2–3): prefer on-beat, never
    /// adjacent 16th steps, never root+fifth-only when alternatives exist.
    /// Deterministic per seed (the seed only decides 3 vs 4).
    public static func selectAccents(pattern: Pattern, key: Key, meter: Meter,
                                     seed: UInt64) -> Set<Int> {
        select(from: Array(pattern.notes.indices), pattern: pattern,
               meter: meter, seed: seed)
    }

    /// The 2-bar inversion (M §8.1 step 5): a fresh curated pick from the
    /// notes the previous melody did NOT use.
    public static func invertAccents(pattern: Pattern, previous: Set<Int>,
                                     meter: Meter, seed: UInt64) -> Set<Int> {
        let complement = pattern.notes.indices.filter { !previous.contains($0) }
        guard !complement.isEmpty else { return previous }
        return select(from: complement, pattern: pattern, meter: meter, seed: seed)
    }

    /// The 4-bar growth (M §8.1 step 6), scored by the interval tension
    /// table against the melody note preceding the candidate (FR-MEL-4).
    /// The tension-walk contour is the default policy: walk position 0
    /// wants the tensest available note, positions 1–2 want release.
    public static func growthPick(pattern: Pattern, current: Set<Int>,
                                  meter: Meter, key: Key, referenceC: Int,
                                  walkPosition: Int) -> Int? {
        let candidates = pattern.notes.indices.filter { !current.contains($0) }
        guard !candidates.isEmpty else { return nil }
        guard !current.isEmpty else {
            return rank(candidates, pattern: pattern, meter: meter).first
        }
        let sortedCurrent = current.sorted {
            pattern.notes[$0].position < pattern.notes[$1].position
        }
        func semis(_ idx: Int) -> Int {
            key.resolve(pattern.notes[idx].pitch, referenceC: referenceC)
        }
        func tension(_ idx: Int) -> Int {
            let position = pattern.notes[idx].position
            let previous = sortedCurrent.last {
                pattern.notes[$0].position < position
            } ?? sortedCurrent.last!
            return TensionTable.score(semitones: abs(semis(idx) - semis(previous)))
        }
        let wantTense = walkPosition % 3 == 0
        return candidates.sorted { a, b in
            let ta = tension(a), tb = tension(b)
            if ta != tb { return wantTense ? ta > tb : ta < tb }
            return pattern.notes[a].position < pattern.notes[b].position
        }.first
    }

    /// The sounding extraction: picked notes only, all accented; locked and
    /// established — the melody engine owns changes from here.
    public static func extraction(from source: Pattern, picks: Set<Int>,
                                  stage: Int) -> Pattern {
        var out = source
        out.id = "\(source.id)/mel\(stage)"
        out.notes = source.notes.enumerated()
            .filter { picks.contains($0.offset) }
            .map { entry in
                var note = entry.element
                note.accent = true
                return note
            }
        out.locked = true
        out.lifecycle = .established
        return out
    }

    /// Lead promotion (FR-MEL-2, M §8.1 step 7): melody notes stretched
    /// legato — each gate reaches the next melody onset, at least one beat.
    public static func leadPattern(from source: Pattern, picks: Set<Int>,
                                   meter: Meter) -> Pattern {
        var out = extraction(from: source, picks: picks, stage: 0)
        out.id = "\(source.id)/lead"
        let onsets = out.notes.map(\.position)
        for idx in out.notes.indices {
            let next = idx + 1 < onsets.count
                ? onsets[idx + 1] - onsets[idx]
                : source.length - onsets[idx] + (onsets.first ?? 0)
            out.notes[idx].gate = max(meter.ticksPerBeat, next)
        }
        return out
    }

    // MARK: - Selection core

    private static func rank(_ candidates: [Int], pattern: Pattern,
                             meter: Meter) -> [Int] {
        candidates.sorted { a, b in
            let na = pattern.notes[a], nb = pattern.notes[b]
            let onA = na.position % meter.ticksPerBeat == 0 ? 0 : 1
            let onB = nb.position % meter.ticksPerBeat == 0 ? 0 : 1
            if onA != onB { return onA < onB }
            return na.position < nb.position
        }
    }

    private static func select(from candidates: [Int], pattern: Pattern,
                               meter: Meter, seed: UInt64) -> Set<Int> {
        guard !candidates.isEmpty else { return [] }
        var rng = SplitMix64(seed: seed)
        let target = candidates.count >= 4
            ? (Bool.random(using: &rng) ? 4 : 3)
            : min(3, candidates.count)
        let stepTicks = meter.ticksPerBeat / 4
        let ranked = rank(candidates, pattern: pattern, meter: meter)

        func farEnough(_ a: Int, _ b: Int) -> Bool {
            abs(Int(pattern.notes[a].position) - Int(pattern.notes[b].position))
                >= 2 * Int(stepTicks)
        }

        var picks: [Int] = []
        for candidate in ranked where picks.count < target {
            if picks.allSatisfy({ farEnough($0, candidate) }) {
                picks.append(candidate)
            }
        }

        // Never root+fifth-only when a color tone is available (step 3).
        func isColor(_ idx: Int) -> Bool {
            let degree = ((pattern.notes[idx].pitch.degree % 7) + 7) % 7
            return degree != 0 && degree != 4
        }
        if !picks.isEmpty, !picks.contains(where: isColor) {
            let kept = picks.dropLast()
            if let replacement = ranked.first(where: { candidate in
                isColor(candidate) && !kept.contains(candidate)
                    && kept.allSatisfy { farEnough($0, candidate) }
            }) {
                picks[picks.count - 1] = replacement
            }
        }
        return Set(picks)
    }
}
