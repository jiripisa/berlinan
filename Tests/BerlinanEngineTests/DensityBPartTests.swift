import Testing
import Foundation
@testable import BerlinanEngine

/// Phase 27: density macro (FR-A-3), ambient legitimization (FR-A-4),
/// B-part bundle (FR-A-5).

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

private func soloProject() -> Project {
    var p = Project.demo
    p.voices = [p.voices[0]]           // bedPluck1, 1-bar loop
    p.transposition = .pedal
    return p
}

// MARK: - Density cap op (FR-A-3)

@Suite("Density — pattern cap")
struct DensityCapTests {

    private func makePattern() -> Pattern {
        var p = Pattern(id: "t", length: bar, notes: [])
        func note(_ sixteenth: Int, degree: Int, accent: Bool) -> PatternNote {
            PatternNote(position: Tick(sixteenth) * (beat / 4),
                        pitch: DegreePitch(degree: degree, octave: 0),
                        gate: 60, accent: accent)
        }
        p.notes = [note(0, degree: 0, accent: false),
                   note(3, degree: 2, accent: true),
                   note(4, degree: 4, accent: false),
                   note(7, degree: 1, accent: false),
                   note(10, degree: 3, accent: true),
                   note(14, degree: 5, accent: false)]
        return p
    }

    @Test("Density 1 is the identity")
    func identity() {
        let p = makePattern()
        #expect(PatternOps.densityCap(p, density: 1.0, meter: .fourFour) == p)
    }

    @Test("Cap keeps ceil(count·d) notes; accents survive first")
    func capAndAccents() {
        let p = makePattern()                       // 6 notes, 2 accents
        let capped = PatternOps.densityCap(p, density: 0.4, meter: .fourFour)
        #expect(capped.notes.count == 3)            // ceil(6·0.4)
        let keptAccents = capped.notes.filter(\.accent).count
        #expect(keptAccents == 2, "both accents must survive a cap of 3")
        // Positions stay sorted (a playable pattern).
        #expect(capped.notes.map(\.position) == capped.notes.map(\.position).sorted())
    }

    @Test("Beat-aligned notes outrank off-beat ones at equal accent")
    func beatPreference() {
        let p = makePattern()
        let capped = PatternOps.densityCap(p, density: 0.5, meter: .fourFour)
        // cap = 3: two accents + one more — the downbeat (position 0) wins
        // over off-beat non-accents.
        #expect(capped.notes.contains { $0.position == 0 })
    }

    @Test("Density 0 silences the pattern")
    func zero() {
        #expect(PatternOps.densityCap(makePattern(), density: 0,
                                      meter: .fourFour).notes.isEmpty)
    }
}

// MARK: - Density in the live engine (FR-A-3)

@Suite("Density — live engine")
struct DensityLiveTests {

    @Test("Project density caps every rendered loop")
    func projectDensity() {
        var base = soloProject()
        var engine0 = LiveEngine(project: base)
        let baseline = engine0.render(range: 0..<(4 * bar))
        base.density = 0.4
        var engine1 = LiveEngine(project: base)
        let capped = engine1.render(range: 0..<(4 * bar))
        for b in 0..<4 {
            let full = baseline.filter { $0.at / bar == Tick(b) }.count
            let thin = capped.filter { $0.at / bar == Tick(b) }.count
            #expect(thin <= Int((Double(full) * 0.4).rounded(.up)),
                    "bar \(b): \(thin) notes exceeds cap of \(full)·0.4")
            #expect(thin > 0)
        }
    }

    @Test("setDensity binds at the next bar")
    func setDensityBinding() {
        var engine = LiveEngine(project: soloProject())
        var reference = LiveEngine(project: soloProject())
        let baseline = reference.render(range: 0..<(2 * bar))
        engine.enqueue(.setDensity(0.4), atTick: beat)      // mid-bar 0
        let notes = engine.render(range: 0..<(2 * bar))
        let bar0Base = baseline.filter { $0.at < bar }.count
        let bar0 = notes.filter { $0.at < bar }.count
        let bar1Base = baseline.filter { $0.at >= bar }.count
        let bar1 = notes.filter { $0.at >= bar }.count
        #expect(bar0 == bar0Base, "bar 0 must still play in full")
        #expect(bar1 <= Int((Double(bar1Base) * 0.4).rounded(.up)))
    }

    @Test("Density render is chunk-independent")
    func chunkSafe() {
        func run(window: Tick) -> [String] {
            var p = soloProject()
            p.density = 0.5
            var engine = LiveEngine(project: p)
            var notes: [RenderedNote] = []
            var t: Tick = 0
            while t < 8 * bar {
                let end = min(t + window, 8 * bar)
                notes += engine.render(range: t..<end)
                t = end
            }
            return notes.map { "\($0.at)/\($0.midiNote)" }
        }
        #expect(run(window: 8 * bar) == run(window: 555))
    }
}

// MARK: - Ambient legitimization (FR-A-4)

@Suite("Ambient — legitimization scaling")
struct AmbientLegitTests {

    @Test("Ambient mode: patterns stay verbatim for 16 plays")
    func scaledRepeats() {
        // Find a seed whose plain render mutates by bar 8...
        var mutatingSeed: UInt64? = nil
        for candidate in UInt64(1)...12 {
            var p = soloProject()
            p.masterSeed = candidate
            var probe = LiveEngine(project: p)
            let notes = probe.render(range: 0..<(8 * bar))
            func sig(_ b: Int) -> [String] {
                notes.filter { $0.at / bar == Tick(b) }
                    .map { "\($0.at % bar)/\($0.midiNote)/\($0.velocity)" }
            }
            if sig(4) != sig(0) || sig(5) != sig(0) { mutatingSeed = candidate; break }
        }
        let seed = try! #require(mutatingSeed)

        // ...then confirm ambient stretches its verbatim life to 16 bars.
        var p = soloProject()
        p.masterSeed = seed
        p.arrangement = ArrangementConfig(enabled: true, ambientMode: true)
        var engine = LiveEngine(project: p)
        let notes = engine.render(range: 0..<(16 * bar))
        func sig(_ b: Int) -> [String] {
            notes.filter { $0.at / bar == Tick(b) }
                .map { "\($0.at % bar)/\($0.midiNote)/\($0.velocity)" }
        }
        for b in 1..<16 {
            #expect(sig(b) == sig(0), "ambient bar \(b) must still be verbatim")
        }
    }
}

// MARK: - B-part bundle (FR-A-5)

@Suite("B-part bundle")
struct BPartTests {

    private func bedAndBass() -> Project {
        var p = Project.demo                       // bedPluck1/2 + bass
        p.transposition = .pedal
        return p
    }

    @Test("Default fire: progression walk lands in the schedule from the fire bar")
    func progressionInjection() {
        var engine = LiveEngine(project: bedAndBass())
        engine.enqueue(.fireBPart, atTick: beat)   // binds at bar 1
        _ = engine.render(range: 0..<(2 * bar))
        #expect(engine.transpositionOffset(atBar: 0) == 0)
        #expect(engine.transpositionOffset(atBar: 1) == 5)    // VI
        #expect(engine.transpositionOffset(atBar: 5) == 3)    // iv
        #expect(engine.transpositionOffset(atBar: 9) == 0)    // home
        #expect(engine.transpositionOffset(atBar: 14) == 0)
    }

    @Test("Fire regenerates the bass at its next loop boundary")
    func bassSwap() {
        var engine = LiveEngine(project: bedAndBass())
        let before = engine.voiceState(id: "bass")!.pattern.provenance.seed
        engine.enqueue(.fireBPart, atTick: 0)
        _ = engine.render(range: 0..<(2 * bar))
        let after = engine.voiceState(id: "bass")!.pattern.provenance.seed
        #expect(after != before)
    }

    @Test("dropBed deactivates the second bed; setVoiceActive brings it back")
    func dropBedAndRecover() {
        var p = bedAndBass()
        p.bPart = BPartConfig(dropBed: true)
        var engine = LiveEngine(project: p)
        engine.enqueue(.fireBPart, atTick: 0)
        let during = engine.render(range: 0..<(4 * bar))
        #expect(!during.contains { $0.voiceID == "bedPluck2" && $0.at >= bar },
                "bed 2 must be silent after the drop")
        engine.enqueue(.setVoiceActive(voiceID: "bedPluck2", on: true),
                       atTick: 4 * bar)
        let after = engine.render(range: (4 * bar)..<(6 * bar))
        #expect(after.contains { $0.voiceID == "bedPluck2" },
                "manual reactivation must bring the bed back")
    }
}
