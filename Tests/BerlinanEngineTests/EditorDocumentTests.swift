import Foundation
import Testing
@testable import BerlinanEngine

private let key = Key.default
private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

private func soloProject() -> Project {
    var p = Project.demo
    p.transposition = .pedal
    p.voices = [p.voices[0]]
    p.voices[0].ccLanes = nil
    return p
}

/// A distinctive hand-made pattern: three root octaves on beats 1–3.
private func handPattern() -> Pattern {
    Pattern(id: "hand", length: bar,
            notes: [
                PatternNote(position: 0, pitch: DegreePitch(degree: 0),
                            velocity: 101, gate: 120),
                PatternNote(position: beat, pitch: DegreePitch(degree: 0, octave: 1),
                            velocity: 102, gate: 120),
                PatternNote(position: 2 * beat, pitch: DegreePitch(degree: 0),
                            velocity: 103, gate: 120),
            ],
            provenance: Provenance(generator: .handEdited, version: 1, seed: 0))
}

// MARK: - replacePattern action (FR-P-7 live path)

@Suite("Replace pattern action")
struct ReplacePatternTests {

    @Test("Binds at the next loop boundary; locked and established afterwards")
    func binding() {
        var engine = LiveEngine(project: soloProject())
        engine.enqueue(.replacePattern(voiceID: "bedPluck1", pattern: handPattern()),
                       atTick: beat)                     // mid-bar 0
        let notes = engine.render(range: 0..<(3 * bar))
        let bar0 = notes.filter { $0.at < bar }
        let bar1 = notes.filter { $0.at >= bar && $0.at < 2 * bar }
        // Bar 0 = generated pattern; bar 1 = the hand pattern exactly.
        #expect(bar1.count == 3)
        #expect(bar1.map(\.at) == [bar, bar + beat, bar + 2 * beat])
        #expect(bar1.map { Int($0.midiNote) } == [60, 72, 60])
        #expect(!bar0.isEmpty)
        let state = engine.voiceState(id: "bedPluck1")!
        #expect(state.pattern.locked)
        #expect(state.pattern.lifecycle == .established)
    }

    @Test("A replaced pattern never auto-mutates (locked forever)")
    func noMutation() {
        var engine = LiveEngine(project: soloProject())
        engine.enqueue(.replacePattern(voiceID: "bedPluck1", pattern: handPattern()),
                       atTick: 0)
        let notes = engine.render(range: 0..<(10 * bar))
        func signature(_ barIndex: Int) -> [String] {
            notes.filter { $0.at >= Tick(barIndex) * bar && $0.at < Tick(barIndex + 1) * bar }
                .map { "\($0.at % bar)/\($0.midiNote)" }
        }
        for barIndex in 2..<10 {
            #expect(signature(barIndex) == signature(1),
                    "bar \(barIndex) drifted despite the lock")
        }
    }

    @Test("Chunk-independent")
    func chunkIndependent() {
        func run(window: Tick) -> [String] {
            var engine = LiveEngine(project: soloProject())
            engine.enqueue(.replacePattern(voiceID: "bedPluck1", pattern: handPattern()),
                           atTick: bar + 7)
            var notes: [RenderedNote] = []
            var t: Tick = 0
            while t < 6 * bar {
                let end = min(t + window, 6 * bar)
                notes += engine.render(range: t..<end)
                t = end
            }
            return notes.map { "\($0.at)/\($0.midiNote)/\($0.velocity)" }
        }
        #expect(run(window: 6 * bar) == run(window: 501))
    }
}

// MARK: - Override pattern in the document (FR-P-7 persistence)

@Suite("Override pattern")
struct OverridePatternTests {

    @Test("Materialized verbatim, locked; renders reproduce the hand notes")
    func overrideUsed() {
        var project = soloProject()
        project.voices[0].overridePattern = handPattern()
        let engine = LiveEngine(project: project)
        let state = engine.voiceState(id: "bedPluck1")!
        #expect(state.pattern.locked)
        #expect(state.pattern.notes == handPattern().notes)

        let notes = OfflineRenderer.renderNotes(project: project, bars: 4)
        for barIndex in 0..<4 {
            let inBar = notes.filter {
                $0.at >= Tick(barIndex) * bar && $0.at < Tick(barIndex + 1) * bar
            }
            #expect(inBar.map { Int($0.midiNote) } == [60, 72, 60], "bar \(barIndex)")
        }
    }
}

// MARK: - Document format

@Suite("Document format (phase 19)")
struct DocumentFormatTests {

    @Test("snapshots + overridePattern survive a JSON round-trip")
    func roundTrip() throws {
        var project = soloProject()
        project.voices[0].overridePattern = handPattern()
        var engine = LiveEngine(project: project)
        _ = engine.render(range: 0..<bar)
        project.snapshots = [engine.captureState(), nil, nil, nil, nil, nil]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(project)
        let back = try JSONDecoder().decode(Project.self, from: data)
        #expect(back == project)
        #expect(back.snapshots?.count == 6)
        #expect(back.snapshots?[0] != nil)
        #expect(back.voices[0].overridePattern == handPattern())
    }

    @Test("0.2.x-style JSON without the new keys still decodes")
    func backCompat() throws {
        let data = try JSONEncoder().encode(Project.demo)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object.removeValue(forKey: "snapshots")
        var voices = object["voices"] as! [[String: Any]]
        for i in voices.indices { voices[i].removeValue(forKey: "overridePattern") }
        object["voices"] = voices
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Project.self, from: stripped)
        #expect(decoded.snapshots == nil)
        #expect(decoded.voices.allSatisfy { $0.overridePattern == nil })
    }
}
