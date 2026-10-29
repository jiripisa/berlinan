import Foundation
import CoreMIDI
import Testing
import BerlinanEngine
@testable import BerlinanRuntime

/// Phase 47: the user picks each voice's MIDI channel — also while playing.
/// A test-owned virtual destination stands in for the multitimbral synth.

private final class TimedWords: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [(word: UInt32, timeStamp: MIDITimeStamp)] = []

    func append(_ word: UInt32, _ timeStamp: MIDITimeStamp) {
        lock.lock(); defer { lock.unlock() }
        storage.append((word, timeStamp))
    }

    /// Note-ons (velocity > 0) on `channel` timestamped after `mach`.
    func noteOns(channel: UInt8, after mach: UInt64) -> Int {
        lock.lock(); defer { lock.unlock() }
        return storage.filter {
            $0.timeStamp > mach
                && ($0.word >> 16) & 0xFF == 0x90 | UInt32(channel)
                && $0.word & 0x7F > 0
        }.count
    }

    /// Control changes for `controller` on any channel.
    func controlChanges(_ controller: UInt8) -> Int {
        lock.lock(); defer { lock.unlock() }
        return storage.filter {
            ($0.word >> 16) & 0xF0 == 0xB0 && ($0.word >> 8) & 0x7F == UInt32(controller)
        }.count
    }

    func contains(_ word: UInt32) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return storage.contains { $0.word == word }
    }
}

private final class ChannelSynth {
    private var client = MIDIClientRef()
    private var endpoint = MIDIEndpointRef()
    let received = TimedWords()

    init(name: String) {
        MIDIClientCreateWithBlock("\(name) client" as CFString, &client, nil)
        let received = self.received
        MIDIDestinationCreateWithProtocol(client, name as CFString, ._1_0, &endpoint) { list, _ in
            for packet in list.unsafeSequence() {
                let timeStamp = packet.pointee.timeStamp
                for word in packet.words() { received.append(word, timeStamp) }
            }
        }
    }

    var uniqueID: MIDIUniqueID {
        var id: MIDIUniqueID = 0
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &id)
        return id
    }

    deinit {
        MIDIEndpointDispose(endpoint)
        MIDIClientDispose(client)
    }
}

/// Past everything the scheduler already queued on the old channel
/// (preroll 100 ms + lookahead 150 ms).
private func machAfterQueued() -> UInt64 {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    return mach_absolute_time() + UInt64(300_000_000 * Double(info.denom) / Double(info.numer))
}

@Suite("Per-voice MIDI channel", .serialized)
struct VoiceChannelTests {

    private func fast(_ project: Project) -> Project {
        var p = project
        p.bpm = 200                                // one bar = 1.2 s
        return p
    }

    @Test("Playing: the voice moves to the new channel, capture export follows")
    func movesWhilePlaying() throws {
        let synth = ChannelSynth(name: "Berlinan Channel Synth A")
        let midi = try MIDIService(clientName: "BerlinanChannelTest1",
                                   sourceName: "Berlinan Channel Test 1")
        midi.setOutput(synth.uniqueID)
        let transport = Transport(project: fast(.demo), midi: midi)
        transport.play()
        defer { transport.stop() }
        Thread.sleep(forTimeInterval: 0.6)

        transport.setChannel("bass", 11)
        let settled = machAfterQueued()
        Thread.sleep(forTimeInterval: 1.6)

        #expect(synth.received.noteOns(channel: 11, after: settled) > 0,
                "bass plays on channel 12")
        #expect(synth.received.noteOns(channel: 2, after: settled) == 0,
                "nothing left on the old channel")
        let smf = try #require(transport.exportCapture(lastBars: 4))
        #expect(String(decoding: smf, as: UTF8.self).contains("bass | ch12"))
    }

    @Test("A sounding note on the old channel is silenced")
    func flushesOldChannel() throws {
        let synth = ChannelSynth(name: "Berlinan Channel Synth B")
        let midi = try MIDIService(clientName: "BerlinanChannelTest2",
                                   sourceName: "Berlinan Channel Test 2")
        midi.setOutput(synth.uniqueID)
        let transport = Transport(project: fast(.ambientDrift), midi: midi)
        transport.play()
        defer { transport.stop() }
        Thread.sleep(forTimeInterval: 0.8)          // the drone sounds (ch 1)

        transport.setChannel("drone", 5)
        Thread.sleep(forTimeInterval: 0.2)
        #expect(synth.received.contains(0x20B0_7B00), "CC 123 on the old channel")
    }

    @Test("A change made while a template load is pending survives the swap")
    func survivesTemplateLoad() throws {
        let synth = ChannelSynth(name: "Berlinan Channel Synth C")
        let midi = try MIDIService(clientName: "BerlinanChannelTest3",
                                   sourceName: "Berlinan Channel Test 3")
        midi.setOutput(synth.uniqueID)
        let transport = Transport(project: fast(.demo), midi: midi)
        transport.play()
        defer { transport.stop() }
        Thread.sleep(forTimeInterval: 0.4)

        transport.loadProject(fast(.fullEnsemble))
        transport.setChannel("bass", 11)
        let settled = machAfterQueued()
        Thread.sleep(forTimeInterval: 2.6)

        #expect(!transport.hasPendingProjectLoad)
        #expect(transport.snapshot()?.voices.count == 6)
        #expect(synth.received.noteOns(channel: 11, after: settled) > 0)
        #expect(synth.received.noteOns(channel: 2, after: settled) == 0,
                "the template's own bass channel must not come back")
    }

    @Test("A CC LFO added while a template load is pending survives the swap (phase 61)")
    func ccLanesSurviveTemplateLoad() throws {
        let synth = ChannelSynth(name: "Berlinan Channel Synth D")
        let midi = try MIDIService(clientName: "BerlinanChannelTest4",
                                   sourceName: "Berlinan Channel Test 4")
        midi.setOutput(synth.uniqueID)
        let transport = Transport(project: fast(.demo), midi: midi)
        transport.play()
        defer { transport.stop() }
        Thread.sleep(forTimeInterval: 0.4)

        transport.loadProject(fast(.fullEnsemble))
        // The pad exists only in the template being loaded.
        transport.setCCLanes(voiceID: "pad", lanes: [
            CCLane(target: "", shape: .sine, cycleBars: 16, depth: 0, center: 0.5,
                   controller: 33),
        ])
        Thread.sleep(forTimeInterval: 2.6)

        #expect(!transport.hasPendingProjectLoad)
        #expect(synth.received.controlChanges(33) > 0)
    }
}
