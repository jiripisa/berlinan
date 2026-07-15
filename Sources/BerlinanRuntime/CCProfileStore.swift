import Foundation

/// Named CC profiles (FR-MOD-5, global half): built-ins from the manual plus
/// user JSON files in Application Support/Berlinan/profiles/.
public struct CCProfile: Codable, Equatable, Sendable {
    public var name: String
    /// Named targets → controller numbers, e.g. "filter": 74.
    public var map: [String: UInt8]

    public init(name: String, map: [String: UInt8]) {
        self.name = name
        self.map = map
    }
}

public struct CCProfileStore: Sendable {

    public let profiles: [CCProfile]

    /// Built-ins (M §13.4 for the Microfreak mapping) + user files from the
    /// directory (nil = the default Application Support location).
    public init(directory: URL?) {
        var loaded: [CCProfile] = [
            CCProfile(name: "Generic", map: ["filter": 74, "resonance": 71]),
            CCProfile(name: "Microfreak", map: ["shape": 12, "timbre": 13,
                                                "filter": 23]),
        ]
        let dir = directory ?? Self.defaultDirectory()
        if let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil) {
            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let profile = try? JSONDecoder().decode(CCProfile.self, from: data) {
                    loaded.append(profile)
                }
            }
        }
        self.profiles = loaded
    }

    public static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask)[0]
            .appendingPathComponent("Berlinan/profiles")
    }
}
