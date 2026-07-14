import Testing
@testable import BerlinanEngine

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

private func note(_ at: Tick, velocity: UInt8 = 100, gate: Tick = 120,
                  voice: String = "a") -> RenderedNote {
    RenderedNote(voiceID: voice, at: at, midiNote: 60, velocity: velocity,
                 gate: gate, accent: false, ratchet: 1)
}

private func delayProject(enabled: Bool) -> Project {
    var p = Project.demo
    p.transposition = .pedal
    p.voices = [p.voices[0]]
    p.voices[0].ccLanes = nil
    p.voices[0].midiDelay = MIDIDelayConfig(
        enabled: enabled, division: .eighth, repeats: 3,
        velocityDecay: 0.55, gateScale: 0.9)
    return p
}

// MARK: - The post-processor

@Suite("MIDI delay processor")
struct MIDIDelayProcessorTests {

    private let config = MIDIDelayConfig(enabled: true, division: .eighth,
                                         repeats: 3, velocityDecay: 0.55,
                                         gateScale: 0.9)

    @Test("Echo times, chained velocity decay, gate scaling, tagging")
    func expansion() {
        let out = MIDIDelay.process([note(0)], config: config)
        #expect(out.count == 4)
        let echoes = out.filter(\.isEcho).sorted { $0.at < $1.at }
        #expect(echoes.map(\.at) == [480, 960, 1440])          // k·eighth
        #expect(echoes.map { Int($0.velocity) } == [55, 30, 17])
        #expect(echoes.map { Int($0.gate) } == [108, 97, 87])  // ×0.9 chain
        #expect(echoes.allSatisfy { $0.midiNote == 60 })
        #expect(out.filter { !$0.isEcho }.count == 1)
    }

    @Test("Inaudible tail cutoff: echoes stop below velocity 8")
    func cutoff() {
        let longConfig = MIDIDelayConfig(enabled: true, division: .eighth,
                                         repeats: 8, velocityDecay: 0.55,
                                         gateScale: 0.9)
        let out = MIDIDelay.process([note(0)], config: longConfig)
        // 100→55→30→17→9→(5 <8 stops): 4 echoes.
        #expect(out.filter(\.isEcho).count == 4)
        #expect(out.filter(\.isEcho).allSatisfy { $0.velocity >= 8 })
    }

    @Test("Disabled config is the identity")
    func disabled() {
        var off = config
        off.enabled = false
        let input = [note(0), note(beat)]
        #expect(MIDIDelay.process(input, config: off) == input)
    }

    @Test("Echoes never re-echo (idempotent over already-processed streams)")
    func noFeedback() {
        let once = MIDIDelay.process([note(0)], config: config)
        let twice = MIDIDelay.process(once, config: config)
        #expect(twice.count == once.count)
    }

    @Test("Division ticks are quarter-based musical values")
    func divisions() {
        #expect(DelayDivision.dotted8th.ticks == 720)
        #expect(DelayDivision.eighth.ticks == 480)
        #expect(DelayDivision.quarter.ticks == 960)
    }
}

// MARK: - Renderer integration

@Suite("MIDI delay in the renderers")
struct MIDIDelayRenderTests {

    @Test("Offline render with delay carries echoes; without it none")
    func offlineEchoes() {
        let with = OfflineRenderer.renderNotes(project: delayProject(enabled: true), bars: 2)
        let without = OfflineRenderer.renderNotes(project: delayProject(enabled: false), bars: 2)
        #expect(with.count > without.count)
        #expect(with.contains(where: \.isEcho))
        #expect(!without.contains(where: \.isEcho))
        // Non-echo notes identical in both.
        let originals = with.filter { !$0.isEcho }
        #expect(originals.map(\.at) == without.map(\.at))
    }

    @Test("Patterns and snapshot stay echo-free (output boundary only)")
    func patternsClean() {
        var engine = LiveEngine(project: delayProject(enabled: true))
        _ = engine.render(range: 0..<(2 * bar))
        let pattern = engine.snapshot().voices[0].pattern
        // The pattern is the generated bed (few sparse notes), not an
        // echo-multiplied stream.
        #expect(pattern.notes.count <= 7)
        #expect(engine.snapshot().voices[0].midiDelayEnabled)
    }

    @Test("Live ≡ offline with delay enabled (sorted streams)")
    func liveEquivalence() {
        let project = delayProject(enabled: true)
        let offline = OfflineRenderer.renderNotes(project: project, bars: 6)
            .sorted { ($0.at, $0.midiNote, $0.velocity) < ($1.at, $1.midiNote, $1.velocity) }
        var live = LiveEngine(project: project)
        var notes: [RenderedNote] = []
        var t: Tick = 0
        while t < 6 * bar {
            let end = min(t + 777, 6 * bar)
            notes += live.render(range: t..<end)
            t = end
        }
        let sorted = notes.sorted { ($0.at, $0.midiNote, $0.velocity) < ($1.at, $1.midiNote, $1.velocity) }
        #expect(sorted.map { "\($0.at)/\($0.midiNote)/\($0.velocity)/\($0.isEcho)" }
             == offline.map { "\($0.at)/\($0.midiNote)/\($0.velocity)/\($0.isEcho)" })
    }

    @Test("Live toggle: off silences future echoes, on re-enables")
    func liveToggle() {
        var engine = LiveEngine(project: delayProject(enabled: true))
        let first = engine.render(range: 0..<bar)
        #expect(first.contains(where: \.isEcho))

        engine.enqueue(.setMIDIDelay(voiceID: "bedPluck1", enabled: false), atTick: bar)
        let second = engine.render(range: bar..<(2 * bar))
        #expect(!second.contains(where: \.isEcho))
        #expect(!engine.snapshot().voices[0].midiDelayEnabled)

        engine.enqueue(.setMIDIDelay(voiceID: "bedPluck1", enabled: true), atTick: 2 * bar)
        let third = engine.render(range: (2 * bar)..<(3 * bar))
        #expect(third.contains(where: \.isEcho))
    }

    @Test("SMF render with delay has more note-ons")
    func smfEchoes() {
        func noteOnCount(_ bytes: [UInt8]) -> Int {
            bytes.enumerated().filter { $0.element & 0xF0 == 0x90 && $0.offset > 22 }.count
        }
        let with = OfflineRenderer.render(project: delayProject(enabled: true), bars: 4)
        let without = OfflineRenderer.render(project: delayProject(enabled: false), bars: 4)
        #expect(with.count > without.count)
    }
}
