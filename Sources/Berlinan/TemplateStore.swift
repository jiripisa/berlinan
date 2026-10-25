import Foundation
import BerlinanEngine

/// Template gallery (phase 36): built-in starting points plus the user's
/// own saved setups. Instantiating a template always gets a fresh master
/// seed (FR-UX-6 — a template is a setup, not a recording).
enum TemplateStore {

    /// The key the app and the built-in templates start in (user request,
    /// phase 51). The engine's `Key.default` stays C minor — its golden
    /// masters are built on it.
    static let defaultKey = Key(root: 9, scale: .preset(.naturalMinor))   // A minor

    static let builtIns: [(name: String, project: Project)] = [
        ("Demo trio", inDefaultKey(.demo)),
        ("Full ensemble", inDefaultKey(.fullEnsemble)),
        ("Ambient drift", inDefaultKey(.ambientDrift)),
    ]

    private static func inDefaultKey(_ project: Project) -> Project {
        var project = project
        project.key = defaultKey
        return project
    }

    static func userTemplatesDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask)[0]
            .appendingPathComponent("Berlinan/templates")
    }

    /// User templates, sorted by name. Unreadable or invalid files are skipped.
    static func userTemplates() -> [(name: String, project: Project)] {
        let directory = userTemplatesDirectory()
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else { return [] }
        return urls
            .filter { $0.pathExtension == "berlinan" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let project = try? JSONDecoder().decode(Project.self,
                                                              from: data),
                      (try? project.validate()) != nil
                else { return nil }
                return (url.deletingPathExtension().lastPathComponent, project)
            }
            .sorted { $0.name < $1.name }
    }
}
