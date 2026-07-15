import CoreMIDI

/// CoreMIDI virtual source + timestamped sending (FR-IO-1/2). One instance
/// owns one virtual source ("Berlinan Out" in the app). Not thread-safe by
/// design — owned and driven by the scheduler thread (spec §5.4).
public final class MIDIService {

    public enum MIDIError: Error {
        case clientCreation(OSStatus)
        case sourceCreation(OSStatus)
    }

    private var client = MIDIClientRef()
    public private(set) var sourceEndpoint = MIDIEndpointRef()
    private var registry = NoteRegistry()

    public var activeNoteCount: Int { registry.activeCount }

    public init(clientName: String, sourceName: String) throws {
        var status = MIDIClientCreateWithBlock(clientName as CFString, &client, nil)
        guard status == noErr else { throw MIDIError.clientCreation(status) }
        status = MIDISourceCreateWithProtocol(client, sourceName as CFString,
                                              ._1_0, &sourceEndpoint)
        guard status == noErr else {
            MIDIClientDispose(client)
            throw MIDIError.sourceCreation(status)
        }
    }

    deinit {
        _ = registry.flushEvents()          // best effort; offs below
        MIDIEndpointDispose(sourceEndpoint)
        MIDIClientDispose(client)
    }

    // MARK: - Sending

    /// Send events with CoreMIDI host-time timestamps (0 = deliver now).
    /// Events are tracked in the note registry as they are sent.
    public func send(_ events: [(hostTime: UInt64, event: MIDI1Event)]) {
        // Capacity is guaranteed by chunking (MIDIEventListAdd's "list full"
        // signal is unusable from Swift — the return is imported non-optional):
        // worst case one packet per event = 16 bytes (8 timestamp + 4 count +
        // 4 word), so 200 events always fit a 4096-byte list with headroom.
        let chunkSize = 200
        var index = 0
        while index < events.count {
            sendChunk(events[index..<min(index + chunkSize, events.count)])
            index += chunkSize
        }
    }

    private func sendChunk(_ events: ArraySlice<(hostTime: UInt64, event: MIDI1Event)>) {
        guard !events.isEmpty else { return }
        var buffer = [UInt8](repeating: 0, count: 4096)
        buffer.withUnsafeMutableBytes { raw in
            let listPtr = raw.baseAddress!.assumingMemoryBound(to: MIDIEventList.self)
            var packet = MIDIEventListInit(listPtr, ._1_0)
            for item in events {
                registry.track(item.event)
                var word = item.event.umpWord
                packet = MIDIEventListAdd(listPtr, raw.count, packet,
                                          MIDITimeStamp(item.hostTime), 1, &word)
            }
            MIDIReceivedEventList(sourceEndpoint, listPtr)
        }
    }

    // MARK: - Clock input (FR-IO-4)

    public enum RealTimeMessage: Sendable {
        case clock, start, continuePlayback, stop
    }

    private var inputPort = MIDIPortRef()

    /// Connect an input port to external sources (self excluded; optionally
    /// filtered by display name) and deliver real-time messages with their
    /// packet timestamps (mach units). Call once.
    public func connectClockInput(sourceName: String? = nil,
                                  handler: @escaping @Sendable (RealTimeMessage, UInt64) -> Void) {
        guard inputPort == 0 else { return }
        let status = MIDIInputPortCreateWithProtocol(client, "clock-in" as CFString,
                                                     ._1_0, &inputPort) { list, _ in
            for packet in list.unsafeSequence() {
                let timeStamp = packet.pointee.timeStamp
                for word in packet.words() {
                    switch word {
                    case 0x10F8_0000: handler(.clock, timeStamp)
                    case 0x10FA_0000: handler(.start, timeStamp)
                    case 0x10FB_0000: handler(.continuePlayback, timeStamp)
                    case 0x10FC_0000: handler(.stop, timeStamp)
                    default: break
                    }
                }
            }
        }
        guard status == noErr else { return }
        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            guard endpoint != sourceEndpoint else { continue }   // never self
            if let sourceName {
                var name: Unmanaged<CFString>?
                MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
                guard (name?.takeRetainedValue() as String?) == sourceName else { continue }
            }
            MIDIPortConnectSource(inputPort, endpoint, nil)
        }
    }

    // MARK: - Control input (FR-IO-10)

    private var controlEndpoint = MIDIEndpointRef()

    /// Publish a virtual DESTINATION for controllers ("Berlinan Control" in
    /// the app) and deliver CC/note-on triggers to the handler. Only the
    /// "press" edge fires: note-ons with velocity 0, note-offs, and CC values
    /// below 64 are ignored (pads on CC send value 0 on release — without the
    /// threshold every pad press would fire its macro twice).
    public func createControlInput(named name: String,
                                   handler: @escaping @Sendable (ControlTrigger) -> Void) {
        guard controlEndpoint == 0 else { return }
        MIDIDestinationCreateWithProtocol(client, name as CFString, ._1_0,
                                          &controlEndpoint) { list, _ in
            for packet in list.unsafeSequence() {
                for word in packet.words() {
                    let status = UInt8((word >> 16) & 0xFF)
                    let data1 = UInt8((word >> 8) & 0x7F)
                    let data2 = UInt8(word & 0x7F)
                    switch status & 0xF0 {
                    case 0xB0 where data2 >= 64:
                        handler(.cc(channel: status & 0x0F, number: data1))
                    case 0x90 where data2 > 0:
                        handler(.note(channel: status & 0x0F, number: data1))
                    default:
                        break
                    }
                }
            }
        }
    }

    // MARK: - Note-off safety net (FR-IO-8)

    /// Immediately silence everything sounding (optionally one channel):
    /// note-offs + CC 123, sent now.
    public func flush(channel: UInt8? = nil) {
        let offs = registry.flushEvents(channel: channel)
        guard !offs.isEmpty else { return }
        // Sending also re-tracks the offs, which is harmless (they remove).
        send(offs.map { (hostTime: 0, event: $0) })
    }
}
