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
        // Condition-based wait: the per-wake re-anchor normally converges in
        // one wake (25 ms). 2026-07-17 a since-unreproduced flake held 90 for
        // a full 0.5 s (see STATE watch list), so poll generously instead of
        // sampling one instant.
        var waited = 0.0
        while waited < 2.0 {
            let converged = abs(transport.currentBPM - 133) < 1.0
            let ticking = (transport.currentTick ?? 0) > 0
            if converged && ticking { break }
            Thread.sleep(forTimeInterval: 0.05)
            waited += 0.05
        }
        #expect(transport.isPlaying)
        #expect(abs(transport.currentBPM - 133) < 1.0,
                "got \(transport.currentBPM) after \(waited)s")
        let tick = try #require(transport.currentTick)
        #expect(tick > 0)

        transport.stop()
        #expect(!transport.isPlaying)
        #expect(midi.activeNoteCount == 0)
    }
}
