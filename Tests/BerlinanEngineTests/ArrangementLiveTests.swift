import Testing
@testable import BerlinanEngine

/// Phase 26: the LiveEngine obeys ArrangementSM directives at bar boundaries
/// — additive builds, mutation nudges, root thinning, and the stop request —
/// deterministically and chunk-safely.

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

private func chunkedRender(_ engine: inout LiveEngine, upTo total: Tick,
                           window: Tick) -> [RenderedNote] {
    var notes: [RenderedNote] = []
    var t: Tick = 0
    while t < total {
        let end = min(t + window, total)
        notes += engine.render(range: t..<end)
        t = end
    }
    return notes
}

private func signature(_ notes: [RenderedNote]) -> [String] {
    notes.sorted { $0.at < $1.at || ($0.at == $1.at && $0.voiceID < $1.voiceID) }
        .map { "\($0.voiceID)/\($0.at)/\($0.midiNote)/\($0.velocity)/\($0.gate)" }
}

/// Demo project with the arrangement autopilot on and a pedal harmony
/// (assertions on absolute pitches stay simple).
private func arrangedProject() -> Project {
    var p = Project.demo
    p.transposition = .pedal
    p.arrangement = ArrangementConfig(enabled: true)
    return p
}

@Suite("Arrangement — live engine integration")
struct ArrangementLiveTests {

    @Test("Enabled at init: only the first build-order voice sounds at start")
    func additiveStart() {
        var engine = LiveEngine(project: arrangedProject())
        let notes = engine.render(range: 0..<(4 * bar))
        let voices = Set(notes.map(\.voiceID))
        #expect(voices == ["bedPluck1"])
    }

    @Test("Voices join additively at bar-aligned times, 8–16 bars apart")
    func additiveJoins() {
        var engine = LiveEngine(project: arrangedProject())
        let notes = engine.render(range: 0..<(40 * bar))
        func firstOnset(_ id: String) -> Tick? {
            notes.filter { $0.voiceID == id }.map(\.at).min()
        }
        let join2 = try! #require(firstOnset("bedPluck2"))
        let join3 = try! #require(firstOnset("bass"))
        // Activation is bar-aligned; the first onset lands inside the
        // activation bar (patterns need not start on the downbeat).
        #expect((8...16).contains(Int(join2 / bar)))
        #expect((8...16).contains(Int(join3 / bar) - Int(join2 / bar)))
        #expect(join3 > join2, "bass must join after the second bed pluck")
    }

    @Test("Chunked render is window-size independent with arrangement on",
          arguments: [Tick(555), Tick(3840), Tick(1000)])
    func chunkInvariance(window: Tick) {
        var whole = LiveEngine(project: arrangedProject())
        let wholeNotes = whole.render(range: 0..<(40 * bar))
        var chunked = LiveEngine(project: arrangedProject())
        let chunkedNotes = chunkedRender(&chunked, upTo: 40 * bar, window: window)
        #expect(signature(wholeNotes) == signature(chunkedNotes))
    }

    @Test("Offline render matches the live render with arrangement on")
    func offlineParity() {
        let offline = OfflineRenderer.renderNotes(project: arrangedProject(),
                                                  bars: 40)
        var live = LiveEngine(project: arrangedProject())
        let liveNotes = chunkedRender(&live, upTo: 40 * bar, window: 777)
        #expect(signature(liveNotes) == signature(offline))
    }

    @Test("advancePhase binds at the next bar: second voice enters at bar 1")
    func advancePhaseAction() {
        var engine = LiveEngine(project: arrangedProject())
        engine.enqueue(.advancePhase, atTick: beat)          // mid-bar 0
        let notes = engine.render(range: 0..<(3 * bar))
        let join = notes.filter { $0.voiceID == "bedPluck2" }.map(\.at).min()
        #expect(join == bar)
    }

    @Test("Snapshot mirrors phase, bars-in-phase, and active voices")
    func snapshotMirror() {
        var engine = LiveEngine(project: arrangedProject())
        _ = engine.render(range: 0..<(2 * bar))
        let status = try! #require(engine.snapshot().arrangement)
        #expect(status.phase == .build)
        #expect(status.activeVoices == ["bedPluck1"])
        #expect(status.barsInPhase >= 1)
    }

    @Test("Disabled arrangement: snapshot reports nil, render unchanged")
    func disabledIsInert() {
        var plain = LiveEngine(project: .demo)
        #expect(plain.snapshot().arrangement == nil)
        let notes = plain.render(range: 0..<(4 * bar))
        var reference = LiveEngine(project: .demo)
        #expect(signature(notes) == signature(reference.render(range: 0..<(4 * bar))))
    }

    @Test("setArrangementEnabled mid-play adopts the running ensemble (bed)")
    func enableMidPlay() {
        var engine = LiveEngine(project: .demo)   // all voices, autopilot off
        _ = engine.render(range: 0..<(2 * bar))
        engine.enqueue(.setArrangementEnabled(true), atTick: 2 * bar)
        _ = engine.render(range: (2 * bar)..<(3 * bar))
        let status = try! #require(engine.snapshot().arrangement)
        #expect(status.phase == .bed)
        #expect(status.activeVoices == ["bedPluck1", "bedPluck2", "bass"])
    }

    @Test("Fast-forwarded arc ends thinned to roots and requests a stop")
    func endingStopsAndThins() {
        var engine = LiveEngine(project: arrangedProject())
        for k in 0..<25 {                          // advance once per bar
            engine.enqueue(.advancePhase, atTick: Tick(k) * bar)
        }
        let notes = engine.render(range: 0..<(40 * bar))
        let stop = try! #require(engine.pendingStopTick)
        #expect(stop % bar == 0, "stop must land on a bar boundary")
        #expect(notes.allSatisfy { $0.at < stop },
                "nothing may sound at or after the stop tick")
        // The final audible bar belongs to the thinned survivor: roots only —
        // a single pitch class (the B-part walk may still hold a
        // transposition in the fast-forwarded arc).
        let lastBarStart = ((notes.map(\.at).max()! / bar)) * bar
        let closing = notes.filter { $0.at >= lastBarStart }
        #expect(closing.allSatisfy { $0.voiceID == "bedPluck1" })
        #expect(Set(closing.map { $0.midiNote % 12 }).count == 1,
                "closing bar must be roots only, got \(closing.map(\.midiNote))")
    }
}
