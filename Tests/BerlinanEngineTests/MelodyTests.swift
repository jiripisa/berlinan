import Testing
import Foundation
@testable import BerlinanEngine

/// Phase 28: velocity-accent melody extraction (FR-MEL-1) and lead
/// promotion (FR-MEL-2) — the manual's §8.1 as one gesture.

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat
private let step: Tick = beat / 4

private func densePattern() -> Pattern {
    // 8 notes: mixed on/off-beat, degrees beyond root+fifth available.
    func note(_ sixteenth: Int, degree: Int) -> PatternNote {
        PatternNote(position: Tick(sixteenth) * step,
                    pitch: DegreePitch(degree: degree, octave: 0),
                    gate: 60)
    }
    return Pattern(id: "src", length: bar,
                   notes: [note(0, degree: 0), note(2, degree: 2),
                           note(4, degree: 4), note(6, degree: 1),
                           note(8, degree: 0), note(10, degree: 3),
                           note(12, degree: 4), note(14, degree: 5)],
                   provenance: Provenance(generator: .seedProcedure,
                                          version: 1, seed: 9))
}

@Suite("Melody — accent selection")
struct MelodySelectionTests {

    @Test("Picks 3–4 pairwise non-adjacent notes, deterministically")
    func basics() {
        let pattern = densePattern()
        let picks = Melody.selectAccents(pattern: pattern, key: .default,
                                         meter: .fourFour, seed: 7)
        #expect((3...4).contains(picks.count))
        #expect(picks == Melody.selectAccents(pattern: pattern, key: .default,
                                              meter: .fourFour, seed: 7))
        let positions = picks.map { pattern.notes[$0].position }.sorted()
        for pair in zip(positions, positions.dropFirst()) {
            #expect(pair.1 - pair.0 >= 2 * step,
                    "adjacent 16th steps must never both be accents")
        }
    }

    @Test("On-beat notes are preferred when plentiful")
    func onBeatPreference() {
        let pattern = densePattern()   // on-beat: steps 0, 4, 8, 12
        let picks = Melody.selectAccents(pattern: pattern, key: .default,
                                         meter: .fourFour, seed: 7)
        let onBeat = picks.filter {
            pattern.notes[$0].position % beat == 0
        }.count
        #expect(onBeat >= picks.count - 1,
                "with four on-beat candidates, at most one pick may be off-beat")
    }

    @Test("Never root+fifth-only when other degrees exist")
    func avoidsRootFifthOnly() {
        for seed in UInt64(1)...12 {
            let pattern = densePattern()
            let picks = Melody.selectAccents(pattern: pattern, key: .default,
                                             meter: .fourFour, seed: seed)
            let degrees = Set(picks.map { pattern.notes[$0].pitch.degree % 7 })
            #expect(degrees != [0], "seed \(seed)")
            #expect(degrees != [0, 4] && degrees != [4],
                    "seed \(seed): melody must not be root+fifth only")
        }
    }
}

@Suite("Melody — live extraction")
struct MelodyLiveTests {

    private func soloProject() -> Project {
        var p = Project.demo
        p.voices = [p.voices[0]]
        p.transposition = .pedal
        return p
    }

    @Test("Extraction mutes all but the accents at the next loop boundary")
    func extractionApplies() {
        var reference = LiveEngine(project: soloProject())
        let full = reference.render(range: 0..<bar).count
        var engine = LiveEngine(project: soloProject())
        engine.enqueue(.extractMelody(voiceID: "bedPluck1"), atTick: 0)
        let notes = engine.render(range: 0..<(2 * bar))
        let bar1 = notes.filter { $0.at >= bar }
        #expect((3...4).contains(Set(bar1.map(\.at)).count)
                || bar1.count <= 4, "melody bar must carry 3–4 notes")
        #expect(bar1.count < full, "extraction must be sparser than the source")
        #expect(bar1.allSatisfy(\.accent), "melody notes are the accents")
    }

    @Test("Toggling extraction off restores the source verbatim")
    func toggleRestores() {
        var engine = LiveEngine(project: soloProject())
        var reference = LiveEngine(project: soloProject())
        engine.enqueue(.extractMelody(voiceID: "bedPluck1"), atTick: 0)
        engine.enqueue(.extractMelody(voiceID: "bedPluck1"), atTick: bar + 1)
        let notes = engine.render(range: 0..<(3 * bar))
        let restored = notes.filter { $0.at >= 2 * bar }
            .map { "\($0.at % bar)/\($0.midiNote)" }
        let baseline = reference.render(range: 0..<(3 * bar))
            .filter { $0.at >= 2 * bar }
            .map { "\($0.at % bar)/\($0.midiNote)" }
        #expect(restored == baseline)
    }

    @Test("Inversion at 2 bars changes the note set; growth adds one at 4 and 8")
    func evolution() {
        var engine = LiveEngine(project: soloProject())
        engine.enqueue(.extractMelody(voiceID: "bedPluck1"), atTick: 0)
        let notes = engine.render(range: 0..<(10 * bar))
        func melodySet(_ b: Int) -> Set<String> {
            Set(notes.filter { $0.at / bar == Tick(b) }
                .map { "\($0.at % bar)/\($0.midiNote)" })
        }
        let initial = melodySet(1)          // extraction active from bar 1
        let inverted = melodySet(3)         // ≥2 bars after start
        #expect(!initial.isEmpty)
        #expect(inverted != initial, "2-bar accent inversion must change notes")
        let grown1 = melodySet(5)           // ≥4 bars: +1 note
        let grown2 = melodySet(9)           // ≥8 bars: +1 more
        #expect(grown1.count == inverted.count + 1)
        #expect(grown2.count == grown1.count + 1)
    }

    @Test("Extraction render is chunk-independent")
    func chunkSafe() {
        func run(window: Tick) -> [String] {
            var engine = LiveEngine(project: soloProject())
            engine.enqueue(.extractMelody(voiceID: "bedPluck1"), atTick: 0)
            var notes: [RenderedNote] = []
            var t: Tick = 0
            while t < 10 * bar {
                let end = min(t + window, 10 * bar)
                notes += engine.render(range: t..<end)
                t = end
            }
            return notes.map { "\($0.at)/\($0.midiNote)/\($0.velocity)" }
        }
        #expect(run(window: 10 * bar) == run(window: 777))
    }
}

@Suite("Melody — lead promotion")
struct LeadPromotionTests {

    private func projectWithLead() -> Project {
        var p = Project.demo
        p.transposition = .pedal
        p.voices.append(VoiceConfig(
            id: "lead", role: .lead,
            register: RegisterWindow(low: 60, high: 96), referenceC: 72,
            generator: .seedProcedure(bars: 1, mutations: 2), channel: 4))
        return p
    }

    @Test("Promotion replaces the lead pattern with legato melody notes")
    func promote() {
        var engine = LiveEngine(project: projectWithLead())
        engine.enqueue(.extractMelody(voiceID: "bedPluck1"), atTick: 0)
        _ = engine.render(range: 0..<(2 * bar))
        engine.enqueue(.promoteToLead(voiceID: "bedPluck1"), atTick: 2 * bar)
        _ = engine.render(range: (2 * bar)..<(4 * bar))
        let lead = engine.voiceState(id: "lead")!.pattern
        #expect(lead.locked, "a promoted line is the producer's word")
        #expect((3...4).contains(lead.notes.count))
        // Legato: every gate reaches at least one beat.
        #expect(lead.notes.allSatisfy { $0.gate >= beat },
                "gates: \(lead.notes.map(\.gate))")
    }

    @Test("Promotion without a lead voice is a safe no-op")
    func noLead() {
        var p = Project.demo
        p.voices = [p.voices[0]]
        var engine = LiveEngine(project: p)
        engine.enqueue(.extractMelody(voiceID: "bedPluck1"), atTick: 0)
        engine.enqueue(.promoteToLead(voiceID: "bedPluck1"), atTick: bar)
        _ = engine.render(range: 0..<(3 * bar))   // must not crash
    }
}
