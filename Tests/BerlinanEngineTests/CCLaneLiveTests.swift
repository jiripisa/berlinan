import Testing
@testable import BerlinanEngine

/// Phase 61: CC lanes edited while playing take over at the render head.

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

private func flatLane(controller: UInt8, center: Double = 0.5) -> CCLane {
    CCLane(target: "", shape: .sine, cycleBars: 16, depth: 0, center: center,
           controller: controller)
}

private func renderWindow(_ engine: inout LiveEngine,
                          _ range: Range<Tick>) -> [RenderedCC] {
    _ = engine.render(range: range)
    return engine.renderCC(range: range).filter { $0.voiceID == "bedPluck1" }
}

@Suite("CC lanes — live edits")
struct CCLaneLiveTests {

    @Test("A lane swap takes effect at the render head and emits at once")
    func swapTakesEffectAtRenderHead() {
        var engine = LiveEngine(project: .demo)
        _ = renderWindow(&engine, 0..<bar)
        engine.enqueue(.setCCLanes(voiceID: "bedPluck1",
                                   lanes: [flatLane(controller: 30)]), atTick: bar)
        let after = renderWindow(&engine, bar..<(2 * bar))
        #expect(after.contains { $0.controller == 30 && $0.at == bar && $0.value == 64 })
        #expect(!after.contains { $0.controller == 74 })
    }

    @Test("Removing every lane silences the voice's CC")
    func emptyLanesSilenceTheVoice() {
        var engine = LiveEngine(project: .demo)
        _ = renderWindow(&engine, 0..<bar)
        engine.enqueue(.setCCLanes(voiceID: "bedPluck1", lanes: []), atTick: bar)
        #expect(renderWindow(&engine, bar..<(4 * bar)).isEmpty)
    }

    @Test("Two swaps before the next window emit once per lane")
    func twoSwapsInOneWindowEmitOnce() {
        var engine = LiveEngine(project: .demo)
        _ = renderWindow(&engine, 0..<bar)
        engine.enqueue(.setCCLanes(voiceID: "bedPluck1",
                                   lanes: [flatLane(controller: 30, center: 0.2)]), atTick: bar)
        engine.enqueue(.setCCLanes(voiceID: "bedPluck1",
                                   lanes: [flatLane(controller: 30, center: 0.8)]), atTick: bar)
        let after = renderWindow(&engine, bar..<(4 * bar))
        #expect(after.count == 1)
        #expect(after.first?.value == UInt8((0.8 * 127).rounded()))
    }

    @Test("An unknown voice is a no-op")
    func unknownVoiceIsNoOp() {
        var reference = LiveEngine(project: .demo)
        var engine = LiveEngine(project: .demo)
        engine.enqueue(.setCCLanes(voiceID: "nobody", lanes: []), atTick: 0)
        #expect(renderWindow(&engine, 0..<(2 * bar))
                == renderWindow(&reference, 0..<(2 * bar)))
    }
}
