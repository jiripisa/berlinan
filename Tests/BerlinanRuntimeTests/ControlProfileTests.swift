import Foundation
import CoreMIDI
import Testing
import BerlinanEngine
@testable import BerlinanRuntime

// MARK: - Control map (FR-IO-10)

@Suite("Control map")
struct ControlMapTests {

    @Test("Bind, lookup, and last-wins rebinding")
    func binding() {
        var map = ControlMap()
        map.bind(.playStop, to: .cc(channel: 0, number: 20))
        map.bind(.degree(3), to: .cc(channel: 0, number: 21))
        #expect(map.macro(for: .cc(channel: 0, number: 20)) == .playStop)
        #expect(map.macro(for: .cc(channel: 0, number: 21)) == .degree(3))
        #expect(map.macro(for: .cc(channel: 0, number: 22)) == nil)
        // Rebinding the same trigger replaces the macro.
        map.bind(.newSeed, to: .cc(channel: 0, number: 20))
        #expect(map.macro(for: .cc(channel: 0, number: 20)) == .newSeed)
        // Rebinding the same macro moves it (old trigger freed).
        map.bind(.newSeed, to: .note(channel: 1, number: 36))
        #expect(map.macro(for: .cc(channel: 0, number: 20)) == nil)
        #expect(map.macro(for: .note(channel: 1, number: 36)) == .newSeed)
    }

    @Test("advancePhase macro (FR-A-6) binds and round-trips")
    func advancePhaseMacro() throws {
        var map = ControlMap()
        map.bind(.advancePhase, to: .cc(channel: 0, number: 30))
        #expect(map.macro(for: .cc(channel: 0, number: 30)) == .advancePhase)
        let data = try JSONEncoder().encode(map)
        let back = try JSONDecoder().decode(ControlMap.self, from: data)
        #expect(back.macro(for: .cc(channel: 0, number: 30)) == .advancePhase)
    }

    @Test("fireBPart macro (FR-A-5) binds and round-trips")
    func fireBPartMacro() throws {
        var map = ControlMap()
        map.bind(.fireBPart, to: .note(channel: 0, number: 41))
        let data = try JSONEncoder().encode(map)
        let back = try JSONDecoder().decode(ControlMap.self, from: data)
        #expect(back.macro(for: .note(channel: 0, number: 41)) == .fireBPart)
    }

    @Test("JSON persistence round-trip")
    func persistence() throws {
        var map = ControlMap()
        map.bind(.playStop, to: .note(channel: 9, number: 42))
        map.bind(.recallSlot(2), to: .cc(channel: 15, number: 119))
        map.bind(.degree(7), to: .cc(channel: 0, number: 1))
        let data = try JSONEncoder().encode(map)
        let back = try JSONDecoder().decode(ControlMap.self, from: data)
        #expect(back == map)
        #expect(back.macro(for: .note(channel: 9, number: 42)) == .playStop)
    }
}

// MARK: - Control input loopback (FR-IO-10)

@Suite("Control input", .serialized)
struct ControlInputTests {

    @Test("A CC sent to 'Berlinan Control' reaches the handler")
    func loopback() throws {
        let midi = try MIDIService(clientName: "BerlinanControlTest",
                                   sourceName: "Berlinan Control Test Out")
        let received = ReceivedBox()
        midi.createControlInput(named: "Berlinan Test Control") { trigger in
            received.append(trigger)
        }

        // Find the destination and send a CC + a note to it.
        var destination = MIDIEndpointRef()
        for index in 0..<MIDIGetNumberOfDestinations() {
            let endpoint = MIDIGetDestination(index)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
            if (name?.takeRetainedValue() as String?) == "Berlinan Test Control" {
                destination = endpoint
                break
            }
        }
        #expect(destination != 0, "control destination must be published")

        var client = MIDIClientRef()
        MIDIClientCreateWithBlock("ControlSender" as CFString, &client, nil)
        defer { MIDIClientDispose(client) }
        var port = MIDIPortRef()
        MIDIOutputPortCreate(client, "out" as CFString, &port)
        var words: [UInt32] = [0x20B0_1440]           // CC ch0 #20 val 64
        var builder = MIDIEventList()
        var packet = MIDIEventListInit(&builder, ._1_0)
        packet = MIDIEventListAdd(&builder, 1024, packet, 0, 1, &words)
        MIDISendEventList(port, destination, &builder)

        let deadline = Date().addingTimeInterval(2)
        while received.all.isEmpty && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        #expect(received.all.contains(.cc(channel: 0, number: 20)))
    }
}

private final class ReceivedBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [ControlTrigger] = []
    func append(_ t: ControlTrigger) { lock.lock(); storage.append(t); lock.unlock() }
    var all: [ControlTrigger] { lock.lock(); defer { lock.unlock() }; return storage }
}
