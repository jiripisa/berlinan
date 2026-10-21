/// Active-note tracking — the runtime half of FR-IO-8. Every event sent
/// through the MIDIService is tracked here; on transport stop, mute, or
/// route change, `flushEvents` produces the note-offs (plus CC 123 as
/// belt-and-braces) that guarantee nothing keeps ringing.
///
/// Note-offs are sent ahead, timestamped, together with their note-ons
/// (lookahead scheduling), so a note counts as sounding until its note-off
/// TIME — not until the note-off was handed to CoreMIDI (audit #2).
public struct NoteRegistry: Sendable {

    private struct Key: Hashable { let channel: UInt8; let note: UInt8 }
    /// Sounding notes → host time of their scheduled note-off (`.max` while
    /// no note-off has been sent yet).
    private var sounding: [Key: UInt64] = [:]

    public init() {}

    public var activeCount: Int { sounding.count }

    /// Notes still sounding (or scheduled to) at host time `now`.
    public func activeCount(at now: UInt64) -> Int {
        sounding.values.filter { $0 > now }.count
    }

    /// Track an event sent with host-time timestamp `hostTime` (0 = now).
    public mutating func track(_ event: MIDI1Event, at hostTime: UInt64 = 0) {
        switch event {
        case let .noteOn(channel, note, _):
            sounding[Key(channel: channel, note: note)] = .max
        case let .noteOff(channel, note):
            let key = Key(channel: channel, note: note)
            if hostTime == 0 {
                sounding.removeValue(forKey: key)
            } else if sounding[key] != nil {
                sounding[key] = hostTime
            }
        default:
            break
        }
    }

    /// Note-offs for everything sounding or scheduled to sound at `now`
    /// (optionally one channel only) + CC 123 (All Notes Off) per touched
    /// channel; clears the tracked state.
    public mutating func flushEvents(channel: UInt8? = nil,
                                     now: UInt64 = 0) -> [MIDI1Event] {
        let touched = sounding.filter { channel == nil || $0.key.channel == channel }
        for key in touched.keys { sounding.removeValue(forKey: key) }
        let victims = touched.filter { $0.value > now }.map(\.key)
        guard !victims.isEmpty else { return [] }
        var events: [MIDI1Event] = victims
            .sorted { ($0.channel, $0.note) < ($1.channel, $1.note) }
            .map { .noteOff(channel: $0.channel, note: $0.note) }
        for ch in Set(victims.map(\.channel)).sorted() {
            events.append(.cc(channel: ch, controller: 123, value: 0))
        }
        return events
    }
}
