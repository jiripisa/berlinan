import Foundation
import Testing
import BerlinanEngine
@testable import BerlinanRuntime

@Suite("Transport snapshot & playhead", .serialized)
struct TransportSnapshotTests {

    @Test("Preview snapshot exists before play; currentTick tracks playback")
    func lifecycle() throws {
        let midi = try MIDIService(clientName: "BerlinanSnapTest",
                                   sourceName: "Berlinan Snap Test Out")
        let transport = Transport(project: .demo, midi: midi)

        // Before play: preview snapshot, no playhead.
        let preview = transport.snapshot()
        #expect(preview != nil)
        #expect(preview?.voices.count == 3)
        #expect(transport.currentTick == nil)

        transport.play()
        Thread.sleep(forTimeInterval: 0.4)
        let playingTick = transport.currentTick
        #expect(playingTick != nil)
        Thread.sleep(forTimeInterval: 0.2)
        if let a = playingTick, let b = transport.currentTick {
            #expect(b > a, "playhead must advance")
        }
        #expect(transport.snapshot() != nil)

        transport.stop()
        #expect(transport.currentTick == nil)
    }

    @Test("Mute state is queryable")
    func muteQuery() throws {
        let midi = try MIDIService(clientName: "BerlinanSnapTest2",
                                   sourceName: "Berlinan Snap Test Out 2")
        let transport = Transport(project: .demo, midi: midi)
        #expect(!transport.isMuted("bass"))
        transport.setMuted("bass", true)
        #expect(transport.isMuted("bass"))
        transport.setMuted("bass", false)
        #expect(!transport.isMuted("bass"))
    }
}
