/// Pattern generators 1–3 (FR-P-1). Every generator is a pure function of
/// (config, role, key, meter, seed) — the same inputs always produce the
/// identical pattern (NFR-4).

public enum HMLRegister: String, Codable, Sendable { case high, mid, low }

public enum GeneratorConfig: Codable, Equatable, Sendable {
    /// M §5.2 — roots on every beat, then N constrained mutations.
    case seedProcedure(bars: Int, mutations: Int)
    /// M §5.3 — the three-voice contour recipe.
    case highMidLow(register: HMLRegister)
    /// M §5.5 — straight 16ths on the root with accented off-root moves.
    case pulsingBass(accents: Int)

    var generatorID: GeneratorID {
        switch self {
        case .seedProcedure: return .seedProcedure
        case .highMidLow:    return .highMidLow
        case .pulsingBass:   return .pulsingBass
        }
    }

    /// All current generators draw from the seed stream (used by tests to
    /// assert the seed is not ignored).
    var usesRandomness: Bool { true }
}

public enum PatternFactory {

    public static func make(id: String, config: GeneratorConfig, role: VoiceRole,
                            key: Key, meter: Meter, seed: UInt64) -> Pattern {
        var rng = SplitMix64(seed: seed)
        let notes: [PatternNote]
        let length: Tick

        switch config {
        case let .seedProcedure(bars, mutations):
            length = Tick(bars) * meter.ticksPerBar
            notes = seedProcedure(bars: bars, mutations: mutations, role: role,
                                  key: key, meter: meter, rng: &rng)
        case let .highMidLow(register):
            length = meter.ticksPerBar
            notes = highMidLow(register: register, meter: meter, rng: &rng)
        case let .pulsingBass(accents):
            length = meter.ticksPerBar
            notes = pulsingBass(accents: accents, meter: meter, rng: &rng)
        }

        return Pattern(
            id: id, length: length, notes: notes,
            provenance: Provenance(generator: config.generatorID, version: 1, seed: seed)
        )
    }

    // MARK: - Shared helpers

    /// A 16th-note step relative to the meter's beat (16 steps/bar in 4/4,
    /// M §5.1).
    private static func step(_ meter: Meter) -> Tick { meter.ticksPerBeat / 4 }

    /// Short gates: 40–60% of a 16th step (M §5.1; FR-P-2).
    private static func shortGate(_ meter: Meter, _ rng: inout SplitMix64) -> Tick {
        let s = Int(step(meter))
        return Tick(Int.random(in: (s * 40 / 100)...(s * 60 / 100), using: &rng))
    }

    /// Beats 1 and 3 of every bar are timing-locked anchors (M §5.3).
    private static func lockedTicks(bars: Int, meter: Meter) -> Set<Tick> {
        var locked = Set<Tick>()
        for bar in 0..<bars {
            let base = Tick(bar) * meter.ticksPerBar
            locked.insert(base)
            if meter.beatsPerBar >= 3 { locked.insert(base + 2 * meter.ticksPerBeat) }
        }
        return locked
    }

    // MARK: - Generator 1: seed procedure (M §5.2, spec §7.2)

    private static func seedProcedure(bars: Int, mutations: Int, role: VoiceRole,
                                      key: Key, meter: Meter,
                                      rng: inout SplitMix64) -> [PatternNote] {
        precondition(bars >= 1 && mutations >= 0)
        let locked = lockedTicks(bars: bars, meter: meter)

        // Bass role: roots on beats 1 & 3 only — anchor-safe and maximally
        // transposable (M §5.3 step 5, §7.1).
        if role == .bass {
            return locked.sorted().map { tick in
                PatternNote(position: tick, pitch: DegreePitch(degree: 0),
                            velocity: 100, gate: shortGate(meter, &rng))
            }
        }

        // SEED: the root on every beat (M §5.2 step 2).
        var notes: [PatternNote] = []
        for bar in 0..<bars {
            for beatIndex in 0..<meter.beatsPerBar {
                let pos = Tick(bar) * meter.ticksPerBar + Tick(beatIndex) * meter.ticksPerBeat
                notes.append(PatternNote(position: pos, pitch: DegreePitch(degree: 0),
                                         velocity: 100, gate: shortGate(meter, &rng)))
            }
        }
        let length = Tick(bars) * meter.ticksPerBar
        var octaveAdds = 0

        // MUTATE (M §5.2 step 3), one audited edit at a time.
        for _ in 0..<mutations {
            switch Int.random(in: 0...3, using: &rng) {
            case 0: // move a backbeat note in time by ±1–2 steps
                let movable = notes.indices.filter { !locked.contains(notes[$0].position) }
                guard let idx = movable.randomElement(using: &rng) else { continue }
                let delta = Tick([-2, -1, 1, 2].randomElement(using: &rng)!) * step(meter)
                let target = notes[idx].position + delta
                let occupied = Set(notes.map(\.position))
                guard target >= 0, target < length, !occupied.contains(target) else { continue }
                notes[idx].position = target

            case 1: // move a note's degree within the scale (never the first sounding note)
                let firstPos = notes.map(\.position).min()!
                let candidates = notes.indices.filter { notes[$0].position != firstPos }
                guard let idx = candidates.randomElement(using: &rng) else { continue }
                let delta = [-2, -1, 1, 2].randomElement(using: &rng)!
                // Clamp so the resolved span stays within two octaves (FR-P-2).
                notes[idx].pitch.degree = max(-3, min(4, notes[idx].pitch.degree + delta))

            case 2: // add one note an octave above the root (max 2 adds — Law 3)
                guard octaveAdds < 2 else { continue }
                let occupied = Set(notes.map(\.position))
                let free = (0..<Int(length / step(meter)))
                    .map { Tick($0) * step(meter) }
                    .filter { !occupied.contains($0) }
                guard let pos = free.randomElement(using: &rng) else { continue }
                notes.append(PatternNote(position: pos,
                                         pitch: DegreePitch(degree: 0, octave: 1),
                                         velocity: 95, gate: shortGate(meter, &rng)))
                octaveAdds += 1

            default: // toggle an accent
                guard let idx = notes.indices.randomElement(using: &rng) else { continue }
                notes[idx].accent.toggle()
            }
        }
        return notes
    }

    // MARK: - Generator 2: High/Mid/Low contours (M §5.3, spec §7.2)

    private static func highMidLow(register: HMLRegister, meter: Meter,
                                   rng: inout SplitMix64) -> [PatternNote] {
        let tpb = meter.ticksPerBeat
        let length = meter.ticksPerBar

        func root(_ pos: Tick) -> PatternNote {
            PatternNote(position: pos, pitch: DegreePitch(degree: 0),
                        velocity: 100, gate: shortGate(meter, &rng))
        }

        switch register {
        case .low:
            // Beats 1 & 3 only — the heartbeat (M §5.3 step 5).
            return [root(0), root(2 * tpb)]

        case .high, .mid:
            var notes = (0..<meter.beatsPerBar).map { root(Tick($0) * tpb) }
            // Contour: beat 2 up a 5th (+4 degrees); beat 4 down (M §5.3
            // steps 3–4): high drops to the 5th BELOW the root (−3), mid
            // stair-steps a full 5th down (−4).
            if notes.count >= 4 {
                notes[1].pitch.degree = 4
                notes[3].pitch.degree = (register == .high) ? -3 : -4
                // Backbeat time shifts (±1–2 steps), beats 1 & 3 stay locked
                // on the grid (M §5.3 step 6).
                for idx in [1, 3] where Bool.random(using: &rng) {
                    let delta = Tick([-2, -1, 1, 2].randomElement(using: &rng)!) * step(meter)
                    let target = notes[idx].position + delta
                    let occupied = Set(notes.enumerated()
                        .filter { $0.offset != idx }.map { $0.element.position })
                    if target > 0, target < length, !occupied.contains(target) {
                        notes[idx].position = target
                    }
                }
            }
            return notes
        }
    }

    // MARK: - Generator 3: pulsing 16th bassline (M §5.5, spec §5.5 recipe)

    private static func pulsingBass(accents: Int, meter: Meter,
                                    rng: inout SplitMix64) -> [PatternNote] {
        let stepsPerBar = meter.beatsPerBar * 4
        let s = step(meter)

        // 1–2: every 16th on the root, low velocity, shortish gate.
        var notes = (0..<stepsPerBar).map { k in
            PatternNote(position: Tick(k) * s, pitch: DegreePitch(degree: 0),
                        velocity: 72, gate: shortGate(meter, &rng))
        }

        // 3–4: move a FEW notes off the root and accent exactly those
        // ("the groove is C" — step 0 is never moved).
        let count = max(2, min(4, accents))
        let mutable = Array(1..<stepsPerBar)
        var chosen = Set<Int>()
        while chosen.count < count {
            chosen.insert(mutable.randomElement(using: &rng)!)
        }
        for k in chosen.sorted() {
            switch Int.random(in: 0...2, using: &rng) {
            case 0:  notes[k].pitch.octave = 1
            case 1:  notes[k].pitch.octave = -1
            default: notes[k].pitch.degree = [-2, -1, 1, 2].randomElement(using: &rng)!
            }
            notes[k].velocity = 100
            notes[k].accent = true
        }
        return notes
    }
}
