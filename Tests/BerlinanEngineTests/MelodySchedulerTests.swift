import Testing
import Foundation
@testable import BerlinanEngine

/// Phase 29: alternating phrase scheduler (FR-MEL-3), interval tension
/// scoring with the tension-walk contour (FR-MEL-4), bass melody (FR-MEL-5).

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat
private let step: Tick = beat / 4

// MARK: - Alternating scheduler (FR-MEL-3)

@Suite("Alternating scheduler")
struct AlternationTests {

    private func pairProject() -> Project {
        var p = Project.demo                    // bedPluck1 + bedPluck2 + bass
        p.transposition = .pedal
        p.alternating = AlternatingConfig(voiceA: "bedPluck1",
                                          voiceB: "bedPluck2", phraseBars: 4)
        return p
    }

    @Test("The two voices never sound at the same tick; slots alternate")
    func neverSimultaneous() {
        var engine = LiveEngine(project: pairProject())
        let notes = engine.render(range: 0..<(16 * bar))
        let a = notes.filter { $0.voiceID == "bedPluck1" }
        let b = notes.filter { $0.voiceID == "bedPluck2" }
        #expect(!a.isEmpty && !b.isEmpty)
        // Onset slots: A owns bars 0–3 and 8–11, B owns 4–7 and 12–15.
        #expect(a.allSatisfy { Int($0.at / bar) / 4 % 2 == 0 },
                "A onsets outside its slots")
        #expect(b.allSatisfy { Int($0.at / bar) / 4 % 2 == 1 },
                "B onsets outside its slots")
        // Tick-level: no A note may still ring inside a B slot and vice
        // versa (gates clamp at the slot edge).
        for note in a + b {
            let slotEnd = ((note.at / (4 * bar)) + 1) * (4 * bar)
            #expect(note.at + note.gate <= slotEnd,
                    "gate must clamp at the slot edge")
        }
    }

    @Test("setAlternating(nil) restores both voices everywhere")
    func toggleOff() {
        var engine = LiveEngine(project: pairProject())
        _ = engine.render(range: 0..<(4 * bar))
        engine.enqueue(.setAlternating(nil), atTick: 4 * bar)
        let notes = engine.render(range: (4 * bar)..<(9 * bar))
        let aBars = Set(notes.filter { $0.voiceID == "bedPluck1" }
            .map { Int($0.at / bar) })
        #expect(aBars.contains { $0 >= 4 && $0 <= 7 },
                "A must sound in B's former slot once alternation is off")
    }

    @Test("Alternation render is chunk-independent")
    func chunkSafe() {
        func run(window: Tick) -> [String] {
            var engine = LiveEngine(project: pairProject())
            var notes: [RenderedNote] = []
            var t: Tick = 0
            while t < 12 * bar {
                let end = min(t + window, 12 * bar)
                notes += engine.render(range: t..<end)
                t = end
            }
            return notes.map { "\($0.voiceID)/\($0.at)/\($0.midiNote)/\($0.gate)" }
        }
        #expect(run(window: 12 * bar) == run(window: 777))
    }

    @Test("Alternating voices get different delay-hint divisions")
    func delayTags() {
        let a = DelayHint.compute(role: .bedPluck1, bpm: 90, alternationSlot: 0)
        let b = DelayHint.compute(role: .bedPluck2, bpm: 90, alternationSlot: 1)
        #expect(a.division != b.division,
                "call and answer must echo differently (M §8.3)")
        let plain = DelayHint.compute(role: .bedPluck2, bpm: 90)
        #expect(DelayHint.compute(role: .bedPluck2, bpm: 90,
                                  alternationSlot: nil) == plain)
    }
}

// MARK: - Tension scoring (FR-MEL-4)

@Suite("Tension table")
struct TensionTests {

    @Test("Manual's ordering: seconds/tritone tense, fifth/unison restful")
    func ordering() {
        #expect(TensionTable.score(semitones: 1) > TensionTable.score(semitones: 6) ||
                TensionTable.score(semitones: 1) >= TensionTable.score(semitones: 6))
        #expect(TensionTable.score(semitones: 6) > TensionTable.score(semitones: 10))
        #expect(TensionTable.score(semitones: 10) > TensionTable.score(semitones: 7))
        #expect(TensionTable.score(semitones: 7) > TensionTable.score(semitones: 0))
        #expect(TensionTable.score(semitones: 11) > TensionTable.score(semitones: 4))
        #expect(TensionTable.score(semitones: 13) == TensionTable.score(semitones: 1),
                "intervals fold to one octave")
    }

    @Test("Tension-walk pick: tense position picks the tensest candidate")
    func walkPick() {
        // Melody so far: C (degree 0) on the downbeat. Candidates: D (2 st),
        // G (7 st), Bb (10 st) — C minor.
        func note(_ sixteenth: Int, degree: Int) -> PatternNote {
            PatternNote(position: Tick(sixteenth) * step,
                        pitch: DegreePitch(degree: degree, octave: 0), gate: 60)
        }
        let pattern = Pattern(id: "walk", length: bar,
                              notes: [note(0, degree: 0), note(4, degree: 1),
                                      note(8, degree: 4), note(12, degree: 6)],
                              provenance: Provenance(generator: .seedProcedure,
                                                     version: 1, seed: 2))
        let current: Set<Int> = [0]
        let tense = Melody.growthPick(pattern: pattern, current: current,
                                      meter: .fourFour, key: .default,
                                      referenceC: 60, walkPosition: 0)
        #expect(tense == 3, "walk position 0 wants the m7 (Bb)")
        let release = Melody.growthPick(pattern: pattern, current: current,
                                        meter: .fourFour, key: .default,
                                        referenceC: 60, walkPosition: 1)
        #expect(release == 2, "release positions want the fifth (G)")
    }
}

// MARK: - Bass melody (FR-MEL-5)

@Suite("Bass melody generator")
struct BassMelodyTests {

    private func walkProject() -> Project {
        var p = Project.demo
        p.transposition = TranspositionSchedule(events: [
            TranspositionEvent(bar: 0, degreeOffset: 0),
            TranspositionEvent(bar: 1, degreeOffset: 5),
            TranspositionEvent(bar: 2, degreeOffset: 3),
        ])
        p.voices = [VoiceConfig(id: "bass", role: .bass,
                                register: RegisterWindow(low: 24, high: 48),
                                referenceC: 36,
                                generator: .bassMelody(bars: 3), channel: 2)]
        return p
    }

    @Test("Beat 1 of every bar states the bar's progression root")
    func rootsPerBar() {
        let project = walkProject()
        let pattern = OfflineRenderer.makePattern(project.voices[0],
                                                  project: project,
                                                  seedLabels: ["t"], idSuffix: "t")
        #expect(pattern.length == 3 * bar)
        for (barIndex, expected) in [0, 5, 3].enumerated() {
            let downbeat = pattern.notes.first {
                $0.position == Tick(barIndex) * bar
            }
            #expect(downbeat?.pitch.degree == expected,
                    "bar \(barIndex) root must be degree \(expected)")
        }
    }

    @Test("Between roots: in-scale stepwise passing tones (|Δdegree| ≤ 2)")
    func passingTones() {
        let project = walkProject()
        let pattern = OfflineRenderer.makePattern(project.voices[0],
                                                  project: project,
                                                  seedLabels: ["t"], idSuffix: "t")
        let sorted = pattern.notes.sorted { $0.position < $1.position }
        #expect(sorted.count > 3, "passing tones must exist between roots")
        for pair in zip(sorted, sorted.dropFirst()) {
            let delta = abs(pair.1.pitch.degree - pair.0.pitch.degree)
            #expect(delta <= 2, "step \(pair.0.pitch.degree)→\(pair.1.pitch.degree)")
        }
    }

    @Test("The walk's laws hold for every seed; seeds vary the walk (phase 38)")
    func seededVariety() {
        var signatures: Set<String> = []
        for seed in UInt64(1)...16 {
            let pattern = PatternFactory.makeBassMelody(
                id: "t", bars: 3,
                schedule: TranspositionSchedule(events: [
                    TranspositionEvent(bar: 0, degreeOffset: 0),
                    TranspositionEvent(bar: 1, degreeOffset: 5),
                    TranspositionEvent(bar: 2, degreeOffset: 3),
                ]),
                meter: .fourFour, seed: seed)
            // Laws: downbeat roots, ≤2-degree steps incl. the wrap.
            for (barIndex, expected) in [0, 5, 3].enumerated() {
                let downbeat = pattern.notes.first {
                    $0.position == Tick(barIndex) * bar
                }
                #expect(downbeat?.pitch.degree == expected, "seed \(seed)")
            }
            let sorted = pattern.notes.sorted { $0.position < $1.position }
            for pair in zip(sorted, sorted.dropFirst()) {
                #expect(abs(pair.1.pitch.degree - pair.0.pitch.degree) <= 2,
                        "seed \(seed)")
            }
            let wrapDelta = abs((sorted.first?.pitch.degree ?? 0)
                                - (sorted.last?.pitch.degree ?? 0))
            #expect(wrapDelta <= 2, "seed \(seed): the loop must close stepwise")
            signatures.insert(sorted
                .map { "\($0.position)/\($0.pitch.degree)/\($0.pitch.octave)" }
                .joined(separator: ","))
            // Determinism: the same seed reproduces itself.
            let again = PatternFactory.makeBassMelody(
                id: "t", bars: 3,
                schedule: TranspositionSchedule(events: [
                    TranspositionEvent(bar: 0, degreeOffset: 0),
                    TranspositionEvent(bar: 1, degreeOffset: 5),
                    TranspositionEvent(bar: 2, degreeOffset: 3),
                ]),
                meter: .fourFour, seed: seed)
            #expect(again.notes == pattern.notes, "seed \(seed)")
        }
        #expect(signatures.count >= 4,
                "16 seeds must produce real variety, got \(signatures.count)")
    }

    @Test("Live regenerate re-rolls the bass walk (phase 38)")
    func regenerateVaries() {
        var project = walkProject()
        project.transposition = TranspositionSchedule(events: [
            TranspositionEvent(bar: 0, degreeOffset: 0),
            TranspositionEvent(bar: 1, degreeOffset: 5),
            TranspositionEvent(bar: 2, degreeOffset: 3),
        ])
        project.voices[0].generator = .bassMelody(bars: 3)
        var engine = LiveEngine(project: project)
        func signature() -> String {
            engine.voiceState(id: "bass")!.pattern.notes
                .map { "\($0.position)/\($0.pitch.degree)/\($0.pitch.octave)" }
                .joined(separator: ",")
        }
        let before = signature()
        engine.enqueue(.regenerate(voiceID: "bass"), atTick: 0)
        _ = engine.render(range: 0..<(4 * bar))
        #expect(signature() != before,
                "regenerate must produce a different walk over the same harmony")
    }
}
