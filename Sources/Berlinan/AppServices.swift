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
    let transport: Transport?
    /// M2 interim: the built-in demo project until documents arrive (M3).
    let project: Project = .demo

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
}
