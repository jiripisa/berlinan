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
