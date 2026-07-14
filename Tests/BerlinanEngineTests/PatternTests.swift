import Foundation
import Testing
@testable import BerlinanEngine

// Shared fixtures
private let sixteenth: Tick = Time.ppqn / 4          // 240
private let beat: Tick = Time.ppqn                   // 960
private let bar: Tick = 4 * beat                     // 3840 (4/4)

private func note(_ position: Tick, degree: Int = 0, octave: Int = 0,
                  velocity: UInt8 = 100, gate: Tick = 120,
                  accent: Bool = false) -> PatternNote {
    PatternNote(position: position, pitch: DegreePitch(degree: degree, octave: octave),
                velocity: velocity, gate: gate, accent: accent)
}

private func pattern(length: Tick, startOffset: Tick = 0, notes: [PatternNote]) -> Pattern {
    Pattern(id: "test", length: length, startOffset: startOffset, notes: notes,
            provenance: Provenance(generator: .handEdited, version: 1, seed: 0))
}

// MARK: - Occurrences (loop-cursor math)

@Suite("Pattern occurrences")
struct OccurrenceTests {

    @Test("Notes repeat at loop-length intervals across a range")
    func loopRepeats() {
        let p = pattern(length: 2 * beat, notes: [note(0), note(beat)])
        let occ = p.occurrences(in: 0..<(6 * beat))
        #expect(occ.map(\.at) == [0, beat, 2 * beat, 3 * beat, 4 * beat, 5 * beat])
    }

    @Test("Half-open range semantics: start inclusive, end exclusive")
    func halfOpen() {
        let p = pattern(length: beat, notes: [note(0)])
        #expect(p.occurrences(in: 0..<beat).count == 1)
        #expect(p.occurrences(in: beat..<(2 * beat)).map(\.at) == [beat])
        #expect(p.occurrences(in: 1..<beat).isEmpty)
    }

    @Test("Mid-loop range picks up only covered notes")
    func midLoop() {
        let p = pattern(length: 2 * beat, notes: [note(0), note(beat + sixteenth)])
        let occ = p.occurrences(in: beat..<(2 * beat))
        #expect(occ.map(\.at) == [beat + sixteenth])
    }

    @Test("Non-power-of-two length (15 sixteenths — the phasing workhorse)")
    func fifteenSteps() {
        let len = 15 * sixteenth
        let p = pattern(length: len, notes: [note(0)])
        let occ = p.occurrences(in: 0..<(4 * len))
        #expect(occ.map(\.at) == [0, len, 2 * len, 3 * len])
    }

    @Test("Rotation: startOffset shifts sounding times (localTick = global + offset mod length)")
    func rotation() {
        // Note at position 2 steps; offset 2 steps → sounds at global 0, then every loop.
        let p = pattern(length: beat, startOffset: 2 * sixteenth,
                        notes: [note(2 * sixteenth)])
        let occ = p.occurrences(in: 0..<(2 * beat))
        #expect(occ.map(\.at) == [0, beat])
    }

    @Test("Occurrences are sorted by time")
    func sorted() {
        let p = pattern(length: beat, notes: [note(3 * sixteenth), note(0), note(2 * sixteenth)])
        let occ = p.occurrences(in: 0..<(2 * beat))
        #expect(occ.map(\.at) == occ.map(\.at).sorted())
    }
}

// MARK: - Invariant helpers

@Suite("Pattern invariant helpers")
struct PatternInvariantTests {

    @Test("firstSoundingIsRoot: true for root (any octave/degree multiple), false otherwise")
    func firstSoundingRoot() {
        let scaleCount = 7
        #expect(pattern(length: bar, notes: [note(0, degree: 0)]).firstSoundingIsRoot(scaleCount: scaleCount))
        #expect(pattern(length: bar, notes: [note(0, degree: 7)]).firstSoundingIsRoot(scaleCount: scaleCount))
        #expect(pattern(length: bar, notes: [note(0, degree: -7, octave: 1)]).firstSoundingIsRoot(scaleCount: scaleCount))
        #expect(!pattern(length: bar, notes: [note(0, degree: 4)]).firstSoundingIsRoot(scaleCount: scaleCount))
        // Pattern may start with a rest — the EARLIEST note decides (M §5.1).
        #expect(pattern(length: bar, notes: [note(beat, degree: 0), note(2 * beat, degree: 3)])
            .firstSoundingIsRoot(scaleCount: scaleCount))
        #expect(!pattern(length: bar, notes: [note(2 * beat, degree: 0), note(beat, degree: 3)])
            .firstSoundingIsRoot(scaleCount: scaleCount))
    }
}

// MARK: - Anchor policy (FR-V-5)

@Suite("Anchor policy")
struct AnchorTests {

    let meter = Meter.fourFour

    private func voice(_ p: Pattern, policy: AnchorPolicy) -> Voice {
        Voice(id: "bass", role: .bass, register: RegisterWindow(low: 24, high: 48),
              referenceC: 36, pattern: p, anchorPolicy: policy)
    }

    @Test("beats1and3 requires onsets at local ticks 0 and 2 beats")
    func beats13() {
        let ok = pattern(length: bar, notes: [note(0), note(2 * beat)])
        let missing = pattern(length: bar, notes: [note(0), note(beat)])
        #expect(voice(ok, policy: .beats1and3).satisfiesAnchor(meter: meter))
        #expect(!voice(missing, policy: .beats1and3).satisfiesAnchor(meter: meter))
    }

    @Test("beat1 requires only the downbeat")
    func beat1() {
        let p = pattern(length: bar, notes: [note(0), note(beat + sixteenth)])
        #expect(voice(p, policy: .beat1).satisfiesAnchor(meter: meter))
        let offbeat = pattern(length: bar, notes: [note(sixteenth)])
        #expect(!voice(offbeat, policy: .beat1).satisfiesAnchor(meter: meter))
    }

    @Test("none always passes")
    func nonePolicy() {
        let p = pattern(length: bar, notes: [note(sixteenth)])
        #expect(voice(p, policy: .none).satisfiesAnchor(meter: meter))
    }

    @Test("Rotation is honored: onset must SOUND on the anchor tick")
    func rotationAware() {
        // Note at position 2 beats, offset 2 beats → sounds at global 0 —
        // but nothing sounds at global 2 beats unless another note covers it.
        let p = pattern(length: bar, startOffset: 2 * beat,
                        notes: [note(2 * beat), note(0)])
        // note(2*beat) sounds at 0; note(0) sounds at 2 beats (local 0 == global 2b + offset mod bar)
        #expect(voice(p, policy: .beats1and3).satisfiesAnchor(meter: meter))
    }

    @Test("Pattern shorter than a bar must still cover every bar's anchors (LCM check)")
    func subBarPattern() {
        // 1-beat loop with a note at 0 sounds on EVERY beat — covers 1 and 3. OK.
        let everyBeat = pattern(length: beat, notes: [note(0)])
        #expect(voice(everyBeat, policy: .beats1and3).satisfiesAnchor(meter: meter))
        // 3-beat loop with a note at 0: sounds at 0, 3, 6, 9... — misses beat 3
        // (tick 2*beat) in bar 1 → must fail.
        let threeBeat = pattern(length: 3 * beat, notes: [note(0)])
        #expect(!voice(threeBeat, policy: .beats1and3).satisfiesAnchor(meter: meter))
    }
}

// MARK: - Codable round-trips (persistence base, spec §10)

@Suite("Pattern/Voice Codable")
struct CodableTests {

    @Test("Pattern survives a JSON round-trip")
    func patternRoundTrip() throws {
        let p = Pattern(
            id: "bedPluck1/gen3", length: 15 * sixteenth, startOffset: 2 * sixteenth,
            notes: [note(0, degree: 0, accent: true), note(4 * sixteenth, degree: 4)],
            gateCycle: [GateStep(on: true, width: 0.5), GateStep(on: false, width: 0.5)],
            gateCycleLength: 2 * sixteenth,
            provenance: Provenance(generator: .seedProcedure, version: 1, seed: 0xDEAD),
            locked: true,
            lifecycle: .repeating(remaining: 3)
        )
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(Pattern.self, from: data)
        #expect(back == p)
    }

    @Test("Voice survives a JSON round-trip")
    func voiceRoundTrip() throws {
        let v = Voice(
            id: "bass", role: .bass,
            register: RegisterWindow(low: 24, high: 48), referenceC: 36,
            pattern: pattern(length: bar, notes: [note(0)]),
            participatesInTransposition: false,
            anchorPolicy: .beats1and3, densityCap: 6
        )
        let data = try JSONEncoder().encode(v)
        let back = try JSONDecoder().decode(Voice.self, from: data)
        #expect(back == v)
    }
}

// MARK: - Math helpers

@Suite("Tick math")
struct MathTests {

    @Test("lcm of loop lengths")
    func lcmBasics() {
        #expect(lcm(Tick(16), Tick(15)) == 240)
        #expect(lcm(Tick(3840), Tick(960)) == 3840)
        #expect(lcm(Tick(16), Tick(24), Tick(19)) == 912)
    }
}
