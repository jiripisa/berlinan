import Observation
import BerlinanRuntime

/// App-lifetime services. Created at launch so the "Berlinan Out" virtual
/// source exists (and is visible to DAWs) for the whole app session —
/// pulled forward from phase 13 so port visibility can be verified early.
@MainActor
@Observable
final class AppServices {

    let midi: MIDIService?
    let midiStatus: String

    init() {
        do {
            midi = try MIDIService(clientName: "Berlinan", sourceName: "Berlinan Out")
            midiStatus = "Berlinan Out — port up"
        } catch {
            midi = nil
            midiStatus = "MIDI unavailable: \(error)"
        }
    }
}
