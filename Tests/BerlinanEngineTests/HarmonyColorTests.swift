import Testing
import Foundation
@testable import BerlinanEngine

/// Phase 30: tension budget (FR-H-7), stochastic chord layer (FR-H-8),
/// heartbeat kick (FR-V-7).

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

// MARK: - Tension budget (FR-H-7)

@Suite("Tension budget")
struct TensionBudgetTests {

    private func soloProject() -> Project {
        var p = Project.demo
        p.voices = [p.voices[0]]
        p.transposition = .pedal
        return p
    }

    /// C minor pitch classes from C: {0, 2, 3, 5, 7, 8, 10}.
    private func inScale(_ midi: Int) -> Bool {
        [0, 2, 3, 5, 7, 8, 10].contains(((midi - 60) % 12 + 12) % 12)
    }

    @Test("Spending inserts ONE sustained out-of-key note at the next bar")
    func spend() {
        var engine = LiveEngine(project: soloProject())
        var reference = LiveEngine(project: soloProject())
        engine.enqueue(.spendTension(voiceID: "bedPluck1"), atTick: beat)
        let notes = engine.render(range: 0..<(3 * bar))
        let baseline = reference.render(range: 0..<(3 * bar))
        let extras = notes.filter { note in
            !baseline.contains { $0.at == note.at && $0.midiNote == note.midiNote
                                 && $0.gate == note.gate }
        }
        #expect(extras.count == 1, "exactly one tension note")
        let tension = try! #require(extras.first)
        #expect(tension.at == bar, "binds at the next bar")
        #expect(!inScale(tension.midiNote), "must be out of key")
        #expect(tension.gate >= bar, "sustained — a whole bar at least")
    }

    @Test("The budget is finite: default 2 spends, then silence")
    func budgetExhausts() {
        var engine = LiveEngine(project: soloProject())
        var reference = LiveEngine(project: soloProject())
        engine.enqueue(.spendTension(voiceID: "bedPluck1"), atTick: 0)
        _ = engine.render(range: 0..<(2 * bar))
        engine.enqueue(.spendTension(voiceID: "bedPluck1"), atTick: 2 * bar)
        _ = engine.render(range: (2 * bar)..<(4 * bar))
        engine.enqueue(.spendTension(voiceID: "bedPluck1"), atTick: 4 * bar)
        let tail = engine.render(range: (4 * bar)..<(6 * bar))
        let baselineTail = reference.render(range: 0..<(6 * bar))
            .filter { $0.at >= 4 * bar }
        #expect(tail.count == baselineTail.count,
                "an exhausted budget must add nothing")
        #expect(engine.snapshot().tensionRemaining == 0)
    }

    @Test("Snapshot mirrors the remaining budget")
    func mirror() {
        var engine = LiveEngine(project: soloProject())
        #expect(engine.snapshot().tensionRemaining == 2)
        engine.enqueue(.spendTension(voiceID: "bedPluck1"), atTick: 0)
        _ = engine.render(range: 0..<(2 * bar))
        #expect(engine.snapshot().tensionRemaining == 1)
    }
}

// MARK: - Chord layer (FR-H-8)

@Suite("Chord layer generator")
struct ChordLayerTests {

    private func make(seed: UInt64) -> Pattern {
        PatternFactory.make(id: "pad", config: .chordLayer(periodBars: 7),
                            role: .pad, key: .default, meter: .fourFour,
                            seed: seed)
    }

    @Test("One sustained in-scale chord fills the whole 7-bar loop")
    func shape() {
        let pattern = make(seed: 5)
        #expect(pattern.length == 7 * bar)
        #expect(pattern.notes.count >= 3, "a chord — three tones at least")
        #expect(pattern.notes.allSatisfy { $0.position == 0 })
        #expect(pattern.notes.allSatisfy { $0.gate == 7 * bar })
        #expect(pattern.notes.allSatisfy { $0.pitch.accidental == 0 },
                "chord tones quantize into the key — no bypass here")
        let degrees = Set(pattern.notes.map(\.pitch.degree))
        #expect(degrees.count >= 3, "stacked tones must be distinct degrees")
    }

    @Test("Deterministic per seed; seeds vary the chord")
    func seeds() {
        #expect(make(seed: 5).notes == make(seed: 5).notes)
        let chords = Set((1...12).map { seed in
            make(seed: UInt64(seed)).notes.map(\.pitch.degree).sorted()
                .map(String.init).joined(separator: ",")
        })
        #expect(chords.count > 1, "twelve seeds must not all give one chord")
    }
}

// MARK: - Heartbeat (FR-V-7)

@Suite("Heartbeat generator")
struct HeartbeatTests {

    @Test("The root on every beat, quiet, unaccented")
    func shape() {
        let pattern = PatternFactory.make(id: "kick", config: .heartbeat,
                                          role: .rhythm, key: .default,
                                          meter: .fourFour, seed: 1)
        #expect(pattern.length == bar)
        #expect(pattern.notes.count == 4)
        #expect(pattern.notes.map(\.position) == [0, beat, 2 * beat, 3 * beat])
        #expect(pattern.notes.allSatisfy { $0.pitch.degree == 0 })
        #expect(pattern.notes.allSatisfy { !$0.accent })
    }
}
