import Testing
import Foundation
@testable import BerlinanEngine

/// Phase 33: drone intro (arranger opens on a drone) and slides (tie steps
/// → legato overlap → portamento glide on a mono synth).

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

@Suite("Drone generator")
struct DroneTests {

    @Test("Root + fifth sustained for the whole loop, quiet")
    func shape() {
        let pattern = PatternFactory.make(id: "drone", config: .drone(bars: 4),
                                          role: .drone, key: .default,
                                          meter: .fourFour, seed: 1)
        #expect(pattern.length == 4 * bar)
        #expect(pattern.notes.count == 2)
        #expect(Set(pattern.notes.map(\.pitch.degree)) == [0, 4])
        #expect(pattern.notes.allSatisfy { $0.position == 0 })
        #expect(pattern.notes.allSatisfy { $0.gate == 4 * bar })
        #expect(pattern.notes.allSatisfy { !$0.accent })
    }

    @Test("A drone voice opens the derived build order; demo stays unchanged")
    func buildOrder() {
        var p = Project.demo
        p.voices.append(VoiceConfig(id: "drone", role: .drone,
                                    register: RegisterWindow(low: 36, high: 60),
                                    referenceC: 48,
                                    generator: .drone(bars: 4), channel: 5))
        #expect(ArrangementSM.deriveBuildOrder(from: p.voices).first == "drone")
        #expect(ArrangementSM.deriveBuildOrder(from: Project.demo.voices)
                == ["bedPluck1", "bedPluck2", "bass"])
    }
}

@Suite("Ties — slides")
struct TieTests {

    private func tiedPattern() -> Pattern {
        var pattern = Pattern(
            id: "t", length: bar,
            notes: [PatternNote(position: 0,
                                pitch: DegreePitch(degree: 0), gate: 60),
                    PatternNote(position: beat,
                                pitch: DegreePitch(degree: 2), gate: 60),
                    PatternNote(position: 3 * beat,
                                pitch: DegreePitch(degree: 4), gate: 60)],
            provenance: Provenance(generator: .seedProcedure, version: 1, seed: 3))
        pattern.notes[0].tie = true          // 0 → beat
        pattern.notes[2].tie = true          // 3·beat → wraps to 0
        return pattern
    }

    @Test("A tied gate reaches the next onset plus overlap; wrap included")
    func applyTies() {
        let tied = PatternOps.applyTies(tiedPattern(), overlap: 30)
        #expect(tied.notes[0].gate == beat + 30)
        #expect(tied.notes[1].gate == 60, "untied notes keep their gate")
        #expect(tied.notes[2].gate == bar - 3 * beat + 0 + 30,
                "the last tie wraps to the loop's first onset")
    }

    @Test("Rendered tied notes overlap the following onset")
    func renderedOverlap() {
        var p = Project.demo
        p.transposition = .pedal
        p.voices = [p.voices[0]]
        p.voices[0].overridePattern = tiedPattern()
        var engine = LiveEngine(project: p)
        let notes = engine.render(range: 0..<bar).sorted { $0.at < $1.at }
        #expect(notes.count == 3)
        #expect(notes[0].at + notes[0].gate > notes[1].at,
                "legato overlap is the slide")
    }

    @Test("Slides mutation: enabled projects grow ties on the bass; disabled never")
    func slideMutation() {
        func tiesAppear(slides: Bool) -> Bool {
            for seed in UInt64(1)...30 {
                var p = Project.demo
                p.transposition = .pedal
                p.voices = [p.voices[2]]           // bass
                p.masterSeed = seed
                p.slidesEnabled = slides
                var engine = LiveEngine(project: p)
                _ = engine.render(range: 0..<(24 * bar))
                if engine.voiceState(id: "bass")!.pattern.notes
                    .contains(where: { $0.tie == true }) {
                    return true
                }
            }
            return false
        }
        #expect(tiesAppear(slides: true), "30 seeds × 24 bars must slide once")
        #expect(!tiesAppear(slides: false), "off = byte-compatible old world")
    }
}
