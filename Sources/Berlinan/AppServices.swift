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
        } catch {
            self.midi = nil
            self.midiStatus = "MIDI unavailable: \(error)"
            self.transport = nil
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
