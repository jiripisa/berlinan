import Testing
import Foundation
@testable import BerlinanEngine

/// Phase 40 (FR-UX-7): the UI names voices by role, never by internal id.

private let beat: Tick = Time.ppqn

@Suite("Voice names")
struct VoiceNameTests {

    @Test("Every role has a musician-facing name")
    func roleNames() {
        let names = VoiceRole.allCases.map(\.displayName)
        #expect(names == ["Pluck 1", "Pluck 2", "Bass", "Pad", "Lead",
                          "Drone", "Heartbeat", "Aux"])
    }

    @Test("Templates label voices by role, not by id")
    func templateLabels() {
        let voices = Project.fullEnsemble.voices.map { ($0.id, $0.role) }
        let labels = VoiceLabels.make(voices)
        #expect(labels["bedPluck1"] == "Pluck 1")
        #expect(labels["bass"] == "Bass")
        #expect(labels["kick"] == "Heartbeat", "the id is not the name")
        #expect(Set(labels.values).count == voices.count, "labels never collide")
    }

    @Test("A role used twice is numbered in document order; singles are not")
    func duplicateRoles() {
        let labels = VoiceLabels.make([("a", .lead), ("b", .bass), ("c", .lead)])
        #expect(labels == ["a": "Lead 1", "b": "Bass", "c": "Lead 2"])
    }

    @Test("Horizon events name their voice in a structured field")
    func horizonVoiceIDs() {
        var engine = LiveEngine(project: Project.fullEnsemble)
        engine.enqueue(.setVoiceActive(voiceID: "bass", on: false), atTick: beat)
        engine.enqueue(.promoteToLead(voiceID: "bedPluck1"), atTick: beat)
        engine.enqueue(.spendTension(voiceID: "bedPluck2"), atTick: beat)
        let events = engine.snapshot().upcomingEvents
        let voiceOff = events.first { $0.kind == .voiceActive }
        #expect(voiceOff?.voiceID == "bass")
        #expect(voiceOff?.detail == "off")
        #expect(events.first { $0.kind == .promoteToLead }?.voiceID == "bedPluck1")
        #expect(events.first { $0.kind == .tension }?.voiceID == "bedPluck2")
    }
}
