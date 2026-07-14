import Foundation
import Testing
import BerlinanEngine
@testable import BerlinanRuntime

private let beat: Tick = 960
private let bar: Tick = 4 * beat
private let meter = Meter.fourFour

private func note(_ at: Tick, voice: String = "a", midi: UInt8 = 60) -> RenderedNote {
    RenderedNote(voiceID: voice, at: at, midiNote: midi, velocity: 100,
                 gate: 120, accent: false, ratchet: 1)
}

// MARK: - Capture buffer (FR-IO-7)

@Suite("Capture buffer")
struct CaptureBufferTests {

    @Test("Prune keeps only the last `capacity` ticks")
    func prune() {
        var capture = CaptureBuffer(capacityTicks: 2 * bar)
        for barIndex in 0..<6 {
            capture.append([note(Tick(barIndex) * bar)], upTo: Tick(barIndex + 1) * bar)
        }
        // Head is 6 bars; only notes at >= 4 bars survive.
        #expect(capture.allNotes.map(\.at) == [4 * bar, 5 * bar])
    }

    @Test("Selection returns exactly the notes inside the window")
    func selection() {
        var capture = CaptureBuffer(capacityTicks: 100 * bar)
        capture.append([note(0), note(bar + beat), note(2 * bar), note(3 * bar - 1)],
                       upTo: 3 * bar)
        let clip = capture.notes(lastBars: 2, endTick: 3 * bar, meter: meter)
        #expect(clip.map(\.at) == [beat, bar, 2 * bar - 1])   // rebased below
    }

    @Test("Rebase: export covers whole bars only, starts on a boundary, re-zeroes ticks")
    func rebase() {
        var capture = CaptureBuffer(capacityTicks: 100 * bar)
        capture.append([note(4 * bar + beat, midi: 61), note(5 * bar + beat, midi: 62)],
                       upTo: 6 * bar)
        // endTick mid-bar 6 floors to 5·bar → window is [3·bar, 5·bar):
        // the partial current bar (and anything in it) is excluded.
        let clip = capture.notes(lastBars: 2, endTick: 6 * bar - 5, meter: meter)
        #expect(clip.count == 1)
        #expect(clip[0].at == bar + beat)     // 4·bar+beat − 3·bar
        #expect(clip[0].midiNote == 61)
    }

    @Test("Empty selection for an empty buffer")
    func emptyBuffer() {
        let capture = CaptureBuffer(capacityTicks: bar)
        #expect(capture.notes(lastBars: 4, endTick: 10 * bar, meter: meter).isEmpty)
    }
}

// MARK: - Transport export integration

@Suite("Transport capture export", .serialized)
struct TransportExportTests {

    @Test("A short live run exports a valid SMF of the last bar")
    func exportAfterPlay() throws {
        let midi = try MIDIService(clientName: "BerlinanCaptureTest",
                                   sourceName: "Berlinan Capture Test Out")
        var project = Project.demo
        project.bpm = 240                       // 1 bar = 1 s — fast test
        let transport = Transport(project: project, midi: midi)

        #expect(transport.exportCapture(lastBars: 1) == nil,
                "nothing captured before playing")

        transport.play()
        Thread.sleep(forTimeInterval: 1.4)      // > 1 bar incl. preroll
        transport.stop()

        let bytes = try #require(transport.exportCapture(lastBars: 1))
        #expect(Array(bytes.prefix(4)) == Array("MThd".utf8))
        // Note-ons present somewhere in the file (status 0x9n).
        #expect(bytes.contains { $0 & 0xF0 == 0x90 })
    }
}
