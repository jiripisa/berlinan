import Testing
import Foundation
@testable import BerlinanEngine

/// Phase 32: the horizon surface — the snapshot narrates what is about to
/// happen (pending binds, arranger countdown, voice activation states).

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

@Suite("Horizon — upcoming events")
struct UpcomingEventTests {

    private func soloProject() -> Project {
        var p = Project.demo
        p.voices = [p.voices[0]]
        p.transposition = .pedal
        return p
    }

    @Test("Pending binds appear with their bar and kind, then clear")
    func pendingBinds() {
        var engine = LiveEngine(project: soloProject())
        var key = Key.default
        key.root = 9                               // A minor
        engine.enqueue(.setKey(key), atTick: beat)
        engine.enqueue(.setDensity(0.4), atTick: beat)
        let upcoming = engine.snapshot().upcomingEvents
        #expect(upcoming.count == 2)
        #expect(upcoming.allSatisfy { $0.tick == bar }, "mid-bar → next bar")
        #expect(upcoming.contains { $0.kind == .key })
        #expect(upcoming.contains { $0.kind == .density })
        _ = engine.render(range: 0..<(2 * bar))
        #expect(engine.snapshot().upcomingEvents.isEmpty,
                "consumed binds must leave the horizon")
    }

    @Test("Events are sorted by bind tick")
    func sorted() {
        var engine = LiveEngine(project: soloProject())
        engine.enqueue(.setDensity(0.5), atTick: 3 * bar)
        engine.enqueue(.spendTension(voiceID: "bedPluck1"), atTick: beat)
        let ticks = engine.snapshot().upcomingEvents.map(\.tick)
        #expect(ticks == ticks.sorted())
        #expect(engine.snapshot().upcomingEvents.first?.kind == .tension)
    }
}

@Suite("Horizon — arranger countdown and voice states")
struct HorizonArrangerTests {

    private func arrangedProject() -> Project {
        var p = Project.demo
        p.transposition = .pedal
        p.arrangement = ArrangementConfig(enabled: true)
        return p
    }

    @Test("barsUntilChange counts down by one per bar")
    func countdown() {
        var engine = LiveEngine(project: arrangedProject())
        _ = engine.render(range: 0..<bar)
        let first = try! #require(engine.snapshot().arrangement).barsUntilChange
        #expect(first > 0)
        _ = engine.render(range: bar..<(2 * bar))
        let second = try! #require(engine.snapshot().arrangement).barsUntilChange
        #expect(second == first - 1)
    }

    @Test("Voice snapshots expose the arranger's activation state")
    func voiceStates() {
        var engine = LiveEngine(project: arrangedProject())
        _ = engine.render(range: 0..<bar)
        let early = engine.snapshot()
        #expect(early.voices.first { $0.id == "bedPluck1" }?.active == true)
        #expect(early.voices.first { $0.id == "bedPluck2" }?.active == false,
                "held-back voices must say so — not just fall silent")
        _ = engine.render(range: bar..<(40 * bar))
        let later = engine.snapshot()
        #expect(later.voices.allSatisfy { $0.active },
                "everyone plays once the build completes")
    }

    @Test("Per-voice pending requests surface with their bind tick")
    func pendingRequests() {
        var engine = LiveEngine(project: Project.demo)
        engine.enqueue(.blankCycle(voiceID: "bass"), atTick: beat)
        let voice = engine.snapshot().voices.first { $0.id == "bass" }
        #expect(voice?.pendingRequest == .blank(beat))
        _ = engine.render(range: 0..<(3 * bar))
        let after = engine.snapshot().voices.first { $0.id == "bass" }
        #expect(after?.pendingRequest == nil, "consumed requests clear")
    }
}
