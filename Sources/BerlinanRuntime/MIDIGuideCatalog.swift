import Foundation

/// The midi.guide CC database (phase 61, FR-MOD-9): manufacturer › model ›
/// parameter with its CC number. Bundled as `MIDIGuide/midiguide.json`
/// (CC BY-SA 4.0, refreshed by `scripts/update_midiguide.py`).
public struct MIDIGuideCatalog: Sendable {

    public struct Parameter: Codable, Hashable, Sendable {
        /// The instrument's section, e.g. "Filter"; "General" when unnamed.
        public var section: String
        public var name: String
        public var cc: UInt8
        /// The parameter's CC value range (0–127 when the database is silent).
        public var min: UInt8
        public var max: UInt8

        public init(section: String, name: String, cc: UInt8, min: UInt8, max: UInt8) {
            self.section = section
            self.name = name
            self.cc = cc
            self.min = min
            self.max = max
        }
    }

    public struct Model: Codable, Hashable, Sendable {
        public var name: String
        public var parameters: [Parameter]

        public init(name: String, parameters: [Parameter]) {
            self.name = name
            self.parameters = parameters
        }
    }

    public struct Manufacturer: Codable, Hashable, Sendable {
        public var name: String
        public var models: [Model]

        public init(name: String, models: [Model]) {
            self.name = name
            self.models = models
        }
    }

    public let manufacturers: [Manufacturer]

    public init(manufacturers: [Manufacturer]) {
        self.manufacturers = manufacturers
    }

    public static func load(from url: URL) throws -> MIDIGuideCatalog {
        let data = try Data(contentsOf: url)
        return MIDIGuideCatalog(
            manufacturers: try JSONDecoder().decode([Manufacturer].self, from: data))
    }

    /// The copy in the app bundle; nil when it is missing or unreadable.
    public static func bundled(in bundle: Bundle = .main) -> MIDIGuideCatalog? {
        guard let url = bundle.url(forResource: "midiguide", withExtension: "json",
                                   subdirectory: "MIDIGuide")
        else { return nil }
        return try? load(from: url)
    }

    /// Search by part of a name: a manufacturer whose name matches keeps all
    /// its models; otherwise it stays with just the models whose names match.
    /// Parameter names are not searched. Blank → everything.
    public func filtered(by query: String) -> [Manufacturer] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return manufacturers }
        return manufacturers.compactMap { manufacturer in
            if manufacturer.name.localizedCaseInsensitiveContains(needle) {
                return manufacturer
            }
            let models = manufacturer.models.filter {
                $0.name.localizedCaseInsensitiveContains(needle)
            }
            return models.isEmpty ? nil : Manufacturer(name: manufacturer.name, models: models)
        }
    }
}
