import Testing
@testable import BerlinanEngine

private let bar: Tick = 4 * Time.ppqn

@Suite("LiveEngine snapshot")
struct SnapshotTests {

    @Test("Snapshot mirrors the materialized voices before any render")
    func initialSnapshot() {
        let engine = LiveEngine(project: .demo)
        let snap = engine.snapshot()
        #expect(snap.voices.map(\.id) == ["bedPluck1", "bedPluck2", "bass"])
        #expect(snap.voices.map(\.role) == [.bedPluck1, .bedPluck2, .bass])
        #expect(snap.voices.allSatisfy { !$0.blankActive })
        // The phased bed voice must show its 15-step loop.
        #expect(snap.voices[1].pattern.length == 15 * (Time.ppqn / 4))
        #expect(snap.voices.allSatisfy { $0.pattern.lifecycle == .repeating(remaining: 4) })
    }

    @Test("Snapshot reflects lifecycle countdown and mutations after renders")
    func evolvesWithRenders() {
        var project = Project.demo
        project.voices = [project.voices[0]]          // 1-bar loop
        project.transposition = .pedal
        var engine = LiveEngine(project: project)
        let before = engine.snapshot().voices[0].pattern

        _ = engine.render(range: 0..<bar)             // one full loop
        let afterOne = engine.snapshot().voices[0].pattern
        #expect(afterOne.lifecycle == .repeating(remaining: 3))
        #expect(afterOne.notes == before.notes, "still verbatim (Law 1)")

        _ = engine.render(range: bar..<(8 * bar))     // past establishment + mutation window
        let later = engine.snapshot().voices[0].pattern
        // After 4 plays the pattern established and auto-mutation ran —
        // lifecycle must be back in a repeating cycle.
        if case .repeating = later.lifecycle {} else {
            Issue.record("expected a repeating lifecycle after auto-mutation")
        }
    }

    @Test("Blank cycle is visible in the snapshot")
    func blankVisible() {
        var project = Project.demo
        project.voices = [project.voices[0]]
        var engine = LiveEngine(project: project)
        engine.enqueue(.blankCycle(voiceID: "bedPluck1"), atTick: bar)
        _ = engine.render(range: 0..<(bar + 1))       // boundary processed at bar
        #expect(engine.snapshot().voices[0].blankActive)
    }

    @Test("transpositionOffset(atBar:) exposes the (live) schedule")
    func offsetLookup() {
        var engine = LiveEngine(project: .demo)       // event at bar 8: +5
        #expect(engine.transpositionOffset(atBar: 0) == 0)
        #expect(engine.transpositionOffset(atBar: 8) == 5)
        engine.enqueue(.transpose(degreeOffset: 2), atTick: 0)
        #expect(engine.transpositionOffset(atBar: 0) == 2)
    }
}
