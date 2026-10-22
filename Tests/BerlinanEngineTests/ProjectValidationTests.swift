import Testing
import Foundation
@testable import BerlinanEngine

/// Phase 45 (audit #1): a decodable but invalid document must be rejected
/// with a message, never crash the app later.

@Suite("Project validation")
struct ProjectValidationTests {

    private func json(_ project: Project) throws -> [String: Any] {
        let data = try JSONEncoder().encode(project)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    /// What the app and the CLI do with a document: decode, then validate.
    private func load(_ data: Data) throws -> Project {
        let project = try JSONDecoder().decode(Project.self, from: data)
        try project.validate()
        return project
    }

    @Test("Built-in templates are valid")
    func builtInsValid() throws {
        for project in [Project.demo, .fullEnsemble, .ambientDrift] {
            try project.validate()
            _ = try load(JSONEncoder().encode(project))
        }
    }

    @Test("Two voices with the same id are rejected")
    func duplicateVoiceIDs() throws {
        var project = Project.demo
        project.voices[1].id = project.voices[0].id
        #expect(throws: Project.ValidationError.self) {
            try load(JSONEncoder().encode(project))
        }
    }

    @Test("A meter with beatUnit 0 is rejected at decode time")
    func badMeter() throws {
        var object = try json(.demo)
        object["meter"] = ["beatsPerBar": 4, "beatUnit": 0, "grouping": []]
        #expect(throws: (any Error).self) {
            try load(data(object))
        }
    }

    @Test("Tempo outside 40–220 BPM is rejected")
    func badTempo() throws {
        var object = try json(.demo)
        object["bpm"] = 0
        #expect(throws: Project.ValidationError.self) {
            try load(data(object))
        }
    }

    @Test("MIDI channels above 16 are rejected")
    func badChannel() throws {
        var project = Project.demo
        project.voices[0].channel = 16
        #expect(throws: Project.ValidationError.self) {
            try load(JSONEncoder().encode(project))
        }
    }
}
