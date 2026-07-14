import AppKit
import Observation
import UniformTypeIdentifiers
import BerlinanEngine
import BerlinanRuntime

extension UTType {
    /// `.berlinan` — pretty-printed project JSON (spec §10; the package
    /// format arrives with capture persistence, deviation noted in phase 19).
    static let berlinanProject = UTType(exportedAs: "io.jp4.berlinan.project")
}

/// App-lifetime services. Created at launch so the "Berlinan Out" virtual
/// source exists (and is visible to DAWs) for the whole app session.
@MainActor
@Observable
final class AppServices {

    let midi: MIDIService?
    let midiStatus: String
    private(set) var transport: Transport?
    private(set) var project: Project = .demo
    /// Set when the project changed while playing — the running transport
    /// keeps its materialized state; rebuilt on the next stop.
    private var transportStale = false

    init() {
        do {
            let midi = try MIDIService(clientName: "Berlinan", sourceName: "Berlinan Out")
            self.midi = midi
            self.midiStatus = "Berlinan Out"
            self.transport = Transport(project: project, midi: midi)
        } catch {
            self.midi = nil
            self.midiStatus = "MIDI unavailable: \(error)"
            self.transport = nil
        }
    }

    // MARK: - Project mutations

    private func rebuildTransport() {
        guard let midi else { return }
        transport = Transport(project: project, midi: midi)
        transportStale = false
    }

    func rebuildTransportIfStale() {
        guard transportStale, transport?.isPlaying != true else { return }
        rebuildTransport()
    }

    /// Replace the whole project (settings sheet, document open). Stopped only.
    func applyProject(_ newProject: Project) {
        guard transport?.isPlaying != true else { return }
        project = newProject
        rebuildTransport()
    }

    /// Change the harmony mode (FR-H-4/5/6). Only while stopped.
    func setHarmonyMode(_ mode: HarmonyModeConfig?) {
        guard transport?.isPlaying != true else { return }
        project.harmony = mode
        rebuildTransport()
    }

    /// Persist a hand-edited pattern (FR-P-7). While playing, the live
    /// `replacePattern` action (enqueued by the caller) covers the running
    /// engine; the rebuilt-on-stop transport picks the override up from here.
    func updateVoiceOverride(_ voiceID: String, pattern: BerlinanEngine.Pattern?) {
        guard let idx = project.voices.firstIndex(where: { $0.id == voiceID }) else { return }
        project.voices[idx].overridePattern = pattern
        if transport?.isPlaying == true {
            transportStale = true
        } else {
            rebuildTransport()
        }
    }

    // MARK: - Documents (spec §10, M3 subset)

    /// File ▸ Open: returns the loaded project so the caller can restore
    /// snapshot slots. Stopped only.
    @discardableResult
    func openDocument() -> Project? {
        guard transport?.isPlaying != true else { return nil }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.berlinanProject, .json]
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode(Project.self, from: data) else {
            return nil
        }
        applyProject(loaded)
        return loaded
    }

    /// File ▸ Save As: embeds the current snapshot slots.
    func saveDocument(snapshots: [LiveEngine.StateSnapshot?]) {
        var toSave = project
        toSave.snapshots = snapshots
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.berlinanProject]
        panel.nameFieldStringValue = "untitled.berlinan"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? (try? encoder.encode(toSave))?.write(to: url)
    }
}
