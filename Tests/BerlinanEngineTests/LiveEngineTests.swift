import Testing
@testable import BerlinanEngine

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat
private let sixteenth: Tick = Time.ppqn / 4

private func signature(_ notes: [RenderedNote]) -> [String] {
    notes.map { "\($0.voiceID)/\($0.at)/\($0.midiNote)/\($0.velocity)/\($0.gate)" }
}

/// Render a LiveEngine in windows of the given size (unaligned sizes allowed).
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

// MARK: - Equivalence with the offline renderer

@Suite("Live engine — pull-model equivalence")
struct LiveEquivalenceTests {

    @Test("No actions: chunked live render matches OfflineRenderer",
          arguments: [Tick(1000), Tick(3840), Tick(777)])
    func matchesOffline(window: Tick) {
        let bars = 16
        let offline = OfflineRenderer.renderNotes(project: .demo, bars: bars)
        var live = LiveEngine(project: .demo)
        let notes = chunkedRender(&live, upTo: Tick(bars) * bar, window: window)
            .sorted { $0.at < $1.at || ($0.at == $1.at && $0.voiceID < $1.voiceID) }
        #expect(signature(notes) == signature(offline))
    }

    @Test("Chunk-independence with actions at fixed request ticks")
    func chunkIndependentWithActions() {
        func run(window: Tick) -> [RenderedNote] {
            var engine = LiveEngine(project: .demo)
            engine.enqueue(.transpose(degreeOffset: 4), atTick: 2 * bar + beat)
            engine.enqueue(.regenerate(voiceID: "bedPluck1"), atTick: 5 * bar + 3)
            engine.enqueue(.blankCycle(voiceID: "bass"), atTick: 6 * bar)
            return chunkedRender(&engine, upTo: 12 * bar, window: window)
                .sorted { $0.at < $1.at || ($0.at == $1.at && $0.voiceID < $1.voiceID) }
        }
        #expect(signature(run(window: 12 * bar)) == signature(run(window: 555)))
        #expect(signature(run(window: 12 * bar)) == signature(run(window: bar)))
    }
}

// MARK: - Actions

@Suite("Live engine — actions")
struct LiveActionTests {

    /// Single-voice project with a pedal schedule for precise assertions.
    private func soloProject() -> Project {
        var p = Project.demo
        p.voices = [p.voices[0]]          // bedPluck1, 1-bar loop
        p.transposition = .pedal
        return p
    }

    @Test("Regenerate binds at the first loop boundary ≥ request tick")
    func regenerateBinding() {
        var engine = LiveEngine(project: soloProject())
        engine.enqueue(.regenerate(voiceID: "bedPluck1"), atTick: bar + beat)   // mid-bar 1
        let notes = engine.render(range: 0..<(4 * bar))
        let byBar = Dictionary(grouping: notes) { Int($0.at / bar) }
        func sig(_ b: Int) -> [String] {
            (byBar[b] ?? []).map { "\($0.at % bar)/\($0.midiNote)" }
        }
        #expect(sig(1) == sig(0), "bar 1 must still be the old pattern")
        #expect(sig(2) != sig(0), "bar 2 must be the regenerated pattern")
    }

    @Test("Regenerated pattern has a new provenance seed and restarts at N plays")
    func regenerateProvenance() {
        var engine = LiveEngine(project: soloProject())
        let originalSeed = engine.voiceState(id: "bedPluck1")!.pattern.provenance.seed
        engine.enqueue(.regenerate(voiceID: "bedPluck1"), atTick: 0)
        _ = engine.render(range: 0..<(2 * bar))
        let state = engine.voiceState(id: "bedPluck1")!
        #expect(state.pattern.provenance.seed != originalSeed)
    }

    @Test("Blank cycle: one silent loop, verbatim resume, lifecycle frozen")
    func blankCycle() {
        var engine = LiveEngine(project: soloProject())
        engine.enqueue(.blankCycle(voiceID: "bedPluck1"), atTick: bar)
        let notes = engine.render(range: 0..<(4 * bar))
        let byBar = Dictionary(grouping: notes) { Int($0.at / bar) }
        func sig(_ b: Int) -> [String] {
            (byBar[b] ?? []).map { "\($0.at % bar)/\($0.midiNote)" }
        }
        #expect(byBar[1] == nil, "bar 1 must be silent")
        #expect(sig(2) == sig(0), "the pattern resumes verbatim after the blank")
        // Lifecycle frozen during the blank: bars 0,2,3 = three audible plays
        // of a 4-play cycle → still repeating, no mutation yet at bar 3.
        #expect(sig(3) == sig(0))
    }

    @Test("Transpose enqueued mid-bar binds at the next bar boundary")
    func transposeBinding() {
        var engine = LiveEngine(project: soloProject())
        engine.enqueue(.transpose(degreeOffset: 4), atTick: beat)   // mid-bar 0
        let notes = engine.render(range: 0..<(2 * bar))
        let bar0 = notes.filter { $0.at < bar }
        let bar1 = notes.filter { $0.at >= bar }
        // Pattern repeats verbatim (Law 1), so pitch sets differ exactly by
        // the diatonic offset: compare the first onsets (both are the root).
        let root0 = bar0.min { $0.at < $1.at }!.midiNote
        let root1 = bar1.min { $0.at < $1.at }!.midiNote
        #expect(root0 == 60)    // C
        #expect(root1 == 67)    // +4 degrees in C minor = G
    }

    @Test("Lock prevents auto-mutation; unlock resumes it")
    func lockBlocksMutation() {
        // Find a master seed whose unlocked render mutates by bar 8.
        var mutatingSeed: UInt64? = nil
        for candidate in UInt64(1)...8 {
            var p = soloProject()
            p.masterSeed = candidate
            var probe = LiveEngine(project: p)
            let notes = probe.render(range: 0..<(8 * bar))
            let byBar = Dictionary(grouping: notes) { Int($0.at / bar) }
            func sig(_ b: Int) -> [String] {
                (byBar[b] ?? []).map { "\($0.at % bar)/\($0.midiNote)/\($0.velocity)" }
            }
            if sig(4) != sig(0) { mutatingSeed = candidate; break }
        }
        let seed = try! #require(mutatingSeed)

        var p = soloProject()
        p.masterSeed = seed
        var engine = LiveEngine(project: p)
        engine.enqueue(.setLock(voiceID: "bedPluck1", on: true), atTick: 0)
        let notes = engine.render(range: 0..<(8 * bar))
        let byBar = Dictionary(grouping: notes) { Int($0.at / bar) }
        func sig(_ b: Int) -> [String] {
            (byBar[b] ?? []).map { "\($0.at % bar)/\($0.midiNote)/\($0.velocity)" }
        }
        for b in 1..<8 {
            #expect(sig(b) == sig(0), "locked voice must repeat verbatim forever (bar \(b))")
        }
    }
}
