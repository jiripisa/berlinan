import BerlinanEngine

/// Pure conversion from the engine's note stream to timed MIDI events —
/// kept free of CoreMIDI so it is fully unit-testable.
public enum NoteEventConverter {

    public struct TimedEvent: Equatable, Sendable {
        public let tick: Tick
        public let event: MIDI1Event
    }

    /// On/off pairs for rendered notes. Offs may land beyond the render
    /// window — they are scheduled ahead with timestamps, which is exactly
    /// what the lookahead design wants (spec §8.2). Muted voices are dropped
    /// here: the runtime post-render gate (spec §8.2, ≤ 20 ms mute latency).
    public static func events(for notes: [RenderedNote],
                              channelMap: [String: UInt8],
                              muted: Set<String>) -> [TimedEvent] {
        var result: [TimedEvent] = []
        result.reserveCapacity(notes.count * 2)
        for note in notes {
            guard !muted.contains(note.voiceID),
                  let channel = channelMap[note.voiceID] else { continue }
            result.append(TimedEvent(tick: note.at,
                                     event: .noteOn(channel: channel,
                                                    note: note.midiNote,
                                                    velocity: note.velocity)))
            result.append(TimedEvent(tick: note.at + note.gate,
                                     event: .noteOff(channel: channel,
                                                     note: note.midiNote)))
        }
        return result
    }

    /// CC lane values → timed events (FR-MOD-3). CC follows the voice's
    /// channel; muting deliberately does NOT drop CC — mute is a note gate,
    /// knobs keep their positions consistent.
    public static func ccEvents(for ccs: [RenderedCC],
                                channelMap: [String: UInt8]) -> [TimedEvent] {
        ccs.compactMap { cc in
            channelMap[cc.voiceID].map {
                TimedEvent(tick: cc.at,
                           event: .cc(channel: $0, controller: cc.controller,
                                      value: cc.value))
            }
        }
    }

    /// 24-PPQ MIDI clock grid (FR-IO-3): one pulse every ppqn/24 = 40 ticks,
    /// half-open and seam-safe like every other window function.
    public static func clockTicks(in range: Range<Tick>) -> [Tick] {
        let spacing = Time.ppqn / 24
        guard range.lowerBound < range.upperBound else { return [] }
        let first = (range.lowerBound + spacing - 1) / spacing * spacing
        return stride(from: first, to: range.upperBound, by: Tick.Stride(spacing)).map { $0 }
    }
}
