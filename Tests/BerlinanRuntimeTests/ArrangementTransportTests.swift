import Foundation
import Testing
import BerlinanEngine
@testable import BerlinanRuntime

// Phase 26 (FR-A-1): the arranger's ending stops the transport by itself,
// exactly at the stop bar, with a full flush.

@Suite("Arrangement transport", .serialized)
struct ArrangementTransportTests {

    @Test("Arranger ending stops the transport on its own")
    func arrangerAutoStop() throws {
        let midi = try MIDIService(clientName: "BerlinanArrTest",
                                   sourceName: "Berlinan Arr Test Out")
        var project = Project.demo
        project.bpm = 220                     // keep the test short
        project.transposition = .pedal
        project.arrangement = ArrangementConfig(enabled: true)

        let transport = Transport(project: project, midi: midi)
        transport.play()
        #expect(transport.isPlaying)
        // Fast-forward the whole arc: the advances all bind at the next bar,
        // so the ending's stop lands a bar or two in.
        for _ in 0..<20 { transport.enqueue(.advancePhase) }

        var waited = 0.0
        while transport.isPlaying && waited < 8.0 {
            Thread.sleep(forTimeInterval: 0.1)
            waited += 0.1
        }
        #expect(!transport.isPlaying, "the ending must stop the transport")
        #expect(midi.activeNoteCount == 0, "everything flushed at the stop")
    }
}
