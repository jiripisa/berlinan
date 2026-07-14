import Foundation
import Testing
@testable import BerlinanEngine

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat
private let meter = Meter.fourFour

// MARK: - Progressions

@Suite("Progression player (FR-H-4)")
struct ProgressionTests {

    @Test("Looped progression unrolls with correct bars and offsets")
    func loopedUnroll() {
        let progression = Progression(
            name: "test", steps: [ProgressionStep(degreeOffset: 0, bars: 4),
                                  ProgressionStep(degreeOffset: 5, bars: 4),
                                  ProgressionStep(degreeOffset: 3, bars: 4)],
            loop: true)
        var project = Project.demo
        project.harmony = .progression(progression)
        let (schedule, bassOnly) = HarmonyScheduler.resolve(project: project)
        #expect(!bassOnly)
        // Two full cycles:
        for (bar, expected) in [(0, 0), (3, 0), (4, 5), (8, 3), (12, 0), (16, 5), (20, 3), (24, 0)] {
            #expect(schedule.offset(atBar: bar) == expected, "bar \(bar)")
        }
    }

    @Test("Non-looped progression holds its last offset")
    func nonLooped() {
        let progression = Progression(
            name: "once", steps: [ProgressionStep(degreeOffset: 0, bars: 2),
                                  ProgressionStep(degreeOffset: 4, bars: 2)],
            loop: false)
        var project = Project.demo
        project.harmony = .progression(progression)
        let (schedule, _) = HarmonyScheduler.resolve(project: project)
        #expect(schedule.offset(atBar: 0) == 0)
        #expect(schedule.offset(atBar: 2) == 4)
        #expect(schedule.offset(atBar: 100) == 4)
    }

    @Test("Manual §7.1 presets carry the documented degree walks")
    func presets() {
        let byName = Dictionary(uniqueKeysWithValues: Progression.presets.map { ($0.name, $0) })
        #expect(byName["1-7-6-5"]!.steps.map(\.degreeOffset) == [0, 6, 5, 4])
        #expect(byName["i-iv-v-i"]!.steps.map(\.degreeOffset) == [0, 3, 4, 0])
        #expect(byName["1-5-6-7"]!.steps.map(\.degreeOffset) == [0, 4, 5, 6])
        #expect(byName["1-6-4-7"]!.steps.map(\.degreeOffset) == [0, 5, 3, 6])
        #expect(byName["1-6-4-1"]!.steps.map(\.degreeOffset) == [0, 5, 3, 0])
        #expect(byName["7-5-6"]!.steps.map(\.degreeOffset) == [6, 4, 5])
        #expect(byName["6-5-4-1"]!.steps.map(\.degreeOffset) == [5, 4, 3, 0])
        for preset in Progression.presets {
            #expect(preset.steps.allSatisfy { (0...6).contains($0.degreeOffset) })
            #expect(preset.steps.allSatisfy { $0.bars > 0 })
        }
    }
}

// MARK: - Weighted-random transposition (FR-H-5)

@Suite("Weighted-random transposition")
struct WeightedTests {

    private func project(seed: UInt64) -> Project {
        var p = Project.demo
        p.masterSeed = seed
        p.harmony = .weightedRandom(weights: [0: 0.4, 4: 0.3, 5: 0.3],
                                    minPeriodBars: 8, maxPeriodBars: 16)
        return p
    }

    @Test("Deterministic per master seed")
    func deterministic() {
        let a = HarmonyScheduler.resolve(project: project(seed: 7)).schedule
        let b = HarmonyScheduler.resolve(project: project(seed: 7)).schedule
        #expect(a == b)
        let c = HarmonyScheduler.resolve(project: project(seed: 8)).schedule
        #expect(a != c)
    }

    @Test("Offsets drawn only from the weight table; gaps within the period range")
    func constrained() {
        let schedule = HarmonyScheduler.resolve(project: project(seed: 42)).schedule
        let events = schedule.events
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { [0, 4, 5].contains($0.degreeOffset) })
        for (a, b) in zip(events, events.dropFirst()) {
            let gap = b.bar - a.bar
            #expect((8...16).contains(gap), "gap \(gap)")
        }
        // Horizon coverage: events reach near the documented 1024-bar limit.
        #expect(events.last!.bar > 1000)
    }
}

// MARK: - Bass reharmonization (FR-H-6)

@Suite("Bass reharmonization")
struct BassReharmTests {

    private func project() -> Project {
        var p = Project.demo
        p.harmony = .bassReharm(Progression(
            name: "walk", steps: [ProgressionStep(degreeOffset: 0, bars: 1),
                                  ProgressionStep(degreeOffset: 5, bars: 1)],
            loop: true))
        return p
    }

    @Test("Upper voices are frozen while the bass follows the progression")
    func uppersFrozen() {
        let notes = OfflineRenderer.renderNotes(project: project(), bars: 4)
        // Bed voices: identical pitch sets in bar 0 and bar 1 (Law 1 keeps
        // patterns verbatim; only a transposition could move them).
        for voiceID in ["bedPluck1", "bedPluck2"] {
            let byBar = Dictionary(grouping: notes.filter { $0.voiceID == voiceID }) {
                Int($0.at / bar)
            }
            let sig0 = byBar[0]!.map { "\($0.at % bar)/\($0.midiNote)" }
            let sig1 = (byBar[1] ?? []).map { "\(($0.at - bar) % bar)/\($0.midiNote)" }
            if voiceID == "bedPluck1" {   // 1-bar loop: exact comparison valid
                #expect(sig0 == sig1, "\(voiceID) must not transpose")
            }
        }
        // Bass: bar 0 majority pitch class C (0), bar 1 majority Ab (8).
        let bass = notes.filter { $0.voiceID == "bass" }
        func majorityClass(bar barIndex: Int) -> Int {
            let classes = bass.filter { $0.at >= Tick(barIndex) * bar && $0.at < Tick(barIndex + 1) * bar }
                .map { Int($0.midiNote) % 12 }
            return classes.reduce(into: [:]) { $0[$1, default: 0] += 1 }
                .max { $0.value < $1.value }!.key
        }
        #expect(majorityClass(bar: 0) == 0)
        #expect(majorityClass(bar: 1) == 8)
    }

    @Test("Bass gates stretch to at least one beat (held roots)")
    func heldRoots() {
        let notes = OfflineRenderer.renderNotes(project: project(), bars: 2)
        let bass = notes.filter { $0.voiceID == "bass" }
        #expect(!bass.isEmpty)
        #expect(bass.allSatisfy { $0.gate >= beat })
    }
}

// MARK: - Compatibility & snapshot

@Suite("Harmony compatibility")
struct HarmonyCompatTests {

    @Test("Projects without a harmony field keep the legacy schedule behavior")
    func legacyEquivalence() {
        var withNil = Project.demo
        withNil.harmony = nil
        let a = OfflineRenderer.render(project: withNil, bars: 12)
        let b = OfflineRenderer.render(project: .demo, bars: 12)
        #expect(a == b)
    }

    @Test("Old project JSON (0.2.0, no harmony key) still decodes")
    func oldJSONDecodes() throws {
        let data = try JSONEncoder().encode(Project.demo)
        // Strip the harmony key if present, simulating an old file.
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object.removeValue(forKey: "harmony")
        let stripped = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Project.self, from: stripped)
        #expect(decoded.harmony == nil)
    }

    @Test("LiveEngine snapshot exposes the schedule events")
    func snapshotEvents() {
        let engine = LiveEngine(project: .demo)
        let events = engine.snapshot().scheduleEvents
        #expect(events.contains { $0.bar == 8 && $0.degreeOffset == 5 })
    }
}
