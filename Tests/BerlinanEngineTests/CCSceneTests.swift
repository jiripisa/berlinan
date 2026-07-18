import Testing
import Foundation
@testable import BerlinanEngine

/// Phase 34: CC scenes — named per-voice CC targets morphed over bars.

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

private func sceneProject() -> Project {
    var p = Project.demo
    p.transposition = .pedal
    p.voices = [p.voices[0]]                  // bedPluck1 with filter=74
    p.ccScenes = [
        CCScene(name: "closed", values: ["bedPluck1": ["filter": 0.2]]),
        CCScene(name: "open",   values: ["bedPluck1": ["filter": 0.9]]),
    ]
    return p
}

@Suite("CC scenes — morphing")
struct CCSceneTests {

    private func sceneCC(_ engine: inout LiveEngine, upTo total: Tick,
                         window: Tick) -> [RenderedCC] {
        var events: [RenderedCC] = []
        var t: Tick = 0
        while t < total {
            let end = min(t + window, total)
            _ = engine.render(range: t..<end)
            events += engine.renderCC(range: t..<end)
            t = end
        }
        // The demo bed also has an LFO lane on CC 74 with a 16-bar sine —
        // strip it by comparing against a scene-less reference.
        return events
    }

    @Test("Morph ramps to the target over the bars, then goes silent")
    func morphRamp() {
        var project = sceneProject()
        project.voices[0].ccLanes = nil        // isolate the scene stream
        var engine = LiveEngine(project: project)
        engine.enqueue(.morphToScene(name: "open", bars: 4), atTick: beat)
        _ = engine.render(range: 0..<(10 * bar))
        let events = engine.renderCC(range: 0..<(10 * bar))
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { $0.controller == 74 })
        let values = events.sorted { $0.at < $1.at }.map(\.value)
        #expect(values == values.sorted(), "the morph must rise monotonically")
        #expect(values.last.map { abs(Int($0) - Int(0.9 * 127)) <= 1 } == true,
                "must land on the scene value")
        // Silent after settling: nothing beyond the morph's end bar.
        #expect(events.allSatisfy { $0.at <= 5 * bar + bar },
                "no emissions after the morph settles")
    }

    @Test("Emission respects the 1/96 quantum")
    func quantum() {
        var project = sceneProject()
        project.voices[0].ccLanes = nil
        var engine = LiveEngine(project: project)
        engine.enqueue(.morphToScene(name: "open", bars: 2), atTick: 0)
        _ = engine.render(range: 0..<(4 * bar))
        let events = engine.renderCC(range: 0..<(4 * bar))
        let quantum = Time.ppqn * 4 / 96
        #expect(events.allSatisfy { $0.at % quantum == 0 })
        let ticks = events.map(\.at)
        #expect(Set(ticks).count == ticks.count, "one emission per grid point")
    }

    @Test("Chunk-independent emission")
    func chunkSafe() {
        func run(window: Tick) -> [String] {
            var project = sceneProject()
            project.voices[0].ccLanes = nil
            var engine = LiveEngine(project: project)
            engine.enqueue(.morphToScene(name: "open", bars: 3), atTick: 0)
            var events: [RenderedCC] = []
            var t: Tick = 0
            while t < 6 * bar {
                let end = min(t + window, 6 * bar)
                _ = engine.render(range: t..<end)
                events += engine.renderCC(range: t..<end)
                t = end
            }
            return events.map { "\($0.at)/\($0.controller)/\($0.value)" }
        }
        #expect(run(window: 6 * bar) == run(window: 555))
    }

    @Test("A re-morph mid-flight starts from the interrupted value")
    func interrupt() {
        var project = sceneProject()
        project.voices[0].ccLanes = nil
        var engine = LiveEngine(project: project)
        engine.enqueue(.morphToScene(name: "open", bars: 8), atTick: 0)
        _ = engine.render(range: 0..<(4 * bar))          // halfway up
        engine.enqueue(.morphToScene(name: "closed", bars: 4), atTick: 4 * bar)
        _ = engine.render(range: (4 * bar)..<(12 * bar))
        let events = engine.renderCC(range: (4 * bar)..<(12 * bar))
            .sorted { $0.at < $1.at }
        let first = try! #require(events.first)
        // 0.5 → interrupted around halfway between 0.5·127 and 0.9·127.
        #expect(first.value > UInt8(0.3 * 127) && first.value < UInt8(0.9 * 127),
                "the second morph starts near the interrupted value, got \(first.value)")
        let values = events.map(\.value)
        #expect(values == values.sorted(by: >), "and falls toward 'closed'")
        #expect(abs(Int(values.last!) - Int(0.2 * 127)) <= 1)
    }

    @Test("An arranger phase transition fires its mapped scene")
    func arrangerHook() {
        var project = sceneProject()
        project.voices[0].ccLanes = nil
        project.arrangement = ArrangementConfig(enabled: true)
        project.sceneByPhase = ["bed": "open"]
        var engine = LiveEngine(project: project)
        for k in 0..<6 {                       // fast-forward into bed
            engine.enqueue(.advancePhase, atTick: Tick(k) * bar)
        }
        _ = engine.render(range: 0..<(12 * bar))
        let events = engine.renderCC(range: 0..<(12 * bar))
        #expect(!events.isEmpty, "entering BED must start the mapped morph")
        #expect(events.allSatisfy { $0.controller == 74 })
    }
}
