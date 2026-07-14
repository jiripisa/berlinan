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
    private(set) var isPlaying = false

    init() {
        do {
            let midi = try MIDIService(clientName: "Berlinan", sourceName: "Berlinan Out")
            self.midi = midi
            self.midiStatus = "Berlinan Out — port up"
            // M2 interim: the transport plays the built-in demo project until
            // documents arrive (phase 13+).
            self.transport = Transport(project: .demo, midi: midi)
        } catch {
            self.midi = nil
            self.midiStatus = "MIDI unavailable: \(error)"
            self.transport = nil
        }
    }

    func togglePlayback() {
        guard let transport else { return }
        if transport.isPlaying {
            transport.stop()
        } else {
            transport.play()
        }
        isPlaying = transport.isPlaying
    }
}
