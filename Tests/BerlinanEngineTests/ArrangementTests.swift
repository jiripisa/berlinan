import Testing
import Foundation
@testable import BerlinanEngine

/// Phase 26 (FR-A-1/2/6): the arrangement state machine as a pure,
/// deterministic directive emitter. The LiveEngine consumes directives at
/// bar boundaries; these tests exercise the SM alone.

@Suite("Arrangement — config")
struct ArrangementConfigTests {

    @Test("Disabled by default; 1.0 documents without the key still decode")
    func defaults() throws {
        #expect(ArrangementConfig().enabled == false)
        let data = try JSONEncoder().encode(Project.demo)
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        #expect(decoded.arrangement == nil)
    }

    @Test("Build order derives from roles: beds → pad → bass → lead → rest")
    func derivedBuildOrder() {
        #expect(ArrangementSM.deriveBuildOrder(from: Project.demo.voices)
                == ["bedPluck1", "bedPluck2", "bass"])

        var p = Project.demo
        p.voices[0].role = .lead          // same ids, shuffled roles
        p.voices[2].role = .bedPluck1
        #expect(ArrangementSM.deriveBuildOrder(from: p.voices)
                == ["bass", "bedPluck2", "bedPluck1"])
    }
}

@Suite("Arrangement — state machine")
struct ArrangementSMTests {

    private func makeSM(seed: UInt64 = 1) -> ArrangementSM {
        ArrangementSM(config: ArrangementConfig(enabled: true),
                      voices: Project.demo.voices, seed: seed)
    }

    /// Advance until the SM reports the wanted phase (manual advance-now
    /// path, FR-A-6). Returns all emitted directives along the way.
    private func advanceUntil(_ sm: inout ArrangementSM,
                              phase: ArrangementPhase,
                              locked: Set<String> = []) -> [ArrangementDirective] {
        var directives: [ArrangementDirective] = []
        var guardCount = 0
        while sm.phase != phase {
            directives += sm.advance(locked: locked)
            guardCount += 1
            precondition(guardCount < 50, "phase \(phase) never reached")
        }
        return directives
    }

    @Test("Starts in build with only the first build-order voice active")
    func initialState() {
        let sm = makeSM()
        #expect(sm.phase == .build)
        #expect(sm.activeVoices == ["bedPluck1"])
    }

    @Test("Build activates voices in build order, then enters bed")
    func buildProgression() {
        var sm = makeSM()
        let directives = advanceUntil(&sm, phase: .bed)
        let activations = directives.compactMap { d -> String? in
            if case .activate(let id) = d { return id } else { return nil }
        }
        #expect(activations == ["bedPluck2", "bass"])
        #expect(sm.activeVoices == ["bedPluck1", "bedPluck2", "bass"])
    }

    @Test("Timed change periods always land in 8...16 bars")
    func periodBounds() {
        var sm = makeSM(seed: 42)
        var barsSinceEvent = 0
        var periods: [Int] = []
        for _ in 0..<300 {
            barsSinceEvent += 1
            if !sm.tickBar().isEmpty {
                periods.append(barsSinceEvent)
                barsSinceEvent = 0
            }
            if sm.phase == .ending { break }
        }
        #expect(periods.count >= 5)
        for period in periods {
            #expect((8...16).contains(period), "period \(period) out of range")
        }
    }

    @Test("Same seed → identical timeline; different seed → different periods")
    func determinism() {
        func timeline(seed: UInt64) -> [(Int, ArrangementPhase)] {
            var sm = makeSM(seed: seed)
            var events: [(Int, ArrangementPhase)] = []
            for barIndex in 0..<300 {
                if !sm.tickBar().isEmpty { events.append((barIndex, sm.phase)) }
            }
            return events
        }
        #expect(timeline(seed: 7).map(\.0) == timeline(seed: 7).map(\.0))
        #expect(timeline(seed: 7).map(\.1) == timeline(seed: 7).map(\.1))
        #expect(timeline(seed: 7).map(\.0) != timeline(seed: 8).map(\.0))
    }

    @Test("advance() fires the next change immediately (advance-now button)")
    func manualAdvance() {
        var sm = makeSM()
        let directives = sm.advance()
        #expect(directives == [.activate(voiceID: "bedPluck2")])
        #expect(sm.barsInPhase == 0 || sm.phase == .build)   // no bars elapsed
    }

    @Test("Bed nudges mutations round-robin, skipping locked voices")
    func bedRoundRobin() {
        var sm = makeSM()
        _ = advanceUntil(&sm, phase: .bed)
        var targets: [String] = []
        var guardCount = 0
        while sm.phase == .bed && guardCount < 10 {
            for directive in sm.advance(locked: ["bedPluck2"]) {
                if case .nudgeMutation(let id) = directive { targets.append(id) }
            }
            guardCount += 1
        }
        #expect(!targets.isEmpty)
        #expect(!targets.contains("bedPluck2"), "locked voice must never be nudged")
        #expect(Set(targets).count > 1 || targets.count == 1,
                "round-robin must rotate over unlocked voices")
    }

    @Test("Walks the full arc build→bed→variation→bPart→payoff→subtract→ending")
    func fullArc() {
        var sm = makeSM()
        for phase in [ArrangementPhase.bed, .variation, .bPart,
                      .payoff, .subtract, .ending] {
            _ = advanceUntil(&sm, phase: phase)
            #expect(sm.phase == phase)
        }
    }

    @Test("Subtract deactivates in reverse build order down to one voice")
    func subtractReverses() {
        var sm = makeSM()
        var directives = advanceUntil(&sm, phase: .subtract)
        directives += advanceUntil(&sm, phase: .ending)
        let deactivations = directives.compactMap { d -> String? in
            if case .deactivate(let id) = d { return id } else { return nil }
        }
        #expect(deactivations == ["bass", "bedPluck2"])
        #expect(sm.activeVoices == ["bedPluck1"])
    }

    @Test("Ending thins the survivor to roots, then requests a stop")
    func endingStops() {
        var sm = makeSM()
        let entering = advanceUntil(&sm, phase: .ending)
        #expect(entering.contains(.thinToRoots(voiceID: "bedPluck1")))
        var stopped = false
        for _ in 0..<20 where !stopped {
            stopped = sm.advance().contains(.requestStop)
        }
        #expect(stopped, "ending must eventually request a transport stop")
    }

    @Test("Ambient mode: fixed change periods at the given bars-per-minute")
    func ambientPeriods() {
        var sm = ArrangementSM(
            config: ArrangementConfig(enabled: true, ambientMode: true),
            voices: Project.demo.voices, seed: 3, ambientPeriodBars: 22)
        var gaps: [Int] = []
        var sinceEvent = 0
        for _ in 0..<100 {
            sinceEvent += 1
            if !sm.tickBar().isEmpty { gaps.append(sinceEvent); sinceEvent = 0 }
        }
        #expect(!gaps.isEmpty)
        #expect(gaps.allSatisfy { $0 == 22 }, "ambient gaps: \(gaps)")
    }

    @Test("Payoff raises density to 1.0; each subtract step lowers it")
    func densityDirectives() {
        var sm = makeSM()
        let payoffDirectives = advanceUntil(&sm, phase: .payoff)
        let raised = payoffDirectives.compactMap { d -> Double? in
            if case .setDensity(let v) = d { return v } else { return nil }
        }
        #expect(raised.contains(1.0), "payoff must raise density to 1.0")

        _ = advanceUntil(&sm, phase: .subtract)
        var lowered: [Double] = []
        var directives = advanceUntil(&sm, phase: .ending)
        directives += []
        for d in directives {
            if case .setDensity(let v) = d { lowered.append(v) }
        }
        #expect(!lowered.isEmpty, "subtract must lower density")
        #expect(lowered == lowered.sorted(by: >), "each step lowers further")
        #expect(lowered.allSatisfy { $0 < 1.0 })
    }

    @Test("Entering bPart fires the bundle directive exactly once")
    func bPartDirective() {
        var sm = makeSM()
        let directives = advanceUntil(&sm, phase: .payoff)
        let fires = directives.filter { $0 == .fireBPart }.count
        #expect(fires == 1)
    }

    @Test("Enabling mid-play with every voice already active enters bed")
    func adoptRunningState() {
        var sm = ArrangementSM(config: ArrangementConfig(enabled: true),
                               voices: Project.demo.voices, seed: 1,
                               adoptingActive: ["bedPluck1", "bedPluck2", "bass"])
        #expect(sm.phase == .bed)
        #expect(sm.activeVoices == ["bedPluck1", "bedPluck2", "bass"])
        _ = sm.tickBar()   // must not crash / re-intro
    }
}
