import Testing
@testable import BerlinanEngine

/// Phase 45 (audit #5): the CLI's SMF export must play what the live engine
/// plays — with the arranger on, voices enter over time, the piece ends.

@Suite("Offline export with the arranger")
struct OfflineArrangementTests {

    private func sorted(_ notes: [RenderedNote]) -> [RenderedNote] {
        notes.sorted { ($0.at, $0.voiceID, $0.midiNote) < ($1.at, $1.voiceID, $1.midiNote) }
    }

    @Test("Arranged project: exported tracks hold exactly the live-rendered notes")
    func arrangedParity() {
        var project = Project.demo
        project.arrangement = ArrangementConfig(enabled: true)
        let exported = OfflineRenderer.tracks(project: project, bars: 24).flatMap(\.notes)
        let live = OfflineRenderer.renderNotes(project: project, bars: 24)
        #expect(sorted(exported) == sorted(live))
    }

    @Test("Unarranged project: tracks unchanged (per-voice path)")
    func unarrangedParity() {
        let exported = OfflineRenderer.tracks(project: .demo, bars: 16).flatMap(\.notes)
        #expect(sorted(exported) == sorted(OfflineRenderer.renderNotes(project: .demo, bars: 16)))
    }
}
