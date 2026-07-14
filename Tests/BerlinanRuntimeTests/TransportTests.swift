import Foundation
import CoreMIDI
import Testing
import BerlinanEngine
@testable import BerlinanRuntime

private let beat: Tick = 960
private let bar: Tick = 4 * beat

// MARK: - TickClock

@Suite("TickClock")
struct TickClockTests {

    /// Identity timebase (1/1) makes mach units = nanoseconds.
    private let clock = TickClock(bpm: 90, anchorMach: 1_000_000,
                                  timebase: (numer: 1, denom: 1))

    @Test("One beat at 90 BPM is 666.67 ms")
    func beatDuration() {
        let t0 = clock.machTime(forTick: 0)
        let t1 = clock.machTime(forTick: beat)
        #expect(t0 == 1_000_000)
        #expect(abs(Int64(t1 - t0) - 666_666_666) <= 1)
    }

    @Test("tick(atMach:) inverts machTime(forTick:)")
    func roundTrip() {
        for tick in [Tick(0), 40, 960, 3840, 12345] {
            let host = clock.machTime(forTick: tick)
            #expect(clock.tick(atMach: host) == tick)
        }
        #expect(clock.tick(atMach: 999_999) == -1)   // just before the anchor
    }

    @Test("Non-identity timebase scales correctly")
    func timebaseScaling() {
        // Apple Silicon style: 125/3 ns per mach unit... inverse: numer=125, denom=3
        // means ns = mach * 125 / 3 → mach = ns * 3 / 125.
        let c = TickClock(bpm: 120, anchorMach: 0, timebase: (numer: 125, denom: 3))
        // One beat @120 = 0.5 s = 500_000_000 ns = 12_000_000 mach units.
        #expect(c.machTime(forTick: beat) == 12_000_000)
        #expect(c.tick(atMach: 12_000_000) == beat)
    }
}

// MARK: - Event conversion

@Suite("Event conversion")
struct EventConversionTests {

    private func note(_ at: Tick, voice: String = "a", midi: UInt8 = 60,
                      gate: Tick = 120, velocity: UInt8 = 100) -> RenderedNote {
        RenderedNote(voiceID: voice, at: at, midiNote: midi, velocity: velocity,
                     gate: gate, accent: false, ratchet: 1)
    }

    @Test("Each note becomes an on/off pair; off = at + gate; channel from the map")
    func pairs() {
        let events = NoteEventConverter.events(
            for: [note(0, voice: "a"), note(beat, voice: "b", midi: 40)],
            channelMap: ["a": 0, "b": 2], muted: [])
        #expect(events.count == 4)
        #expect(events.contains { $0.tick == 0 && $0.event == .noteOn(channel: 0, note: 60, velocity: 100) })
        #expect(events.contains { $0.tick == 120 && $0.event == .noteOff(channel: 0, note: 60) })
        #expect(events.contains { $0.tick == beat && $0.event == .noteOn(channel: 2, note: 40, velocity: 100) })
        #expect(events.contains { $0.tick == beat + 120 && $0.event == .noteOff(channel: 2, note: 40) })
    }

    @Test("Muted voices are dropped (runtime post-render gate)")
    func mutedDropped() {
        let events = NoteEventConverter.events(
            for: [note(0, voice: "a"), note(0, voice: "b", midi: 40)],
            channelMap: ["a": 0, "b": 2], muted: ["b"])
        #expect(events.count == 2)
        #expect(events.allSatisfy {
            if case .noteOff(2, _) = $0.event { return false }
            if case .noteOn(2, _, _) = $0.event { return false }
            return true
        })
    }

    @Test("24 PPQ clock grid: 96 clocks per 4/4 bar at 40-tick spacing")
    func clockGrid() {
        let ticks = NoteEventConverter.clockTicks(in: 0..<bar)
        #expect(ticks.count == 96)
        #expect(ticks.first == 0)
        #expect(ticks.allSatisfy { $0 % 40 == 0 })
        // Half-open + seam-safety:
        let a = NoteEventConverter.clockTicks(in: 0..<777)
        let b = NoteEventConverter.clockTicks(in: 777..<bar)
        #expect(a.count + b.count == 96)
    }
}

// MARK: - Transport integration (loopback)

private final class EventCollector: @unchecked Sendable {
    struct Received { let word: UInt32; let timeStamp: MIDITimeStamp }
    private let lock = NSLock()
    private var storage: [Received] = []

    func append(_ items: [Received]) {
        lock.lock(); defer { lock.unlock() }
        storage.append(contentsOf: items)
    }

    var received: [Received] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }
}

@Suite("Transport integration", .serialized)
struct TransportIntegrationTests {

    @Test("Play → start + clocks + notes; stop → stop + silence")
    func playStop() throws {
        let midi = try MIDIService(clientName: "BerlinanTransportTest",
                                   sourceName: "Berlinan Transport Test Out")
        var project = Project.demo
        project.bpm = 120

        var client = MIDIClientRef()
        MIDIClientCreateWithBlock("TransportListener" as CFString, &client, nil)
        defer { MIDIClientDispose(client) }
        let collector = EventCollector()
        var port = MIDIPortRef()
        MIDIInputPortCreateWithProtocol(client, "in" as CFString, ._1_0, &port) { list, _ in
            var items: [EventCollector.Received] = []
            for packet in list.unsafeSequence() {
                let ts = packet.pointee.timeStamp
                for word in packet.words() {
                    items.append(.init(word: word, timeStamp: ts))
                }
            }
            collector.append(items)
        }
        MIDIPortConnectSource(port, midi.sourceEndpoint, nil)

        let transport = Transport(project: project, midi: midi)
        transport.play()
        #expect(transport.isPlaying)
        Thread.sleep(forTimeInterval: 0.7)
        transport.stop()
        #expect(!transport.isPlaying)
        Thread.sleep(forTimeInterval: 0.1)

        let words = collector.received.map(\.word)
        #expect(words.contains(0x10FA_0000), "MIDI Start must be sent")
        #expect(words.contains(0x10FC_0000), "MIDI Stop must be sent")

        // ~0.7 s @ 120 BPM = 1.4 beats = ~33 clocks; lookahead adds ~0.15 s.
        let clocks = collector.received.filter { $0.word == 0x10F8_0000 }
        #expect(clocks.count > 20 && clocks.count < 60, "clock count \(clocks.count)")

        let noteOns = words.filter { ($0 & 0xFFF0_0000) == 0x2090_0000 }
        #expect(!noteOns.isEmpty, "notes must flow")

        // NFR-1 evidence at the scheduling layer: consecutive clock
        // timestamps spaced one 24-PPQ interval apart (±1 ms in mach≈ns).
        let expectedSpacing = 60.0 / 120.0 / 24.0 * 1e9 * machToNanos()
        let stamps = clocks.map(\.timeStamp).sorted()
        for (a, b) in zip(stamps, stamps.dropFirst()) {
            let delta = Double(b - a)
            #expect(abs(delta - expectedSpacing) < 1e6 * machToNanos(),
                    "clock jitter \(delta) vs \(expectedSpacing)")
        }

        #expect(midi.activeNoteCount == 0, "stop must flush all notes")
    }
}

/// mach units per nanosecond correction factor (1.0 when timebase is 1/1).
private func machToNanos() -> Double {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    return Double(info.denom) / Double(info.numer)
}

// MARK: - CC over the live stream (phase 17)

@Suite("Transport CC emission", .serialized)
struct TransportCCTests {

    @Test("A project with a CC lane produces 0xB0 words live")
    func liveCC() throws {
        let midi = try MIDIService(clientName: "BerlinanCCTest",
                                   sourceName: "Berlinan CC Test Out")
        var project = Project.demo          // bedPluck1 carries a filter lane
        project.bpm = 240

        var client = MIDIClientRef()
        MIDIClientCreateWithBlock("CCListener" as CFString, &client, nil)
        defer { MIDIClientDispose(client) }
        let collector = EventCollector()
        var port = MIDIPortRef()
        MIDIInputPortCreateWithProtocol(client, "in" as CFString, ._1_0, &port) { list, _ in
            var items: [EventCollector.Received] = []
            for packet in list.unsafeSequence() {
                let ts = packet.pointee.timeStamp
                for word in packet.words() { items.append(.init(word: word, timeStamp: ts)) }
            }
            collector.append(items)
        }
        MIDIPortConnectSource(port, midi.sourceEndpoint, nil)

        let transport = Transport(project: project, midi: midi)
        transport.play()
        Thread.sleep(forTimeInterval: 0.5)
        transport.stop()
        Thread.sleep(forTimeInterval: 0.1)

        let ccWords = collector.received.map(\.word)
            .filter { ($0 & 0xFFFF_0000) == 0x20B0_0000 && (($0 >> 8) & 0x7F) == 74 }
        #expect(!ccWords.isEmpty, "expected CC74 on channel 0 in the live stream")
    }
}
