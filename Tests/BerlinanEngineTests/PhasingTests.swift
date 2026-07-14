import Testing
@testable import BerlinanEngine

private let sixteenth: Tick = Time.ppqn / 4          // 240
private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat
private let meter = Meter.fourFour

private func note(_ position: Tick, degree: Int = 0) -> PatternNote {
    PatternNote(position: position, pitch: DegreePitch(degree: degree),
                velocity: 100, gate: 120)
}

private func pattern(_ id: String = "p", length: Tick, startOffset: Tick = 0,
                     notes: [PatternNote]) -> Pattern {
    Pattern(id: id, length: length, startOffset: startOffset, notes: notes,
            provenance: Provenance(generator: .handEdited, version: 1, seed: 0))
}

private func voice(_ id: String, _ p: Pattern) -> Voice {
    Voice(id: id, role: .bedPluck1, register: RegisterWindow(low: 48, high: 84),
          referenceC: 60, pattern: p)
}

// MARK: - Length change & rotation ops

@Suite("Phasing ops")
struct PhasingOpsTests {

    @Test("Truncation drops notes at or beyond the new end")
    func truncate() {
        let p = pattern(length: 16 * sixteenth,
                        notes: [note(0), note(7 * sixteenth), note(15 * sixteenth)])
        let t = p.withLength(15 * sixteenth)
        #expect(t.length == 15 * sixteenth)
        #expect(t.notes.map(\.position) == [0, 7 * sixteenth])
    }

    @Test("Extension preserves every note")
    func extend() {
        let p = pattern(length: bar, notes: [note(0), note(2 * beat)])
        let e = p.withLength(bar + beat)
        #expect(e.length == bar + beat)
        #expect(e.notes == p.notes)
    }

    @Test("Rotation composes with the existing offset and normalizes")
    func rotate() {
        let p = pattern(length: bar, notes: [note(0)])
        #expect(p.rotated(by: 2 * sixteenth).startOffset == 2 * sixteenth)
        #expect(p.rotated(by: bar + sixteenth).startOffset == sixteenth)
        #expect(p.rotated(by: -sixteenth).startOffset == bar - sixteenth)
    }

    @Test("phasedCopy: FR-PH-2 one-action setup — new length, new id, same notes")
    func phasedCopy() {
        let p = pattern("bed1/gen0", length: 16 * sixteenth,
                        notes: [note(0), note(4 * sixteenth)])
        let c = PhasingOps.phasedCopy(of: p, newLength: 15 * sixteenth, idSuffix: "phased")
        #expect(c.length == 15 * sixteenth)
        #expect(c.id == "bed1/gen0/phased")
        #expect(c.notes == p.notes)          // all inside 15 steps here
        #expect(p.length == 16 * sixteenth)  // source untouched
    }
}

// MARK: - The Reich drift (M §6.1)

@Suite("Length-mismatch phasing")
struct DriftTests {

    /// A 15-step copy against a 16-step master traverses ALL 16 relative
    /// offsets (unison + "15 automatic variations") before re-sync.
    @Test("16 vs 15 steps: 16 distinct relative offsets over one convergence")
    func fifteenAgainstSixteen() {
        let master = 16 * sixteenth
        let copy = pattern(length: 15 * sixteenth, notes: [note(0)])
        let period = Convergence.period(lengths: [master, 15 * sixteenth])!
        let onsets = copy.occurrences(in: 0..<period).map(\.at)
        let offsets = Set(onsets.map { Int(floorMod(Int($0), Int(master))) / Int(sixteenth) })
        #expect(offsets.count == 16)
        #expect(period == 15 * master)   // 15 bars of the 16-step master
    }

    /// gcd(14, 16) = 2 → only 8 offsets (unison + 7 variations), stepping
    /// through offsets twice as fast [M §6.1].
    @Test("16 vs 14 steps: 8 distinct relative offsets")
    func fourteenAgainstSixteen() {
        let master = 16 * sixteenth
        let copy = pattern(length: 14 * sixteenth, notes: [note(0)])
        let period = Convergence.period(lengths: [master, 14 * sixteenth])!
        let onsets = copy.occurrences(in: 0..<period).map(\.at)
        let offsets = Set(onsets.map { Int(floorMod(Int($0), Int(master))) / Int(sixteenth) })
        #expect(offsets.count == 8)
    }
}

// MARK: - Convergence math (FR-PH-4)

@Suite("Convergence")
struct ConvergenceTests {

    @Test("16v15 sixteenths converge after 15 bars of 4/4")
    func sixteenFifteen() {
        let period = Convergence.period(lengths: [16 * sixteenth, 15 * sixteenth])!
        #expect(Convergence.bars(period: period, meter: meter) == 15.0)
    }

    @Test("Chord-tone polymeter 16/24/19 steps → 57 bars [M §6.3]")
    func chordTone() {
        let period = Convergence.period(
            lengths: [16 * sixteenth, 24 * sixteenth, 19 * sixteenth])!
        #expect(Convergence.bars(period: period, meter: meter) == 57.0)
    }

    @Test("Identical lengths converge every loop")
    func trivial() {
        let period = Convergence.period(lengths: [bar, bar])!
        #expect(period == bar)
    }

    @Test("Overflow-prone lengths return nil (practically infinite)")
    func overflow() {
        let a: Tick = (1 << 40) + 1   // coprime giants — product overflows Int64
        let b: Tick = (1 << 40) - 1
        #expect(Convergence.period(lengths: [a, b]) == nil)
    }

    @Test("Wall-clock length of the convergence period")
    func seconds() {
        // 15 bars of 4/4 at 90 BPM = 15 * 4 * (60/90) s = 40 s
        let period = Convergence.period(lengths: [16 * sixteenth, 15 * sixteenth])!
        #expect(abs(Convergence.seconds(period: period, bpm: 90) - 40.0) < 1e-9)
    }
}

// MARK: - Multi-voice event stream (FR-PH-1)

@Suite("PhasingEngine event stream")
struct EnsembleTests {

    @Test("Merged stream is time-sorted and voice-tagged")
    func mergedSorted() {
        let a = voice("a", pattern(length: bar, notes: [note(0), note(2 * beat)]))
        let b = voice("b", pattern(length: 3 * beat, notes: [note(beat)]))
        let events = PhasingEngine.events(voices: [a, b], in: 0..<(2 * bar))
        #expect(events.map(\.at) == events.map(\.at).sorted())
        // Voice b's note at local 1 beat, loop 3 beats → global 1, 4, 7 beats.
        #expect(events.filter { $0.voiceID == "b" }.map(\.at) == [beat, 4 * beat, 7 * beat])
        // Voice a: 0, 2, 4, 6 beats.
        #expect(events.filter { $0.voiceID == "a" }.map(\.at) == [0, 2 * beat, 4 * beat, 6 * beat])
    }

    @Test("Half-open windows chain without duplication or loss")
    func windowChaining() {
        let voices = [
            voice("a", pattern(length: 15 * sixteenth, notes: [note(0), note(5 * sixteenth)])),
            voice("b", pattern(length: bar, notes: [note(0), note(3 * beat)])),
        ]
        let whole = PhasingEngine.events(voices: voices, in: 0..<(4 * bar))
        var chained: [EnsembleEvent] = []
        let windowSize: Tick = 1000   // deliberately unaligned with anything
        var start: Tick = 0
        while start < 4 * bar {
            let end = min(start + windowSize, 4 * bar)
            chained.append(contentsOf: PhasingEngine.events(voices: voices, in: start..<end))
            start = end
        }
        #expect(chained == whole)
    }

    @Test("Muted-equivalent: empty voice list yields empty stream")
    func emptyVoices() {
        #expect(PhasingEngine.events(voices: [], in: 0..<bar).isEmpty)
    }
}
