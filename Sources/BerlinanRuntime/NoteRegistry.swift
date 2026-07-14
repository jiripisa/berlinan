/// Active-note tracking — the runtime half of FR-IO-8. Every event sent
/// through the MIDIService is tracked here; on transport stop, mute, or
/// route change, `flushEvents` produces the note-offs (plus CC 123 as
/// belt-and-braces) that guarantee nothing keeps ringing.
public struct NoteRegistry: Sendable {

    private struct Key: Hashable { let channel: UInt8; let note: UInt8 }
    private var sounding = Set<Key>()

    public init() {}

    public var activeCount: Int { sounding.count }

    public mutating func track(_ event: MIDI1Event) {
        switch event {
        case let .noteOn(channel, note, _):
            sounding.insert(Key(channel: channel, note: note))
        case let .noteOff(channel, note):
            sounding.remove(Key(channel: channel, note: note))
        default:
            break
        }
    }

    /// Note-offs for everything sounding (optionally one channel only) +
    /// CC 123 (All Notes Off) per touched channel; clears the tracked state.
    public mutating func flushEvents(channel: UInt8? = nil) -> [MIDI1Event] {
        let victims = sounding.filter { channel == nil || $0.channel == channel }
        guard !victims.isEmpty else { return [] }
        var events: [MIDI1Event] = victims
            .sorted { ($0.channel, $0.note) < ($1.channel, $1.note) }
            .map { .noteOff(channel: $0.channel, note: $0.note) }
        for ch in Set(victims.map(\.channel)).sorted() {
            events.append(.cc(channel: ch, controller: 123, value: 0))
        }
        sounding.subtract(victims)
        return events
    }
}
