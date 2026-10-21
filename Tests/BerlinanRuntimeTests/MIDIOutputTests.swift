import Foundation
import CoreMIDI
import Testing
@testable import BerlinanRuntime

/// Phase 44 (FR-IO-1): the output can be a connected destination instead of
/// the virtual source. A test-owned virtual destination stands in for the
/// hardware synth.

private final class Received: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UInt32] = []

    func append(_ words: [UInt32]) {
        lock.lock(); defer { lock.unlock() }
        storage.append(contentsOf: words)
    }

    var words: [UInt32] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }
}

/// A virtual destination ("the synth") that records every word it receives.
private final class FakeSynth {
    private var client = MIDIClientRef()
    private(set) var endpoint = MIDIEndpointRef()
    let received = Received()

    init(name: String) {
        MIDIClientCreateWithBlock("\(name) client" as CFString, &client, nil)
        let received = self.received
        MIDIDestinationCreateWithProtocol(client, name as CFString, ._1_0, &endpoint) { list, _ in
            for packet in list.unsafeSequence() {
                received.append(Array(packet.words()))
            }
        }
    }

    var uniqueID: MIDIUniqueID {
        var id: MIDIUniqueID = 0
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &id)
        return id
    }

    func unplug() {
        MIDIEndpointDispose(endpoint)
        endpoint = 0
    }

    deinit {
        if endpoint != 0 { MIDIEndpointDispose(endpoint) }
        MIDIClientDispose(client)
    }
}

@Suite("MIDI output device", .serialized)
struct MIDIOutputTests {

    @Test("Connected destinations are offered; our own control input is not")
    func listsDestinations() throws {
        let synth = FakeSynth(name: "Berlinan Test Synth A")
        let midi = try MIDIService(clientName: "BerlinanOutTest1",
                                   sourceName: "Berlinan Out Test 1")
        midi.createControlInput(named: "Berlinan Output Test Control") { _ in }
        Thread.sleep(forTimeInterval: 0.1)
        let names = midi.destinations().map(\.name)
        #expect(names.contains("Berlinan Test Synth A"))
        #expect(!names.contains("Berlinan Output Test Control"), "never offer our own input")
        #expect(midi.destinations().contains { $0.uniqueID == synth.uniqueID })
    }

    @Test("With a device chosen, notes go to the device")
    func sendsToDevice() throws {
        let synth = FakeSynth(name: "Berlinan Test Synth B")
        let midi = try MIDIService(clientName: "BerlinanOutTest2",
                                   sourceName: "Berlinan Out Test 2")
        midi.setOutput(synth.uniqueID)
        #expect(midi.outputDestinationID == synth.uniqueID)
        #expect(midi.isOutputAvailable)
        midi.send([(hostTime: 0, event: .noteOn(channel: 0, note: 60, velocity: 100))])
        Thread.sleep(forTimeInterval: 0.2)
        #expect(synth.received.words.contains(0x2090_3C64))
    }

    @Test("Switching output silences what still sounds on the previous one")
    func switchFlushes() throws {
        let first = FakeSynth(name: "Berlinan Test Synth C")
        let second = FakeSynth(name: "Berlinan Test Synth D")
        let midi = try MIDIService(clientName: "BerlinanOutTest3",
                                   sourceName: "Berlinan Out Test 3")
        midi.setOutput(first.uniqueID)
        midi.send([(hostTime: 0, event: .noteOn(channel: 2, note: 48, velocity: 90))])
        midi.setOutput(second.uniqueID)
        Thread.sleep(forTimeInterval: 0.2)
        #expect(first.received.words.contains(0x2082_3000), "note-off reached the old device")
        #expect(second.received.words.isEmpty)
        #expect(midi.activeNoteCount == 0)
    }

    @Test("An unplugged device drops events instead of crashing")
    func unpluggedDrops() throws {
        let synth = FakeSynth(name: "Berlinan Test Synth E")
        let midi = try MIDIService(clientName: "BerlinanOutTest4",
                                   sourceName: "Berlinan Out Test 4")
        midi.setOutput(synth.uniqueID)
        synth.unplug()
        Thread.sleep(forTimeInterval: 0.1)
        #expect(!midi.isOutputAvailable)
        midi.send([(hostTime: 0, event: .noteOn(channel: 0, note: 60, velocity: 100))])
        midi.setOutput(nil)
        #expect(midi.outputDestinationID == nil)
        #expect(midi.isOutputAvailable, "the virtual source is always there")
    }
}

/// Phase 45 (audit #2): a note's note-off is sent ahead with its note-on;
/// until that time the note still sounds and stop/mute must silence it.
@Suite("Scheduled notes and flush", .serialized)
struct ScheduledFlushTests {

    @Test("A note stays tracked until its scheduled note-off time")
    func tracksUntilOffTime() {
        var registry = NoteRegistry()
        registry.track(.noteOn(channel: 0, note: 36, velocity: 100), at: 100)
        registry.track(.noteOff(channel: 0, note: 36), at: 5_000)
        let atStop = registry.flushEvents(now: 1_000)
        #expect(atStop.contains(.noteOff(channel: 0, note: 36)))
        #expect(atStop.contains(.cc(channel: 0, controller: 123, value: 0)))
        #expect(registry.flushEvents(now: 1_000).isEmpty, "flushed once")
    }

    @Test("A note whose note-off already passed is not flushed again")
    func endedNotesIgnored() {
        var registry = NoteRegistry()
        registry.track(.noteOn(channel: 1, note: 60, velocity: 100), at: 100)
        registry.track(.noteOff(channel: 1, note: 60), at: 500)
        #expect(registry.flushEvents(now: 1_000).isEmpty)
    }

    @Test("Stop silences a long note that is still sounding on the device")
    func flushReachesDevice() throws {
        let synth = FakeSynth(name: "Berlinan Test Synth F")
        let midi = try MIDIService(clientName: "BerlinanOutTest5",
                                   sourceName: "Berlinan Out Test 5")
        midi.setOutput(synth.uniqueID)
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let threeSeconds = UInt64(3e9 * Double(info.denom) / Double(info.numer))
        midi.send([
            (hostTime: 0, event: .noteOn(channel: 0, note: 36, velocity: 100)),
            (hostTime: mach_absolute_time() + threeSeconds, event: .noteOff(channel: 0, note: 36)),
        ])
        #expect(midi.activeNoteCount == 1, "the drone still sounds")
        midi.flush()
        Thread.sleep(forTimeInterval: 0.2)
        #expect(synth.received.words.contains(0x2080_2400), "note-off now, not in 3 s")
        #expect(synth.received.words.contains(0x20B0_7B00), "CC 123 too")
        #expect(midi.activeNoteCount == 0)
    }
}
