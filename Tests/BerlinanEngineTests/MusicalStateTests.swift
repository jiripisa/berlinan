import Testing
@testable import BerlinanEngine

// MARK: - Time

@Suite("Meter tick math")
struct MeterTests {

    @Test("4/4: quarter-note beats at 960 PPQN")
    func fourFour() {
        let m = Meter.fourFour
        #expect(m.ticksPerBeat == 960)
        #expect(m.ticksPerBar == 3840)
    }

    @Test("7/8: eighth-note beats")
    func sevenEight() {
        let m = Meter(beatsPerBar: 7, beatUnit: 8, grouping: [4, 3])
        #expect(m.ticksPerBeat == 480)
        #expect(m.ticksPerBar == 3360)
    }

    @Test("6/8 and 5/4 bars")
    func oddMeters() {
        #expect(Meter(beatsPerBar: 6, beatUnit: 8).ticksPerBar == 2880)
        #expect(Meter(beatsPerBar: 5, beatUnit: 4).ticksPerBar == 4800)
    }
}

// MARK: - Scale presets (manual §4.2)

@Suite("Scale presets")
struct ScalePresetTests {

    @Test("Preset offsets match the manual")
    func presetOffsets() {
        #expect(Scale.preset(.naturalMinor).offsets == [0, 2, 3, 5, 7, 8, 10])
        #expect(Scale.preset(.dorian).offsets == [0, 2, 3, 5, 7, 9, 10])
        #expect(Scale.preset(.phrygian).offsets == [0, 1, 3, 5, 7, 8, 10])
        #expect(Scale.preset(.mixolydian).offsets == [0, 2, 4, 5, 7, 9, 10])
        #expect(Scale.preset(.lydian).offsets == [0, 2, 4, 6, 7, 9, 11])
        #expect(Scale.preset(.lydianDominant).offsets == [0, 2, 4, 6, 7, 9, 10])
        #expect(Scale.preset(.harmonicMinor).offsets == [0, 2, 3, 5, 7, 8, 11])
        #expect(Scale.preset(.minorPentatonic).offsets == [0, 3, 5, 7, 10])
        #expect(Scale.preset(.locrian).offsets == [0, 1, 3, 5, 6, 8, 10])
        #expect(Scale.preset(.major).offsets == [0, 2, 4, 5, 7, 9, 11])
    }

    @Test("All presets are normalized: start at 0, strictly ascending, within one octave")
    func presetInvariants() {
        for mode in ModeID.allCases where mode != .custom {
            let s = Scale.preset(mode)
            #expect(s.offsets.first == 0)
            #expect(s.offsets == s.offsets.sorted())
            #expect(Set(s.offsets).count == s.offsets.count)
            #expect(s.offsets.allSatisfy { (0...11).contains($0) })
        }
    }
}

// MARK: - Degree resolution (spec §6.2 — the only degree→MIDI path)

@Suite("DegreePitch resolution")
struct ResolutionTests {

    let cMinor = Key(root: 0, scale: .preset(.naturalMinor))

    @Test("C minor at referenceC 60")
    func cMinorBasics() {
        #expect(cMinor.resolve(DegreePitch(degree: 0), referenceC: 60) == 60)   // C
        #expect(cMinor.resolve(DegreePitch(degree: 2), referenceC: 60) == 63)   // Eb
        #expect(cMinor.resolve(DegreePitch(degree: 4), referenceC: 60) == 67)   // G
        #expect(cMinor.resolve(DegreePitch(degree: 7), referenceC: 60) == 72)   // C, next octave
        #expect(cMinor.resolve(DegreePitch(degree: 0, octave: -1), referenceC: 60) == 48)
    }

    @Test("Negative degrees descend through the scale")
    func negativeDegrees() {
        // degree -1 = Bb below the root: 60 + (10 - 12) = 58
        #expect(cMinor.resolve(DegreePitch(degree: -1), referenceC: 60) == 58)
        // degree -7 = full octave down
        #expect(cMinor.resolve(DegreePitch(degree: -7), referenceC: 60) == 48)
    }

    @Test("Non-zero root shifts everything")
    func rootShift() {
        let aMinor = Key(root: 9, scale: .preset(.naturalMinor))
        #expect(aMinor.resolve(DegreePitch(degree: 0), referenceC: 60) == 69)   // A
        #expect(aMinor.resolve(DegreePitch(degree: 2), referenceC: 60) == 72)   // C
    }

    @Test("Accidental is a raw semitone offset (tension budget only)")
    func accidental() {
        #expect(cMinor.resolve(DegreePitch(degree: 0, accidental: 1), referenceC: 60) == 61)
    }

    @Test("Property: resolved pitch class is always in the scale (accidental 0)")
    func inScaleProperty() {
        var rng = SplitMix64(seed: 0xBE71)
        let classes = Set(Scale.preset(.naturalMinor).offsets)
        for _ in 0..<500 {
            let p = DegreePitch(degree: Int.random(in: -21...21, using: &rng),
                                octave: Int.random(in: -2...2, using: &rng))
            let midi = cMinor.resolve(p, referenceC: 60)
            let pc = ((midi - 60) % 12 + 12) % 12
            #expect(classes.contains(pc))
        }
    }
}

// MARK: - Register window fold (FR-V-3: fold, never clamp)

@Suite("RegisterWindow octave fold")
struct FoldTests {

    @Test("Inside stays, outside folds by octaves")
    func basics() {
        let w = RegisterWindow(low: 36, high: 60)
        #expect(w.fold(48) == 48)
        #expect(w.fold(72) == 60)   // -12
        #expect(w.fold(84) == 60)   // -24
        #expect(w.fold(24) == 36)   // +12
        #expect(w.fold(61) == 49)   // one above high → fold down
    }

    @Test("Property: result inside window, pitch class preserved")
    func foldProperty() {
        var rng = SplitMix64(seed: 0xF01D)
        for _ in 0..<500 {
            let low = Int.random(in: 0...80, using: &rng)
            let span = Int.random(in: 11...40, using: &rng)
            let w = RegisterWindow(low: UInt8(low), high: UInt8(min(low + span, 127)))
            let note = Int.random(in: -20...150, using: &rng)
            let folded = Int(w.fold(note))
            #expect(folded >= Int(w.low) && folded <= Int(w.high))
            #expect(((folded - note) % 12 + 12) % 12 == 0)
        }
    }
}

// MARK: - Chromatic quantization (ties go DOWN — spec §7.1)

@Suite("Chromatic quantize")
struct QuantizeTests {

    let cMajor = Key(root: 0, scale: .preset(.major))
    let cMinor = Key(root: 0, scale: .preset(.naturalMinor))

    @Test("In-scale notes are idempotent")
    func idempotent() {
        for midi in [60, 62, 63, 65, 67, 68, 70, 72] {   // C minor scale tones
            let p = cMinor.quantize(midi: midi, referenceC: 60)
            #expect(cMinor.resolve(p, referenceC: 60) == midi)
            #expect(p.accidental == 0)
        }
    }

    @Test("Equidistant ties resolve downward")
    func tiesDown() {
        // C# (61) in C major: C (60) and D (62) both 1 semitone away → C
        let p = cMajor.quantize(midi: 61, referenceC: 60)
        #expect(cMajor.resolve(p, referenceC: 60) == 60)
    }

    @Test("Property: output is in scale and within 6 semitones of input")
    func quantizeProperty() {
        var rng = SplitMix64(seed: 0x0A11)
        let classes = Set(Scale.preset(.minorPentatonic).offsets)
        let key = Key(root: 5, scale: .preset(.minorPentatonic))   // F minor pentatonic
        for _ in 0..<500 {
            let midi = Int.random(in: 24...108, using: &rng)
            let p = key.quantize(midi: midi, referenceC: 60)
            let out = key.resolve(p, referenceC: 60)
            let pc = ((out - 60 - 5) % 12 + 12) % 12
            #expect(classes.contains(pc))
            #expect(abs(out - midi) <= 6)
        }
    }
}

// MARK: - Deterministic RNG (NFR-4)

@Suite("SplitMix64 & seed streams")
struct RandTests {

    @Test("Same seed, same sequence")
    func determinism() {
        var a = SplitMix64(seed: 42)
        var b = SplitMix64(seed: 42)
        for _ in 0..<100 { #expect(a.next() == b.next()) }
    }

    @Test("Different seeds diverge")
    func divergence() {
        var a = SplitMix64(seed: 1)
        var b = SplitMix64(seed: 2)
        #expect(a.next() != b.next())
    }

    @Test("SeedStream.derive is stable and label-sensitive")
    func seedStreams() {
        let s1 = SeedStream.derive(master: 7, "voice", "bedPluck1", "gen0")
        let s2 = SeedStream.derive(master: 7, "voice", "bedPluck1", "gen0")
        let s3 = SeedStream.derive(master: 7, "voice", "bedPluck2", "gen0")
        let s4 = SeedStream.derive(master: 8, "voice", "bedPluck1", "gen0")
        #expect(s1 == s2)
        #expect(s1 != s3)
        #expect(s1 != s4)
    }
}
