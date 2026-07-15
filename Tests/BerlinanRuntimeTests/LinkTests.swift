import Foundation
import Testing
import BerlinanEngine
@testable import BerlinanRuntime

// MARK: - LinkService (FR-IO-5)
//
// All tests run with Link DISABLED — the session state is fully functional
// locally (tempo, beat grid) without opening network sockets, so the suite
// stays deterministic and never triggers a local-network permission prompt.

@Suite("Link service")
struct LinkServiceTests {

    @Test("Initial tempo is the creation tempo")
    func initialTempo() {
        let link = LinkService(bpm: 120)
        #expect(abs(link.tempo() - 120) < 0.01)
        #expect(link.isEnabled == false)
        #expect(link.numPeers == 0)
    }

    @Test("setTempo round-trips through the session state")
    func setTempo() {
        let link = LinkService(bpm: 120)
        link.setTempo(133)
        #expect(abs(link.tempo() - 133) < 0.01)
    }

    @Test("The beat grid advances with the Link clock at the session tempo")
    func beatAdvances() {
        let link = LinkService(bpm: 120)
        let now = link.clockMicros()
        let beat1 = link.beat(atMicros: now, quantum: 4)
        let beat2 = link.beat(atMicros: now + 1_000_000, quantum: 4)
        // 120 BPM → 2 beats per second.
        #expect(abs((beat2 - beat1) - 2.0) < 0.01)
    }

    @Test("requestBeat aligns the grid so the beat lands at the given time")
    func requestBeat() {
        let link = LinkService(bpm: 120)
        let at = link.clockMicros() + 500_000
        link.requestBeat(0, atMicros: at, quantum: 4)
        let beat = link.beat(atMicros: at, quantum: 4)
        // Without peers the request is granted verbatim (mod quantum).
        #expect(abs(beat.truncatingRemainder(dividingBy: 4)) < 0.01
                || abs(beat.truncatingRemainder(dividingBy: 4) - 4) < 0.01)
    }
}

// MARK: - Transport in Link mode (FR-IO-5)

@Suite("Link transport sync", .serialized)
struct LinkTransportTests {

    @Test("Link mode: transport plays at the Link session tempo, not the project's")
    func linkTempoDrivesTransport() throws {
        let midi = try MIDIService(clientName: "BerlinanLinkTest",
                                   sourceName: "Berlinan Link Test Out")
        var project = Project.demo
        project.bpm = 90                      // must be OVERRIDDEN by Link

        let transport = Transport(project: project, midi: midi)
        transport.setSyncMode(.link)
        transport.linkService?.setTempo(133)

        transport.play()
        Thread.sleep(forTimeInterval: 0.5)
        #expect(transport.isPlaying)
        #expect(abs(transport.currentBPM - 133) < 1.0,
                "got \(transport.currentBPM)")
        let tick = try #require(transport.currentTick)
        #expect(tick > 0)

        transport.stop()
        #expect(!transport.isPlaying)
        #expect(midi.activeNoteCount == 0)
    }
}
