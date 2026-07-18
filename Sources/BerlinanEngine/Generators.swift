/// Pattern generators 1–3 (FR-P-1). Every generator is a pure function of
/// (config, role, key, meter, seed) — the same inputs always produce the
/// identical pattern (NFR-4).

public enum HMLRegister: String, Codable, Sendable { case high, mid, low }
public enum ArpDirection: String, Codable, Sendable { case up, down, upDown }
public enum ArpRate: String, Codable, Sendable {
    case eighth, sixteenth

    var stepTicks: Tick { self == .eighth ? Time.ppqn / 2 : Time.ppqn / 4 }
}

public enum GeneratorConfig: Codable, Equatable, Sendable {
    /// M §5.2 — roots on every beat, then N constrained mutations.
    case seedProcedure(bars: Int, mutations: Int)
    /// M §5.3 — the three-voice contour recipe.
    case highMidLow(register: HMLRegister)
    /// M §5.5 — straight 16ths on the root with accented off-root moves.
    case pulsingBass(accents: Int)
    /// M §13.2 — constrained chromatic walk quantized into the key.
    case drunkardsWalk(bars: Int, scatter: Int)
    /// M §5.6 — staged 16th build with a signature closing note.
    case stagedPluck(bars: Int)
    /// M §5.9 — held chord expanded across octaves; loop = one full cycle
    /// (odd tone counts phase naturally against the meter).
    case arpeggiator(chordDegrees: [Int], octaves: Int, direction: ArpDirection,
                     rate: ArpRate)
    /// M §8.4 (FR-MEL-5) — progression roots on the downbeats, scale
    /// passing tones walking toward the next bar's root. Deterministic:
    /// the walk IS the harmony, no dice.
    case bassMelody(bars: Int)
    /// M §13.3 (FR-H-8) — one sustained pad chord per loop: 20% home root /
    /// 80% +1..12 semitones, quantized, stacked +4/+7/+12, re-quantized.
    /// The Legitimizer's lifecycle re-rolls it — "one chord per ~7 bars".
    case chordLayer(periodBars: Int)
    /// M §9.2 (FR-V-7) — the quarter-note heartbeat kick.
    case heartbeat
    /// M §12 (phase 33) — the intro layer: root + fifth sustained for the
    /// whole loop. Deterministic.
    case drone(bars: Int)

    var generatorID: GeneratorID {
        switch self {
        case .seedProcedure:  return .seedProcedure
        case .highMidLow:     return .highMidLow
        case .pulsingBass:    return .pulsingBass
        case .drunkardsWalk:  return .drunkardsWalk
        case .stagedPluck:    return .stagedPluck
        case .arpeggiator:    return .arpeggiator
        case .bassMelody:     return .bassMelody
        case .chordLayer:     return .chordLayer
        case .heartbeat:      return .heartbeat
        case .drone:          return .drone
        }
    }

    /// Most generators draw from the seed stream (used by tests to assert
    /// the seed is not ignored); the bass melody and heartbeat are the
    /// deterministic exceptions.
    var usesRandomness: Bool {
        switch self {
        case .bassMelody, .heartbeat, .drone: return false
        default:                              return true
        }
    }
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
        case let .drunkardsWalk(bars, scatter):
            length = Tick(bars) * meter.ticksPerBar
            notes = drunkardsWalk(bars: bars, scatter: scatter, key: key,
                                  meter: meter, rng: &rng)
        case let .stagedPluck(bars):
            length = Tick(bars) * meter.ticksPerBar
            notes = stagedPluck(bars: bars, meter: meter, rng: &rng)
        case let .arpeggiator(chordDegrees, octaves, direction, rate):
            let expansion = arpeggiate(chordDegrees: chordDegrees, octaves: octaves,
                                       direction: direction, rate: rate,
                                       key: key, meter: meter, rng: &rng)
            length = expansion.length
            notes = expansion.notes
        case let .bassMelody(bars):
            // Without a schedule the walk is a pedal — the real path goes
            // through `makeBassMelody` (OfflineRenderer supplies the
            // resolved transposition schedule).
            return makeBassMelody(id: id, bars: bars, schedule: .pedal,
                                  meter: meter, seed: seed)
        case let .chordLayer(periodBars):
            length = Tick(periodBars) * meter.ticksPerBar
            notes = chordLayer(gate: length, key: key, rng: &rng)
        case .heartbeat:
            length = meter.ticksPerBar
            notes = (0..<meter.beatsPerBar).map {
                PatternNote(position: Tick($0) * meter.ticksPerBeat,
                            pitch: DegreePitch(degree: 0), velocity: 92,
                            gate: meter.ticksPerBeat / 2)
            }
        case let .drone(bars):
            length = Tick(bars) * meter.ticksPerBar
            notes = [PatternNote(position: 0, pitch: DegreePitch(degree: 0),
                                 velocity: 64, gate: length),
                     PatternNote(position: 0, pitch: DegreePitch(degree: 4),
                                 velocity: 60, gate: length)]
        }

        return Pattern(
            id: id, length: length, notes: notes,
            provenance: Provenance(generator: config.generatorID, version: 1, seed: seed)
        )
    }

    /// The §13.3 chord recipe (FR-H-8): 20% home / 80% +1..12 semitones →
    /// quantize → stack +4/+7/+12 → re-quantize. Every tone lands in scale
    /// (`accidental == 0` by quantizer contract) — no bypass here.
    private static func chordLayer(gate: Tick, key: Key,
                                   rng: inout SplitMix64) -> [PatternNote] {
        let referenceC = 60
        let rootMidi = Double.random(in: 0..<1, using: &rng) < 0.2
            ? referenceC
            : referenceC + Int.random(in: 1...12, using: &rng)
        let root = key.quantize(midi: rootMidi, referenceC: referenceC)
        let rootResolved = key.resolve(root, referenceC: referenceC)
        var seen: Set<Int> = []
        var notes: [PatternNote] = []
        for offset in [0, 4, 7, 12] {
            let tone = key.quantize(midi: rootResolved + offset,
                                    referenceC: referenceC)
            let resolved = key.resolve(tone, referenceC: referenceC)
            guard seen.insert(resolved).inserted else { continue }
            notes.append(PatternNote(position: 0, pitch: tone, velocity: 84,
                                     gate: gate))
        }
        return notes
    }

    /// Bass melody (FR-MEL-5, M §8.4): beat 1 states the bar's progression
    /// root; the bar's tail walks stepwise (|Δ| ≤ 2 by construction) toward
    /// the next bar's root — wrapping, so the loop closes on itself.
    public static func makeBassMelody(id: String, bars: Int,
                                      schedule: TranspositionSchedule,
                                      meter: Meter, seed: UInt64) -> Pattern {
        precondition(bars >= 1)
        var notes: [PatternNote] = []
        let beatTicks = meter.ticksPerBeat
        for barIdx in 0..<bars {
            let root = schedule.offset(atBar: barIdx)
            let next = schedule.offset(atBar: (barIdx + 1) % bars)
            let delta = next - root
            let passing = delta == 0
                ? 1                                     // turnaround dip
                : max(0, min(meter.beatsPerBar - 1, abs(delta) - 1))
            let barStart = Tick(barIdx) * meter.ticksPerBar
            let heldBeats = max(1, meter.beatsPerBar - passing)
            notes.append(PatternNote(position: barStart,
                                     pitch: DegreePitch(degree: root),
                                     gate: Tick(heldBeats) * beatTicks,
                                     accent: true))
            var previous = root
            if passing > 0 {
                for k in 1...passing {
                    let degree = delta == 0
                        ? root - 1
                        : root + Int((Double(delta) * Double(k)
                                      / Double(passing + 1)).rounded())
                    guard degree != previous else { continue }
                    let beat = meter.beatsPerBar - passing + (k - 1)
                    notes.append(PatternNote(position: barStart + Tick(beat) * beatTicks,
                                             pitch: DegreePitch(degree: degree),
                                             gate: beatTicks))
                    previous = degree
                }
            }
        }
        return Pattern(id: id, length: Tick(bars) * meter.ticksPerBar,
                       notes: notes,
                       provenance: Provenance(generator: .bassMelody,
                                              version: 1, seed: seed))
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

    // MARK: - Generator 4: drunkard's walk (M §13.2)

    private static func drunkardsWalk(bars: Int, scatter: Int, key: Key,
                                      meter: Meter,
                                      rng: inout SplitMix64) -> [PatternNote] {
        precondition(bars >= 1 && scatter >= 1)
        let stepTicks = step(meter)
        let totalSteps = bars * meter.beatsPerBar * 4
        var notes: [PatternNote] = []

        // The walk's state is the QUANTIZED chromatic offset from the root —
        // guarantees consecutive sounding pitches stay within scatter+1
        // semitones after quantization.
        var offset = 0
        func emit(step index: Int) {
            let candidate = max(-4, min(18, offset + Int.random(in: -scatter...scatter,
                                                                using: &rng)))
            let pitch = key.quantize(midi: 60 + key.root + candidate, referenceC: 60)
            offset = key.resolve(pitch, referenceC: 60) - 60 - key.root
            notes.append(PatternNote(position: Tick(index) * stepTicks, pitch: pitch,
                                     velocity: 100, gate: shortGate(meter, &rng)))
        }

        // Root first (M §5.1 — home base), then burst/rest phrasing:
        // bursts of 2–4 notes, rests of 2–4 steps ("random but with a
        // pleasing distribution of hit groups vs rests").
        notes.append(PatternNote(position: 0, pitch: DegreePitch(degree: 0),
                                 velocity: 100, gate: shortGate(meter, &rng)))
        var burstLeft = Int.random(in: 1...3, using: &rng)   // root consumed one
        var restLeft = 0
        for index in 1..<totalSteps {
            if burstLeft > 0 {
                emit(step: index)
                burstLeft -= 1
                if burstLeft == 0 { restLeft = Int.random(in: 2...4, using: &rng) }
            } else {
                restLeft -= 1
                if restLeft <= 0 { burstLeft = Int.random(in: 2...4, using: &rng) }
            }
        }
        return notes
    }

    // MARK: - Generator 5: staged pluck build (M §5.6)

    private static func stagedPluck(bars: Int, meter: Meter,
                                    rng: inout SplitMix64) -> [PatternNote] {
        precondition(bars >= 1)
        let stepTicks = step(meter)
        let stepsPerBar = meter.beatsPerBar * 4
        let length = Tick(bars) * meter.ticksPerBar
        var occupied = Set<Tick>()
        var notes: [PatternNote] = []

        func add(_ position: Tick, _ pitch: DegreePitch, accent: Bool = false,
                 velocity: UInt8 = 100) {
            guard !occupied.contains(position) else { return }
            occupied.insert(position)
            notes.append(PatternNote(position: position, pitch: pitch,
                                     velocity: velocity,
                                     gate: shortGate(meter, &rng), accent: accent))
        }

        let syncopationPool = [2, 3, 5, 6, 7, 9, 10, 11, 13, 14]
        for barIndex in 0..<bars {
            let barStart = Tick(barIndex) * meter.ticksPerBar
            // Stage 1: home base — the root on the downbeat + 2 syncopated roots.
            add(barStart, DegreePitch(degree: 0))
            var syncopes: [Tick] = []
            for _ in 0..<2 {
                let pick = syncopationPool.randomElement(using: &rng)!
                let position = barStart + Tick(pick) * stepTicks
                syncopes.append(position)
                add(position, DegreePitch(degree: 0))
            }
            // Stage 2: octave jumps — first bar always gets one (M §5.6).
            if let target = syncopes.first(where: { occupied.contains($0) && $0 != 0 }),
               barIndex == 0 || Bool.random(using: &rng) {
                if let idx = notes.firstIndex(where: { $0.position == target }) {
                    notes[idx].pitch.octave = 1
                }
            }
            // Stage 3: fill with scale notes between the roots.
            for _ in 0..<2 {
                let pick = Int.random(in: 0..<stepsPerBar, using: &rng)
                add(barStart + Tick(pick) * stepTicks,
                    DegreePitch(degree: Int.random(in: 1...4, using: &rng)))
            }
            // Stage 4: high micro-melody in the final bar (degrees 4–7).
            if barIndex == bars - 1 {
                for _ in 0..<2 {
                    let pick = Int.random(in: 0..<stepsPerBar, using: &rng)
                    add(barStart + Tick(pick) * stepTicks,
                        DegreePitch(degree: Int.random(in: 4...7, using: &rng)))
                }
            }
        }
        // Stage 5: the signature closing note — accented, on the last step
        // ("the signature of the pattern, a sort of closing", M §5.6).
        let lastStep = length - stepTicks
        notes.removeAll { $0.position == lastStep }
        occupied.remove(lastStep)
        add(lastStep, DegreePitch(degree: Int.random(in: 5...6, using: &rng)),
            accent: true)
        return notes
    }

    // MARK: - Generator 6: arpeggiator expansion (M §5.9)

    private static func arpeggiate(chordDegrees: [Int], octaves: Int,
                                   direction: ArpDirection, rate: ArpRate,
                                   key: Key, meter: Meter,
                                   rng: inout SplitMix64) -> (length: Tick, notes: [PatternNote]) {
        precondition(!chordDegrees.isEmpty && chordDegrees.first == 0,
                     "chord must start on the root")
        precondition(chordDegrees == chordDegrees.sorted()
                     && Set(chordDegrees).count == chordDegrees.count)
        precondition(chordDegrees.allSatisfy { (0..<key.scale.count).contains($0) })
        precondition((1...2).contains(octaves), "span cap ≤ 2 octaves (FR-P-2)")

        // All chord tones across the octave range, ascending.
        var ascending: [Int] = []
        for octave in 0..<octaves {
            for degree in chordDegrees {
                ascending.append(degree + octave * key.scale.count)
            }
        }

        let cycle: [Int]
        switch direction {
        case .up:
            cycle = ascending
        case .down:
            // Descending, rotated to begin on the highest ROOT so the first
            // sounding note is a root pitch class (FR-P-2).
            let descending = ascending.reversed().map { $0 }
            let rootIndex = descending.firstIndex {
                floorMod($0, key.scale.count) == 0
            } ?? 0
            cycle = Array(descending[rootIndex...] + descending[..<rootIndex])
        case .upDown:
            // Up, then down through the interior (endpoints visited once).
            cycle = ascending + ascending.dropFirst().dropLast().reversed()
        }

        let stepTicks = rate.stepTicks
        let notes = cycle.enumerated().map { index, degree in
            PatternNote(position: Tick(index) * stepTicks,
                        pitch: DegreePitch(degree: degree),
                        velocity: 100, gate: shortGate(meter, &rng))
        }
        return (Tick(cycle.count) * stepTicks, notes)
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
