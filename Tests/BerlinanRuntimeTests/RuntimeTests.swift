import Foundation
import CoreMIDI
import Testing
@testable import BerlinanRuntime

// MARK: - UMP encoding (MIDI 1.0 channel voice in Universal MIDI Packets)

@Suite("MIDI1Event UMP encoding")
struct UMPEncodingTests {

    @Test("Channel voice vectors (message type 0x2)")
    func channelVoice() {
        #expect(MIDI1Event.noteOn(channel: 0, note: 60, velocity: 100).umpWord == 0x2090_3C64)
        #expect(MIDI1Event.noteOff(channel: 2, note: 48).umpWord == 0x2082_3000)
        #expect(MIDI1Event.cc(channel: 1, controller: 74, value: 127).umpWord == 0x20B1_4A7F)
        #expect(MIDI1Event.cc(channel: 15, controller: 123, value: 0).umpWord == 0x20BF_7B00)
    }

    @Test("System real-time vectors (message type 0x1)")
    func systemRealTime() {
        #expect(MIDI1Event.clock.umpWord == 0x10F8_0000)
        #expect(MIDI1Event.start.umpWord == 0x10FA_0000)
        #expect(MIDI1Event.continuePlayback.umpWord == 0x10FB_0000)
        #expect(MIDI1Event.stop.umpWord == 0x10FC_0000)
    }
}

// MARK: - Note registry (runtime half of FR-IO-8)

@Suite("Note registry")
struct NoteRegistryTests {

    @Test("On adds, off removes")
    func tracking() {
        var registry = NoteRegistry()
        registry.track(.noteOn(channel: 0, note: 60, velocity: 100))
        registry.track(.noteOn(channel: 1, note: 62, velocity: 90))
        #expect(registry.activeCount == 2)
        registry.track(.noteOff(channel: 0, note: 60))
        #expect(registry.activeCount == 1)
    }

    @Test("Non-note events do not affect the registry")
    func ignoresOthers() {
        var registry = NoteRegistry()
        registry.track(.cc(channel: 0, controller: 74, value: 1))
        registry.track(.clock)
        #expect(registry.activeCount == 0)
    }

    @Test("Flush emits note-offs for everything sounding + CC123 per channel, then is empty")
    func flushAll() {
        var registry = NoteRegistry()
        registry.track(.noteOn(channel: 0, note: 60, velocity: 100))
        registry.track(.noteOn(channel: 0, note: 64, velocity: 100))
        registry.track(.noteOn(channel: 2, note: 36, velocity: 100))
        let events = registry.flushEvents()
        let offs = events.filter { if case .noteOff = $0 { return true }; return false }
        let resets = events.filter { if case .cc(_, 123, 0) = $0 { return true }; return false }
        #expect(offs.count == 3)
        #expect(resets.count == 2)          // channels 0 and 2
        #expect(registry.activeCount == 0)
        #expect(registry.flushEvents().isEmpty, "double flush must be a no-op")
    }

    @Test("Per-channel flush leaves other channels sounding")
    func flushChannel() {
        var registry = NoteRegistry()
        registry.track(.noteOn(channel: 0, note: 60, velocity: 100))
        registry.track(.noteOn(channel: 2, note: 36, velocity: 100))
        let events = registry.flushEvents(channel: 0)
        #expect(events.contains(.noteOff(channel: 0, note: 60)))
        #expect(events.contains(.cc(channel: 0, controller: 123, value: 0)))
        #expect(!events.contains(.noteOff(channel: 2, note: 36)))
        #expect(registry.activeCount == 1)
    }
}

// MARK: - CoreMIDI loopback integration

/// Thread-safe word collector for the CoreMIDI receive callback.
private final class WordCollector: @unchecked Sendable {
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

@Suite("MIDIService loopback", .serialized)
struct MIDIServiceTests {

    @Test("Virtual source is visible and delivers timestamped events in-process")
    func loopback() throws {
        let service = try MIDIService(clientName: "BerlinanTest",
                                      sourceName: "Berlinan Test Out")

        // The virtual source must be discoverable by name.
        let names = (0..<MIDIGetNumberOfSources()).compactMap { i -> String? in
            let endpoint = MIDIGetSource(i)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
            return name?.takeRetainedValue() as String?
        }
        #expect(names.contains("Berlinan Test Out"))

        // Connect an in-process input port to the virtual source.
        var client = MIDIClientRef()
        #expect(MIDIClientCreateWithBlock("BerlinanTestListener" as CFString, &client, nil) == noErr)
        defer { MIDIClientDispose(client) }

        let collector = WordCollector()
        var port = MIDIPortRef()
        let status = MIDIInputPortCreateWithProtocol(client, "in" as CFString, ._1_0, &port) { list, _ in
            var received: [UInt32] = []
            for packet in list.unsafeSequence() {
                for word in packet.words() {
                    received.append(word)
                }
            }
            collector.append(received)
        }
        #expect(status == noErr)
        #expect(MIDIPortConnectSource(port, service.sourceEndpoint, nil) == noErr)

        // Send now (hostTime 0) and poll for arrival.
        service.send([
            (hostTime: 0, event: .noteOn(channel: 0, note: 60, velocity: 100)),
            (hostTime: 0, event: .noteOff(channel: 0, note: 60)),
        ])
        let deadline = Date().addingTimeInterval(2.0)
        while collector.words.count < 2 && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        #expect(collector.words.contains(0x2090_3C64))
        #expect(collector.words.contains(0x2080_3C00))

        // The registry saw the pair — nothing should be left sounding.
        #expect(service.activeNoteCount == 0)
    }

    @Test("flush() emits offs for hanging notes")
    func flushSendsOffs() throws {
        let service = try MIDIService(clientName: "BerlinanTest2",
                                      sourceName: "Berlinan Test Out 2")
        service.send([(hostTime: 0, event: .noteOn(channel: 3, note: 40, velocity: 80))])
        #expect(service.activeNoteCount == 1)
        service.flush()
        #expect(service.activeNoteCount == 0)
    }
}
