import Testing
@testable import BerlinanEngine

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

private func soloProject() -> Project {
    var p = Project.demo
    p.transposition = .pedal
    p.voices = [p.voices[0]]
    p.voices[0].ccLanes = nil
    return p
}

private let aMinor = Key(root: 9, scale: .preset(.naturalMinor))

// MARK: - Runtime key change (FR-GS-5)

@Suite("Runtime key change")
struct RuntimeKeyTests {

    @Test("Binds at the next bar: C-rooted before, A-rooted after")
    func binding() {
        var engine = LiveEngine(project: soloProject())
        engine.enqueue(.setKey(aMinor), atTick: beat)          // mid-bar 0
        let notes = engine.render(range: 0..<(2 * bar))

        let cClasses = Set(Scale.preset(.naturalMinor).offsets.map { $0 % 12 })
        let before = notes.filter { $0.at < bar }
        let after = notes.filter { $0.at >= bar }
        #expect(!before.isEmpty && !after.isEmpty)
        // Before: C minor pitch classes (root 0); after: A minor (root 9).
        #expect(before.allSatisfy { cClasses.contains(Int($0.midiNote) % 12) })
        let aClasses = Set(Scale.preset(.naturalMinor).offsets.map { ($0 + 9) % 12 })
        #expect(after.allSatisfy { aClasses.contains(Int($0.midiNote) % 12) })
        // The same degrees re-rooted: first onset of bar 1 is an A-class root.
        let firstAfter = after.min { $0.at < $1.at }!
        #expect(Int(firstAfter.midiNote) % 12 == 9)
    }

    @Test("Mutations and regenerations after the change stay in the new key")
    func staysInNewKey() {
        var engine = LiveEngine(project: soloProject())
        engine.enqueue(.setKey(aMinor), atTick: 0)
        engine.enqueue(.regenerate(voiceID: "bedPluck1"), atTick: 2 * bar)
        let notes = engine.render(range: 0..<(16 * bar))       // incl. auto-mutations
        let aClasses = Set(Scale.preset(.naturalMinor).offsets.map { ($0 + 9) % 12 })
        #expect(notes.filter { $0.at >= bar }
            .allSatisfy { aClasses.contains(Int($0.midiNote) % 12) })
    }

    @Test("Chunk-independent")
    func chunkIndependent() {
        func run(window: Tick) -> [String] {
            var engine = LiveEngine(project: soloProject())
            engine.enqueue(.setKey(aMinor), atTick: bar + 3)
            engine.enqueue(.regenerate(voiceID: "bedPluck1"), atTick: 3 * bar)
            var notes: [RenderedNote] = []
            var t: Tick = 0
            while t < 8 * bar {
                let end = min(t + window, 8 * bar)
                notes += engine.render(range: t..<end)
                t = end
            }
            return notes.map { "\($0.at)/\($0.midiNote)/\($0.velocity)" }
        }
        #expect(run(window: 8 * bar) == run(window: 733))
    }

    @Test("Snapshot carries the effective key; recall + key interleave by tick")
    func snapshotAndInterleave() {
        var engine = LiveEngine(project: soloProject())
        #expect(engine.snapshot().key == Key.default)

        _ = engine.render(range: 0..<bar)
        let capturedCMinor = engine.captureState()

        engine.enqueue(.setKey(aMinor), atTick: bar)           // binds bar 1
        engine.enqueue(.recallSnapshot(capturedCMinor), atTick: 2 * bar)  // binds bar 2
        _ = engine.render(range: bar..<(2 * bar))
        #expect(engine.snapshot().key == aMinor)

        _ = engine.render(range: (2 * bar)..<(3 * bar))
        // Recall restores patterns/schedule but NOT the key (key is a global
        // performance setting, not part of the material snapshot).
        #expect(engine.snapshot().key == aMinor)
    }
}
