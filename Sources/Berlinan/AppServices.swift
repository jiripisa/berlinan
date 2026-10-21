import AppKit
import CoreMIDI
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

    /// Controller triggers land here on the main actor (FR-IO-10);
    /// UIState registers itself.
    var onControlTrigger: ((ControlTrigger) -> Void)?

    init() {
        // Seed freshness (FR-UX-6, phase 20b): every app session starts the
        // built-in project in a NEW musical universe. Saved documents keep
        // their stored seed — reproducibility on demand, not by accident.
        var fresh = Project.demo
        fresh.masterSeed = UInt64.random(in: UInt64.min...UInt64.max)
        self.project = fresh

        do {
            let midi = try MIDIService(clientName: "Berlinan", sourceName: "Berlinan Out")
            self.midi = midi
            self.midiStatus = "Berlinan Out"
            self.transport = Transport(project: fresh, midi: midi)
            // MIDI learn input (FR-IO-10): controllers target this port.
            midi.createControlInput(named: "Berlinan Control") { [weak self] trigger in
                Task { @MainActor in self?.onControlTrigger?(trigger) }
            }
            // Output choice (phase 44) survives relaunches — and unplugging:
            // the device is found again by its unique ID.
            if let id = UserDefaults.standard.object(forKey: Self.outputIDKey) as? Int {
                midi.setOutput(MIDIUniqueID(id))
                outputName = UserDefaults.standard.string(forKey: Self.outputNameKey)
                    ?? outputName
            }
        } catch {
            self.midi = nil
            self.midiStatus = "MIDI unavailable: \(error)"
            self.transport = nil
        }
    }

    // MARK: - MIDI output (phase 44, FR-IO-1)

    private static let outputIDKey = "midiOutputDestinationID"
    private static let outputNameKey = "midiOutputDestinationName"

    /// Where the notes go: the virtual source or the chosen device's name.
    private(set) var outputName = "Berlinan Out"

    var midiDestinations: [MIDIService.Destination] { midi?.destinations() ?? [] }

    var midiOutputID: MIDIUniqueID? { midi?.outputDestinationID }

    /// nil = back to the virtual source. Works while playing: what still
    /// sounds on the previous output is silenced first.
    func setMIDIOutput(_ destination: MIDIService.Destination?) {
        guard let midi else { return }
        midi.setOutput(destination?.uniqueID)
        outputName = destination?.name ?? "Berlinan Out"
        let defaults = UserDefaults.standard
        if let destination {
            defaults.set(Int(destination.uniqueID), forKey: Self.outputIDKey)
            defaults.set(destination.name, forKey: Self.outputNameKey)
        } else {
            defaults.removeObject(forKey: Self.outputIDKey)
            defaults.removeObject(forKey: Self.outputNameKey)
        }
    }

    /// Apply a CC profile to a voice (FR-MOD-5).
    func updateVoiceCCMap(_ voiceID: String, map: [String: UInt8]) {
        guard let idx = project.voices.firstIndex(where: { $0.id == voiceID }) else { return }
        project.voices[idx].ccMap = map
        if transport?.isPlaying == true {
            transportStale = true
        } else {
            rebuildTransport()
        }
    }

    /// Arrangement autopilot toggle (FR-A-6). Playing → live action at the
    /// next bar (adopts the running ensemble); stopped → project config +
    /// transport rebuild (play starts in Intro/Build).
    func setArrangerEnabled(_ on: Bool) {
        var config = project.arrangement ?? ArrangementConfig()
        config.enabled = on
        project.arrangement = config
        if transport?.isPlaying == true {
            transport?.enqueue(.setArrangementEnabled(on))
            transportStale = true
        } else {
            rebuildTransport()
        }
    }

    /// Density macro (FR-A-3): live → bar-quantized action; stopped →
    /// project value + rebuild.
    func setDensity(_ value: Double) {
        let clamped = max(0, min(1, value))
        project.density = clamped
        if transport?.isPlaying == true {
            transport?.enqueue(.setDensity(clamped))
            transportStale = true
        } else {
            rebuildTransport()
        }
    }

    /// Alternating phrase scheduler (FR-MEL-3): live → bar-quantized
    /// action; stopped → project value + rebuild.
    func setAlternating(_ config: AlternatingConfig?) {
        project.alternating = config
        if transport?.isPlaying == true {
            transport?.enqueue(.setAlternating(config))
            transportStale = true
        } else {
            rebuildTransport()
        }
    }

    /// Arrangement form preset (phase 35). Stopped only.
    func setArrangerForm(_ config: ArrangementConfig) {
        guard transport?.isPlaying != true else { return }
        project.arrangement = config
        rebuildTransport()
    }

    /// Ambient mode (FR-A-4). Stopped only — it rescales legitimization at
    /// materialize time.
    func setAmbientMode(_ on: Bool) {
        guard transport?.isPlaying != true else { return }
        var config = project.arrangement ?? ArrangementConfig()
        config.ambientMode = on
        project.arrangement = config
        rebuildTransport()
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

    /// Instantiate a template (phase 36): fresh seed, fresh universe.
    /// Stopped → rebuild; playing → it takes over at the next bar (phase 42).
    func applyTemplate(_ template: Project) {
        var fresh = template
        fresh.masterSeed = UInt64.random(in: UInt64.min...UInt64.max)
        if transport?.isPlaying == true {
            project = fresh
            transportStale = true                 // next stop rebuilds on the template
            transport?.loadProject(fresh)
        } else {
            applyProject(fresh)
        }
    }

    /// Save the current setup into the templates folder (phase 36).
    func saveAsTemplate() {
        let directory = TemplateStore.userTemplatesDirectory()
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.berlinanProject]
        panel.directoryURL = directory
        panel.nameFieldStringValue = "my-template.berlinan"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? (try? encoder.encode(project))?.write(to: url)
    }

    /// Runtime key/tempo changes (FR-GS-5) — usable while playing, both
    /// bar-quantized (key in the engine, tempo in the transport clock).
    func applyLiveMusicalChanges(key: Key?, bpm: Double?) {
        if let bpm {
            project.bpm = bpm
            transport?.setTempo(bpm)
            transportStale = true
        }
        if let key {
            project.key = key
            transport?.enqueue(.setKey(key))
            transportStale = true
        }
    }

    /// 🎲 New Seed (FR-UX-6): a whole new musical universe from the same
    /// configuration. Stopped → rebuild; playing → live swap at the next bar
    /// (a fresh engine's state recalled through the phase-18 machinery).
    func reseed() {
        var newProject = project
        newProject.masterSeed = UInt64.random(in: UInt64.min...UInt64.max)
        if transport?.isPlaying == true {
            let freshState = LiveEngine(project: newProject).captureState()
            project = newProject
            transportStale = true                 // next stop rebuilds on the new seed
            transport?.enqueue(.recallSnapshot(freshState))
        } else {
            applyProject(newProject)
        }
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

    /// Persist a MIDI-delay toggle (FR-MOD-7); the live engine action is
    /// enqueued by the caller while playing.
    func updateVoiceMIDIDelay(_ voiceID: String, enabled: Bool) {
        guard let idx = project.voices.firstIndex(where: { $0.id == voiceID }) else { return }
        var config = project.voices[idx].midiDelay ?? MIDIDelayConfig(
            division: DelayHint.compute(role: project.voices[idx].role,
                                        bpm: project.bpm).division)
        config.enabled = enabled
        project.voices[idx].midiDelay = config
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
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let loaded: Project
        do {
            let data = try Data(contentsOf: url)
            loaded = try JSONDecoder().decode(Project.self, from: data)
            try loaded.validate()
        } catch {
            // Invalid documents never reach the engine; the current project stays.
            let alert = NSAlert()
            alert.messageText = "“\(url.lastPathComponent)” can’t be opened"
            alert.informativeText = (error as? Project.ValidationError)?.description
                ?? "The file is not a valid Berlinan project."
            alert.runModal()
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
