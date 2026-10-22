import Foundation
import CoreMIDI
import Testing
import BerlinanEngine
@testable import BerlinanRuntime

// MARK: - Estimator (pure)

@Suite("Clock estimator")
struct ClockEstimatorTests {

    /// 120 BPM → 24 PPQ pulse interval = 60e9 / (120·24) ns.
    private let interval120: Double = 60_000_000_000.0 / (120.0 * 24.0)

    @Test("Steady pulses converge to the true tempo")
    func steady() {
        var estimator = ClockEstimator()
        var t: Double = 1_000_000
        for _ in 0..<60 {
            estimator.pulse(atNanos: UInt64(t))
            t += interval120
        }
        let bpm = try! #require(estimator.bpm)
        #expect(abs(bpm - 120) < 0.5)
        #expect(estimator.pulseCount == 60)
    }

    @Test("±2 ms alternating jitter stays within 3%")
    func jitter() {
        var estimator = ClockEstimator()
        var t: Double = 1_000_000
        for index in 0..<120 {
            let wobble: Double = index.isMultiple(of: 2) ? 2_000_000 : -2_000_000
            estimator.pulse(atNanos: UInt64(t + wobble))
            t += interval120
        }
        let bpm = try! #require(estimator.bpm)
        #expect(abs(bpm - 120) / 120 < 0.03)
    }

    @Test("A single outlier is absorbed by the median")
    func outlier() {
        var estimator = ClockEstimator()
        var t: Double = 1_000_000
        for index in 0..<40 {
            estimator.pulse(atNanos: UInt64(t))
            t += interval120
            if index == 20 { t += 15_000_000 }   // one 15 ms hiccup
        }
        let bpm = try! #require(estimator.bpm)
        #expect(abs(bpm - 120) / 120 < 0.05)
    }

    @Test("Reset clears the state")
    func reset() {
        var estimator = ClockEstimator()
        estimator.pulse(atNanos: 0)
        estimator.pulse(atNanos: UInt64(interval120))
        estimator.reset()
        #expect(estimator.bpm == nil)
        #expect(estimator.pulseCount == 0)
    }
}

// MARK: - External sync integration (loopback)

@Suite("External clock sync", .serialized)
struct ExternalSyncTests {

    @Test("FA + F8 stream drives the transport; FC stops it")
    func followExternal() throws {
        let senderMIDI = try MIDIService(clientName: "BerlinanClockSender",
                                         sourceName: "Berlinan Test Clock Master")
        let midi = try MIDIService(clientName: "BerlinanSlaveTest",
                                   sourceName: "Berlinan Slave Test Out")
        var project = Project.demo
        project.bpm = 90                      // must be OVERRIDDEN by the estimate

        let transport = Transport(project: project, midi: midi)
        transport.setSyncMode(.externalClock, sourceName: "Berlinan Test Clock Master")

        // Drive: Start + ~1.2 s of 240 BPM pulses. The pulses are scheduled
        // upfront with EXACT timestamps (a sleep-per-pulse sender loop drifts
        // by milliseconds and skews the estimate — the estimator reads the
        // stamps, like a hardware slave).
        senderMIDI.send([(hostTime: 0, event: .start)])
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let machPerSecond = 1e9 * Double(info.denom) / Double(info.numer)
        let intervalMach = UInt64(60.0 / (240.0 * 24.0) * machPerSecond)
        let base = mach_absolute_time() + intervalMach
        senderMIDI.send((0..<115).map { index in
            (hostTime: base + UInt64(index) * intervalMach, event: MIDI1Event.clock)
        })
        Thread.sleep(forTimeInterval: 1.4)
        #expect(transport.isPlaying, "Start + clock must launch playback")
        let bpm = transport.currentBPM
        #expect(abs(bpm - 240) < 8, "estimated \(bpm)")
        #expect(transport.currentTick != nil)

        senderMIDI.send([(hostTime: 0, event: .stop)])
        Thread.sleep(forTimeInterval: 0.2)
        #expect(!transport.isPlaying, "Stop must halt the transport")
        #expect(midi.activeNoteCount == 0)
    }

    @Test("A rebuilt transport on the same MIDI service still follows external clock (audit #3)")
    func followAfterRebuild() throws {
        let senderMIDI = try MIDIService(clientName: "BerlinanClockSender2",
                                         sourceName: "Berlinan Test Clock Master 2")
        let midi = try MIDIService(clientName: "BerlinanSlaveTest2",
                                   sourceName: "Berlinan Slave Test Out 2")
        var first: Transport? = Transport(project: .demo, midi: midi)
        first?.setSyncMode(.externalClock, sourceName: "Berlinan Test Clock Master 2")
        first = nil                                   // project change → rebuild

        let rebuilt = Transport(project: .fullEnsemble, midi: midi)
        rebuilt.setSyncMode(.externalClock, sourceName: "Berlinan Test Clock Master 2")
        senderMIDI.send([(hostTime: 0, event: .start)])
        Thread.sleep(forTimeInterval: 0.4)
        #expect(rebuilt.isPlaying, "external Start must reach the rebuilt transport")
        senderMIDI.send([(hostTime: 0, event: .stop)])
        Thread.sleep(forTimeInterval: 0.2)
        #expect(!rebuilt.isPlaying)
    }
}
