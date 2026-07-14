import Testing
@testable import BerlinanEngine

private let key = Key.default                 // C natural minor
private let meter = Meter.fourFour
private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

private func note(_ position: Tick, degree: Int = 0, octave: Int = 0) -> PatternNote {
    PatternNote(position: position, pitch: DegreePitch(degree: degree, octave: octave),
                velocity: 100, gate: 120)
}

private func voice(_ id: String, notes: [PatternNote], length: Tick = bar,
                   register: RegisterWindow = RegisterWindow(low: 48, high: 84),
                   referenceC: Int = 60, participates: Bool = true) -> Voice {
    let p = Pattern(id: "\(id)/p", length: length, notes: notes,
                    provenance: Provenance(generator: .handEdited, version: 1, seed: 0))
    return Voice(id: id, role: .bedPluck1, register: register, referenceC: referenceC,
                 pattern: p, participatesInTransposition: participates)
}

// MARK: - Schedule

@Suite("Transposition schedule")
struct ScheduleTests {

    @Test("Empty schedule = pedal on the root (FR-H-1)")
    func pedal() {
        let s = TranspositionSchedule.pedal
        for barIndex in [0, 1, 7, 100] {
            #expect(s.offset(atBar: barIndex) == 0)
        }
    }

    @Test("Events partition the timeline; before the first event = 0")
    func partitions() {
        let s = TranspositionSchedule(events: [
            TranspositionEvent(bar: 4, degreeOffset: 3),
            TranspositionEvent(bar: 8, degreeOffset: 0),
        ])
        #expect(s.offset(atBar: 0) == 0)
        #expect(s.offset(atBar: 3) == 0)
        #expect(s.offset(atBar: 4) == 3)
        #expect(s.offset(atBar: 7) == 3)
        #expect(s.offset(atBar: 8) == 0)
        #expect(s.offset(atBar: 64) == 0)
    }

    @Test("Unsorted input is normalized; same-bar duplicates last-wins")
    func normalization() {
        let s = TranspositionSchedule(events: [
            TranspositionEvent(bar: 8, degreeOffset: -2),
            TranspositionEvent(bar: 2, degreeOffset: 5),
            TranspositionEvent(bar: 2, degreeOffset: 1),
        ])
        #expect(s.offset(atBar: 2) == 1)      // last one for bar 2 wins
        #expect(s.offset(atBar: 8) == -2)
        #expect(s.events.map(\.bar) == s.events.map(\.bar).sorted())
    }
}

// MARK: - Bar quantization of change requests (FR-H-3)

@Suite("Quantized event bar")
struct QuantizeBarTests {

    @Test("Mid-bar request lands on the next bar; exact boundary maps to itself")
    func nextBar() {
        #expect(HarmonyEngine.quantizedEventBar(requestTick: 0, meter: meter) == 0)
        #expect(HarmonyEngine.quantizedEventBar(requestTick: 1, meter: meter) == 1)
        #expect(HarmonyEngine.quantizedEventBar(requestTick: 2 * bar + beat, meter: meter) == 3)
        #expect(HarmonyEngine.quantizedEventBar(requestTick: 3 * bar, meter: meter) == 3)
    }

    @Test("Larger quanta snap to multiples (2/4/8 bars)")
    func quanta() {
        #expect(HarmonyEngine.quantizedEventBar(requestTick: bar + 1, meter: meter, quantumBars: 4) == 4)
        #expect(HarmonyEngine.quantizedEventBar(requestTick: 4 * bar, meter: meter, quantumBars: 4) == 4)
        #expect(HarmonyEngine.quantizedEventBar(requestTick: 4 * bar + 1, meter: meter, quantumBars: 4) == 8)
        #expect(HarmonyEngine.quantizedEventBar(requestTick: 5 * bar, meter: meter, quantumBars: 2) == 6)
    }
}

// MARK: - Rendering pipeline (FR-H-2, Law 2)

@Suite("Harmony rendering")
struct HarmonyRenderTests {

    @Test("Diatonic offsets in C minor: +2→Eb, +4→G, +5→Ab")
    func diatonicOffsets() {
        let v = voice("a", notes: [note(0)])
        for (offset, expected) in [(0, 60), (2, 63), (4, 67), (5, 68)] {
            let s = TranspositionSchedule(events: [TranspositionEvent(bar: 0, degreeOffset: offset)])
            let out = HarmonyEngine.render(voices: [v], schedule: s, key: key,
                                           meter: meter, in: 0..<bar)
            #expect(out.map { Int($0.midiNote) } == [expected])
        }
    }

    @Test("The i→VI→iv→i walk renders C–Ab–F–C (M §7.1 progressions as offsets)")
    func bassWalk() {
        // One root note per bar; schedule moves the degree offset per bar.
        let v = voice("bass", notes: [note(0)], length: bar,
                      register: RegisterWindow(low: 55, high: 79), referenceC: 60)
        let s = TranspositionSchedule(events: [
            TranspositionEvent(bar: 0, degreeOffset: 0),
            TranspositionEvent(bar: 1, degreeOffset: 5),   // VI = Ab
            TranspositionEvent(bar: 2, degreeOffset: 3),   // iv = F
            TranspositionEvent(bar: 3, degreeOffset: 0),
        ])
        let out = HarmonyEngine.render(voices: [v], schedule: s, key: key,
                                       meter: meter, in: 0..<(4 * bar))
        #expect(out.map { Int($0.midiNote) } == [60, 68, 65, 60])
    }

    @Test("Law 2 property: any offset −7…+7 keeps every note in scale")
    func law2() {
        var rng = SplitMix64(seed: 0x1A72)
        let classes = Set(key.scale.offsets)
        let v = voice("a", notes: [note(0), note(beat, degree: 2), note(2 * beat, degree: 4)])
        for _ in 0..<200 {
            let offset = Int.random(in: -7...7, using: &rng)
            let s = TranspositionSchedule(events: [TranspositionEvent(bar: 0, degreeOffset: offset)])
            let out = HarmonyEngine.render(voices: [v], schedule: s, key: key,
                                           meter: meter, in: 0..<bar)
            for n in out {
                let pc = floorMod(Int(n.midiNote) - key.root, 12)
                #expect(classes.contains(pc))
            }
        }
    }

    @Test("Per-voice opt-out: lead stays while the bed transposes (FR-H-2)")
    func optOut() {
        let bed = voice("bed", notes: [note(0)])
        let lead = voice("lead", notes: [note(0)], participates: false)
        let s = TranspositionSchedule(events: [TranspositionEvent(bar: 0, degreeOffset: 4)])
        let out = HarmonyEngine.render(voices: [bed, lead], schedule: s, key: key,
                                       meter: meter, in: 0..<bar)
        #expect(out.first { $0.voiceID == "bed" }!.midiNote == 67)
        #expect(out.first { $0.voiceID == "lead" }!.midiNote == 60)
    }

    @Test("Bar precision: the new offset binds exactly at the bar-start tick")
    func barPrecision() {
        // Loop of one bar length with notes at the last tick and at 0.
        let v = voice("a", notes: [note(0), note(bar - 1)])
        let s = TranspositionSchedule(events: [TranspositionEvent(bar: 1, degreeOffset: 4)])
        let out = HarmonyEngine.render(voices: [v], schedule: s, key: key,
                                       meter: meter, in: 0..<(2 * bar))
        // at 0 → C, at bar−1 → C (old), at bar → G (new), at 2bar−1 → G
        #expect(out.map { Int($0.midiNote) } == [60, 60, 67, 67])
    }

    @Test("Register fold applies after transposition")
    func foldAfterTranspose() {
        let v = voice("a", notes: [note(0, octave: 1)],
                      register: RegisterWindow(low: 55, high: 70))
        let s = TranspositionSchedule(events: [TranspositionEvent(bar: 0, degreeOffset: 4)])
        // degree 0+4, octave 1 → 67+12 = 79 → fold → 67 (inside 55...70)
        let out = HarmonyEngine.render(voices: [v], schedule: s, key: key,
                                       meter: meter, in: 0..<bar)
        #expect(out.map { Int($0.midiNote) } == [67])
    }

    @Test("Velocity, gate, accent and ratchet pass through unchanged")
    func passthrough() {
        var n = note(0)
        n.velocity = 87; n.gate = 133; n.accent = true; n.ratchet = 3
        let v = voice("a", notes: [n])
        let out = HarmonyEngine.render(voices: [v], schedule: .pedal, key: key,
                                       meter: meter, in: 0..<bar)
        #expect(out.count == 1)
        #expect(out[0].velocity == 87)
        #expect(out[0].gate == 133)
        #expect(out[0].accent)
        #expect(out[0].ratchet == 3)
    }
}
