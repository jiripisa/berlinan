import Observation
import BerlinanEngine
import BerlinanRuntime

/// App-lifetime services. Created at launch so the "Berlinan Out" virtual
/// source exists (and is visible to DAWs) for the whole app session.
@MainActor
@Observable
final class AppServices {

    let midi: MIDIService?
    let midiStatus: String
    private(set) var transport: Transport?
    /// The working project (built-in demo until documents arrive, phase 19).
    private(set) var project: Project = .demo

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

    /// Change the harmony mode (FR-H-4/5/6). Only while stopped — the
    /// transport is rebuilt over the updated project (M3 limitation,
    /// runtime switching arrives with M4 polish).
    func setHarmonyMode(_ mode: HarmonyModeConfig?) {
        guard transport?.isPlaying != true else { return }
        project.harmony = mode
        if let midi {
            transport = Transport(project: project, midi: midi)
        }
    }
}
