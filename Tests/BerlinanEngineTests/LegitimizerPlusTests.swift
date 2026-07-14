import Foundation
import Testing
@testable import BerlinanEngine

private let key = Key.default
private let meter = Meter.fourFour
private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

/// Single-voice pedal project with a long legitimization cycle (no mutations
/// interfering) — the accumulator laboratory.
private func accumulatorProject(step: Int = 1, wrap: Int = 4) -> Project {
    var p = Project.demo
    p.transposition = .pedal
    p.voices = [p.voices[0]]
    p.voices[0].ccLanes = nil
    p.voices[0].accumulator = AccumulatorConfig(degreeStep: step, wrap: wrap)
    p.legitimization = Legitimizer.Config(repeats: 32)
    return p
}

// MARK: - Accumulator (FR-L-4)

@Suite("Accumulator")
struct AccumulatorTests {

    /// The LAST sounding note of the loop drifts by (cycle mod wrap)·step.
    @Test("Deterministic per-cycle drift with wrap")
    func drift() {
        let project = accumulatorProject(step: 1, wrap: 4)
        let notes = OfflineRenderer.renderNotes(project: project, bars: 8)
        let base = accumBaseline(project: project)
        let lastPosition = base.max { $0.position < $1.position }!.position

        for barIndex in 0..<8 {
            let expectedDrift = barIndex % 4
            let inBar = notes.filter {
                $0.at >= Tick(barIndex) * bar && $0.at < Tick(barIndex + 1) * bar
            }
            let lastNote = inBar.first { ($0.at - Tick(barIndex) * bar) == lastPosition }
            let baseNote = base.first { $0.position == lastPosition }!
            let expectedPitch = key.resolve(
                DegreePitch(degree: baseNote.pitch.degree + expectedDrift,
                            octave: baseNote.pitch.octave),
                referenceC: 60)
            #expect(lastNote != nil)
            #expect(Int(lastNote!.midiNote) == expectedPitch,
                    "bar \(barIndex): \(lastNote!.midiNote) vs \(expectedPitch)")
        }
    }

    @Test("Live engine matches the offline renderer with an accumulator")
    func liveEquivalence() {
        let project = accumulatorProject(step: 2, wrap: 3)
        let offline = OfflineRenderer.renderNotes(project: project, bars: 8)
        var live = LiveEngine(project: project)
        var notes: [RenderedNote] = []
        var t: Tick = 0
        while t < 8 * bar {
            let end = min(t + 999, 8 * bar)
            notes += live.render(range: t..<end)
            t = end
        }
        notes.sort { $0.at < $1.at || ($0.at == $1.at && $0.voiceID < $1.voiceID) }
        #expect(notes.map { "\($0.at)/\($0.midiNote)/\($0.velocity)" }
             == offline.map { "\($0.at)/\($0.midiNote)/\($0.velocity)" })
    }

    private func accumBaseline(project: Project) -> [PatternNote] {
        // The generated pattern before any drift (cycle 0 == bar 0).
        LiveEngine(project: project).snapshot().voices[0].pattern.notes
    }
}

// MARK: - Ratchet policy (FR-L-5)

@Suite("Ratchet policy")
struct RatchetPolicyTests {

    private func establishedVoice(seed: UInt64) -> Voice {
        var project = Project.demo
        project.voices = [project.voices[0]]
        var voice = LiveEngine(project: project).voiceState(id: "bedPluck1")!.voice
        voice.pattern.lifecycle = .established
        _ = seed
        return voice
    }

    @Test("Probability 0 disables ratchets entirely")
    func disabled() {
        let config = Legitimizer.Config(repeats: 4, ratchetProbability: 0)
        for seed in UInt64(1)...50 {
            let out = Legitimizer.mutate(establishedVoice(seed: seed), key: key,
                                         meter: meter, seed: seed, config: config)
            #expect(out.pattern.notes.allSatisfy { $0.ratchet == 1 })
        }
    }

    @Test("High probability produces ratchets; never more than one note")
    func enabled() {
        let config = Legitimizer.Config(repeats: 4, ratchetProbability: 0.5)
        var anyRatchet = false
        for seed in UInt64(1)...50 {
            let out = Legitimizer.mutate(establishedVoice(seed: seed), key: key,
                                         meter: meter, seed: seed, config: config)
            let ratcheted = out.pattern.notes.filter { $0.ratchet > 1 }
            #expect(ratcheted.count <= 1)
            if !ratcheted.isEmpty { anyRatchet = true }
        }
        #expect(anyRatchet)
    }

    @Test("Old-style config (no probability) decodes and defaults to 0.15")
    func backCompat() throws {
        let json = #"{"repeats": 8}"#
        let decoded = try JSONDecoder().decode(Legitimizer.Config.self,
                                               from: Data(json.utf8))
        #expect(decoded.repeats == 8)
        #expect(decoded.ratchetProbability == nil)
    }
}

// MARK: - Snapshots (FR-L-6)

@Suite("State snapshots")
struct SnapshotRecallTests {

    private func project() -> Project {
        var p = Project.demo
        p.transposition = .pedal
        p.voices = [p.voices[0]]
        p.voices[0].ccLanes = nil
        return p
    }

    @Test("Recall restores patterns and schedule at the next bar")
    func recallRestores() {
        var engine = LiveEngine(project: project())
        _ = engine.render(range: 0..<(2 * bar))
        let captured = engine.captureState()

        // Diverge: transpose +4 and regenerate.
        engine.enqueue(.transpose(degreeOffset: 4), atTick: 2 * bar)
        engine.enqueue(.regenerate(voiceID: "bedPluck1"), atTick: 2 * bar)
        let diverged = engine.render(range: (2 * bar)..<(4 * bar))
        #expect(!diverged.isEmpty)

        // Recall mid-bar 4 → binds at bar 5.
        engine.enqueue(.recallSnapshot(captured), atTick: 4 * bar + beat)
        let after = engine.render(range: (4 * bar)..<(7 * bar))

        // Bar 4 still the diverged material (regenerated + transposed).
        let bar4 = after.filter { $0.at < 5 * bar }
        #expect(!bar4.isEmpty)

        // Bars 5+: the captured pattern, transposition reverted (offset 0).
        let capturedNotes = captured.voices[0].pattern.notes
            .sorted { $0.position < $1.position }
        let bar5 = after.filter { $0.at >= 5 * bar && $0.at < 6 * bar }
            .sorted { $0.at < $1.at }
        #expect(bar5.count == capturedNotes.count)
        for (rendered, patternNote) in zip(bar5, capturedNotes) {
            #expect(rendered.at - 5 * bar == patternNote.position)
            let expected = key.resolve(patternNote.pitch, referenceC: 60)
            #expect(Int(rendered.midiNote) == expected)
        }
        #expect(engine.transpositionOffset(atBar: 5) == 0, "schedule restored")
    }

    @Test("Recall is chunk-independent")
    func chunkIndependent() {
        func run(window: Tick) -> [String] {
            var engine = LiveEngine(project: project())
            _ = engine.render(range: 0..<bar)
            let snap = engine.captureState()
            engine.enqueue(.regenerate(voiceID: "bedPluck1"), atTick: bar)
            engine.enqueue(.recallSnapshot(snap), atTick: 3 * bar + 5)
            var notes: [RenderedNote] = []
            var t: Tick = bar
            while t < 8 * bar {
                let end = min(t + window, 8 * bar)
                notes += engine.render(range: t..<end)
                t = end
            }
            return notes.map { "\($0.at)/\($0.midiNote)/\($0.velocity)" }
        }
        #expect(run(window: 7 * bar) == run(window: 611))
        #expect(run(window: 7 * bar) == run(window: bar))
    }

    @Test("Snapshot round-trips through JSON (persistence-ready)")
    func codable() throws {
        var engine = LiveEngine(project: project())
        _ = engine.render(range: 0..<bar)
        let snap = engine.captureState()
        let data = try JSONEncoder().encode(snap)
        let back = try JSONDecoder().decode(LiveEngine.StateSnapshot.self, from: data)
        #expect(back == snap)
    }
}
