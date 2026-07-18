import Testing
import Foundation
@testable import BerlinanEngine

/// Phase 35: arrangement form presets and the reprise — the bed theme
/// returns at the payoff.

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

@Suite("Form presets")
struct FormPresetTests {

    @Test("Presets carry their documented shapes")
    func presets() {
        #expect(ArrangementConfig.classicArc.enabled)
        #expect(ArrangementConfig.classicArc.reprise == true)
        #expect(ArrangementConfig.classicArc.minPeriodBars == 8)
        #expect(ArrangementConfig.slowBuild.minPeriodBars == 12)
        #expect(ArrangementConfig.slowBuild.maxPeriodBars == 24)
        #expect(ArrangementConfig.slowBuild.reprise == true)
        #expect(ArrangementConfig.ambientPlateau.ambientMode)
        #expect(ArrangementConfig.ambientPlateau.reprise != true)
    }
}

@Suite("Reprise")
struct RepriseTests {

    private func project(reprise: Bool) -> Project {
        var p = Project.demo
        p.transposition = .pedal
        var config = ArrangementConfig(enabled: true)
        config.reprise = reprise
        p.arrangement = config
        return p
    }

    /// Note-content signature (mutations keep pattern ids — compare notes).
    private func signature(_ engine: LiveEngine) -> [String] {
        engine.snapshot().voices.map { voice in
            voice.pattern.id + "|" + voice.pattern.notes
                .map { "\($0.position)/\($0.pitch.degree)/\($0.accent)/\($0.velocity)" }
                .joined(separator: ",")
        }
    }

    /// Advance bar-by-bar until the SM reports the phase; returns the tick.
    private func advance(_ engine: inout LiveEngine, to phase: ArrangementPhase,
                         from startBar: Int) -> Int {
        var barIndex = startBar
        while engine.snapshot().arrangement?.phase != phase {
            engine.enqueue(.advancePhase, atTick: Tick(barIndex) * bar)
            _ = engine.render(range: Tick(barIndex) * bar..<(Tick(barIndex + 1) * bar))
            barIndex += 1
            precondition(barIndex < 64, "phase \(phase) never reached")
        }
        return barIndex
    }

    @Test("With reprise, the payoff recalls the bed-entry theme")
    func repriseRecalls() {
        var engine = LiveEngine(project: project(reprise: true))
        let bedBar = advance(&engine, to: .bed, from: 0)
        let theme = signature(engine)
        let varBar = advance(&engine, to: .variation, from: bedBar)
        _ = advance(&engine, to: .payoff, from: varBar)
        let payoff = signature(engine)
        #expect(payoff == theme, "the theme must return")
    }

    @Test("Without reprise, the payoff keeps the evolved material")
    func noReprise() {
        var engine = LiveEngine(project: project(reprise: false))
        let bedBar = advance(&engine, to: .bed, from: 0)
        let theme = signature(engine)
        let varBar = advance(&engine, to: .variation, from: bedBar)
        _ = advance(&engine, to: .payoff, from: varBar)
        let payoff = signature(engine)
        #expect(payoff != theme,
                "variation nudges must have changed something by the payoff")
    }
}
