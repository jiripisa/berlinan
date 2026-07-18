import Testing
import Foundation
@testable import BerlinanEngine

/// Phase 36: built-in project templates.

private let bar: Tick = 4 * Time.ppqn

@Suite("Templates")
struct TemplateTests {

    @Test("Full ensemble: the whole 1.1 palette, renderable")
    func fullEnsemble() {
        let p = Project.fullEnsemble
        #expect(p.voices.count == 6)
        let roles = Set(p.voices.map(\.role))
        #expect(roles.isSuperset(of: [.pad, .lead, .rhythm, .bass]))
        #expect(p.voices.contains { $0.generator == .chordLayer(periodBars: 7) })
        #expect(p.voices.contains { $0.generator == .heartbeat })
        var engine = LiveEngine(project: p)
        #expect(!engine.render(range: 0..<(8 * bar)).isEmpty)
    }

    @Test("Ambient drift: drone-led, ambient arrangement, scenes mapped")
    func ambientDrift() {
        let p = Project.ambientDrift
        #expect(p.voices.contains { $0.role == .drone })
        #expect(ArrangementSM.deriveBuildOrder(from: p.voices).first
                == p.voices.first { $0.role == .drone }?.id)
        #expect(p.arrangement?.ambientMode == true)
        #expect(p.arrangement?.enabled == true)
        #expect((p.ccScenes ?? []).count >= 2)
        #expect(p.sceneByPhase?.isEmpty == false)
        var engine = LiveEngine(project: p)
        #expect(!engine.render(range: 0..<(8 * bar)).isEmpty)
    }
}
