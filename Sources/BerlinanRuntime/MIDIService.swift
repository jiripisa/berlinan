import CoreMIDI

/// CoreMIDI virtual source + timestamped sending (FR-IO-1/2). One instance
/// owns one virtual source ("Berlinan Out" in the app) and can instead send
/// to one connected destination (phase 44). Sending and output switching
/// are serialized by a lock (the scheduler sends, the UI flushes/switches).
public final class MIDIService {

    public enum MIDIError: Error {
        case clientCreation(OSStatus)
        case sourceCreation(OSStatus)
    }

    private var client = MIDIClientRef()
    public private(set) var sourceEndpoint = MIDIEndpointRef()
    private var registry = NoteRegistry()
    private let sendLock = NSRecursiveLock()

    /// A connected MIDI destination (DIN interface, USB synth, IAC bus).
    public struct Destination: Hashable, Sendable {
        public let uniqueID: MIDIUniqueID
        public let name: String
    }

    private var outputPort = MIDIPortRef()
    /// nil = the virtual source; otherwise the chosen destination.
    private var destinationID: MIDIUniqueID? = nil

    /// Notes sounding right now or scheduled to (note-ons already sent).
    public var activeNoteCount: Int {
        sendLock.lock(); defer { sendLock.unlock() }
        return registry.activeCount(at: mach_absolute_time())
    }

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
        sendLock.lock(); defer { sendLock.unlock() }
        // Hot-plug (NFR-5): resolve the device per send; while it is gone the
        // events are dropped (still tracked, so a later flush stays correct).
        var target: MIDIEndpointRef? = nil
        if let destinationID {
            guard let endpoint = Self.destinationEndpoint(destinationID) else {
                events.forEach { registry.track($0.event, at: $0.hostTime) }
                return
            }
            target = endpoint
        }
        var buffer = [UInt8](repeating: 0, count: 4096)
        buffer.withUnsafeMutableBytes { raw in
            let listPtr = raw.baseAddress!.assumingMemoryBound(to: MIDIEventList.self)
            var packet = MIDIEventListInit(listPtr, ._1_0)
            for item in events {
                registry.track(item.event, at: item.hostTime)
                var word = item.event.umpWord
                packet = MIDIEventListAdd(listPtr, raw.count, packet,
                                          MIDITimeStamp(item.hostTime), 1, &word)
            }
            if let target {
                MIDISendEventList(outputPort, target, listPtr)
            } else {
                MIDIReceivedEventList(sourceEndpoint, listPtr)
            }
        }
    }

    // MARK: - Output choice (phase 44)

    /// Connected destinations, Berlinan's own control input excluded.
    public func destinations() -> [Destination] {
        (0..<MIDIGetNumberOfDestinations()).compactMap { index in
            let endpoint = MIDIGetDestination(index)
            guard endpoint != controlEndpoint else { return nil }
            var id: MIDIUniqueID = 0
            MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &id)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
            return Destination(uniqueID: id,
                               name: (name?.takeRetainedValue() as String?) ?? "MIDI \(id)")
        }
    }

    /// The chosen destination, nil while sending through the virtual source.
    public var outputDestinationID: MIDIUniqueID? {
        sendLock.lock(); defer { sendLock.unlock() }
        return destinationID
    }

    /// False while the chosen device is unplugged.
    public var isOutputAvailable: Bool {
        guard let id = outputDestinationID else { return true }
        return Self.destinationEndpoint(id) != nil
    }

    /// Send to a destination (nil = back to the virtual source). Whatever
    /// still sounds on the previous output gets its note-offs first.
    public func setOutput(_ uniqueID: MIDIUniqueID?) {
        sendLock.lock(); defer { sendLock.unlock() }
        guard uniqueID != destinationID else { return }
        flush()
        if uniqueID != nil && outputPort == 0 {
            MIDIOutputPortCreate(client, "out" as CFString, &outputPort)
        }
        destinationID = uniqueID
    }

    private static func destinationEndpoint(_ uniqueID: MIDIUniqueID) -> MIDIEndpointRef? {
        var object = MIDIObjectRef()
        var type = MIDIObjectType.other
        guard MIDIObjectFindByUniqueID(uniqueID, &object, &type) == noErr,
              type == .destination || type == .externalDestination
        else { return nil }
        return object
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

    /// Immediately silence everything sounding or scheduled to sound
    /// (optionally one channel): note-offs + CC 123, sent now — and once
    /// more after the scheduler's lookahead, for notes whose note-on was
    /// already queued with a future timestamp (audit #2).
    public func flush(channel: UInt8? = nil) {
        sendLock.lock(); defer { sendLock.unlock() }
        let now = mach_absolute_time()
        let offs = registry.flushEvents(channel: channel, now: now)
        guard !offs.isEmpty else { return }
        let afterQueued = now + Self.machTicks(nanos: Self.queuedHorizonNanos)
        // Sending re-tracks the offs, which is harmless (the notes are gone).
        send(offs.map { (hostTime: 0, event: $0) }
             + offs.map { (hostTime: afterQueued, event: $0) })
    }

    /// Covers the transport's preroll (100 ms) + lookahead (150 ms).
    private static let queuedHorizonNanos: Double = 300_000_000

    private static func machTicks(nanos: Double) -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return UInt64((nanos * Double(info.denom) / Double(info.numer)).rounded())
    }
}
