import Foundation
import Testing
@testable import BerlinanRuntime

/// Phase 61: the bundled midi.guide catalog and its search rule.

private func model(_ name: String) -> MIDIGuideCatalog.Model {
    MIDIGuideCatalog.Model(name: name, parameters: [
        MIDIGuideCatalog.Parameter(section: "Filter", name: "Cutoff", cc: 74,
                                   min: 0, max: 127),
    ])
}

private let fixture = MIDIGuideCatalog(manufacturers: [
    MIDIGuideCatalog.Manufacturer(name: "Arturia", models: [model("MicroFreak")]),
    MIDIGuideCatalog.Manufacturer(name: "Digitech", models: [model("Whammy")]),
    MIDIGuideCatalog.Manufacturer(name: "Elektron", models: [
        model("Analog Four"), model("Digitakt"), model("Digitone"),
    ]),
])

private func names(_ result: [MIDIGuideCatalog.Manufacturer]) -> [String: [String]] {
    Dictionary(uniqueKeysWithValues: result.map { ($0.name, $0.models.map(\.name)) })
}

@Suite("midi.guide catalog")
struct MIDIGuideCatalogTests {

    @Test("Search matches manufacturers or models; a model match narrows the models")
    func searchManufacturerOrModel() {
        #expect(names(fixture.filtered(by: "digi")) == [
            "Digitech": ["Whammy"],
            "Elektron": ["Digitakt", "Digitone"],
        ])
    }

    @Test("Empty or blank search shows everything")
    func blankSearchShowsAll() {
        #expect(fixture.filtered(by: "") == fixture.manufacturers)
        #expect(fixture.filtered(by: "   ") == fixture.manufacturers)
    }

    @Test("Search is case-insensitive and trims spaces")
    func caseInsensitive() {
        #expect(names(fixture.filtered(by: " ARTURIA ")) == ["Arturia": ["MicroFreak"]])
    }

    @Test("No match → empty")
    func noMatch() {
        #expect(fixture.filtered(by: "xyz").isEmpty)
    }

    @Test("A missing file throws; a bundle without the resource gives nil")
    func missingData() {
        let nowhere = URL(fileURLWithPath: "/nonexistent/midiguide.json")
        #expect(throws: (any Error).self) { try MIDIGuideCatalog.load(from: nowhere) }
        #expect(MIDIGuideCatalog.bundled(in: Bundle(for: BundleMarker.self)) == nil)
    }

    @Test("The bundled snapshot loads with known MicroFreak numbers")
    func realSnapshotLoads() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/MIDIGuide/midiguide.json")
        let catalog = try MIDIGuideCatalog.load(from: url)
        #expect(catalog.manufacturers.count > 100)
        let freak = catalog.manufacturers.first { $0.name == "Arturia" }?
            .models.first { $0.name == "MicroFreak" }
        let cc = Dictionary(freak?.parameters.map { ($0.name, $0.cc) } ?? [],
                            uniquingKeysWith: { first, _ in first })
        #expect(cc["Timbre"] == 12 && cc["Shape"] == 13 && cc["Cutoff"] == 23)
    }

    @Test("The snapshot offers no channel-mode messages and no fixed-value commands")
    func snapshotHasOnlyModulatableParameters() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/MIDIGuide/midiguide.json")
        let all = try MIDIGuideCatalog.load(from: url).manufacturers
            .flatMap(\.models).flatMap(\.parameters)
        // CC 120–127 = All Notes Off, Local Control, Omni/Mono/Poly …: an LFO
        // on them would cut notes or switch modes; min == max = a command
        // (e.g. "Store"), not something to sweep.
        #expect(!all.contains { $0.cc >= 120 })
        #expect(!all.contains { $0.min == $0.max })
    }
}

private final class BundleMarker {}
