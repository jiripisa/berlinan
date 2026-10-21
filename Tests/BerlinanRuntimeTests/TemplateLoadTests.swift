import Foundation
import Testing
import BerlinanEngine
@testable import BerlinanRuntime

/// Phase 42: a template picked while playing loads at the next bar — the
/// clock keeps running, the new piece starts from its beginning.

@Suite("Transport — live project load", .serialized)
struct TemplateLoadTests {

    private func fast(_ project: Project) -> Project {
        var p = project
        p.bpm = 200                                // one bar = 1.2 s
        return p
    }

    @Test("Playing: the new project takes over at the next bar, position restarts")
    func loadsAtNextBar() throws {
        let midi = try MIDIService(clientName: "BerlinanLoadTest",
                                   sourceName: "Berlinan Load Test Out")
        let transport = Transport(project: fast(.demo), midi: midi)
        transport.play()
        defer { transport.stop() }
        Thread.sleep(forTimeInterval: 0.4)

        transport.loadProject(fast(.fullEnsemble))
        #expect(transport.hasPendingProjectLoad)
        #expect(transport.snapshot()?.voices.count == 3,
                "the old piece plays on until the bar line")

        Thread.sleep(forTimeInterval: 1.6)
        #expect(!transport.hasPendingProjectLoad)
        #expect(transport.snapshot()?.voices.count == 6)
        #expect(transport.isPlaying, "the transport never stops")
        let bar = Project.fullEnsemble.meter.ticksPerBar
        let tick = try #require(transport.currentTick)
        #expect(tick < bar, "the new piece starts from its beginning")
    }

    @Test("Bar lines count from the loaded project's origin (meter may change)")
    func barsFromOrigin() {
        let fourFour: Tick = 4 * Time.ppqn, threeFour: Tick = 3 * Time.ppqn
        #expect(Transport.nextBar(after: 1, origin: 0, barTicks: fourFour) == fourFour)
        #expect(Transport.nextBar(after: fourFour, origin: 0, barTicks: fourFour) == fourFour)
        // A 3/4 project loaded at bar 2 of a 4/4 piece: its bars start there.
        let origin = 2 * fourFour
        #expect(Transport.nextBar(after: origin + 1, origin: origin, barTicks: threeFour)
                == origin + threeFour)
    }

    @Test("Stopped: loadProject is ignored — the app rebuilds instead")
    func ignoredWhenStopped() throws {
        let midi = try MIDIService(clientName: "BerlinanLoadTest2",
                                   sourceName: "Berlinan Load Test Out 2")
        let transport = Transport(project: .demo, midi: midi)
        transport.loadProject(.fullEnsemble)
        #expect(!transport.hasPendingProjectLoad)
        #expect(transport.snapshot()?.voices.count == 3)
    }
}
