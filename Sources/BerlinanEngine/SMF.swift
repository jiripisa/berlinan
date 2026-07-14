/// Standard MIDI File writer (FR-IO-6) — type 1, 960 PPQN, pure bytes.
/// Deterministic: identical inputs produce identical files (golden masters
/// compare bytes, spec §12.1).

public struct SMFTrack: Equatable, Sendable {
    public var name: String
    /// MIDI channel 0–15.
    public var channel: UInt8
    public var notes: [RenderedNote]
    /// CC automation (FR-MOD-3); emitted as 0xB0 events.
    public var ccs: [RenderedCC]

    public init(name: String, channel: UInt8, notes: [RenderedNote],
                ccs: [RenderedCC] = []) {
        precondition(channel <= 15, "MIDI channel must be 0–15")
        self.name = name
        self.channel = channel
        self.notes = notes
        self.ccs = ccs
    }
}

public enum SMFWriter {

    // MARK: Public API

    /// Encode a complete type-1 SMF. Track 0 carries tempo, time signature
    /// and markers; each `SMFTrack` becomes one voice track. All tracks end
    /// at `length` ticks so DAW imports line up.
    public static func encode(bpm: Double, meter: Meter, tracks: [SMFTrack],
                              length: Tick,
                              markers: [(at: Tick, label: String)] = []) -> [UInt8] {
        precondition(bpm > 0 && length > 0)
        var out: [UInt8] = []

        // Header chunk
        out += Array("MThd".utf8)
        out += uint32(6)
        out += uint16(1)                                  // format 1
        out += uint16(UInt16(tracks.count + 1))
        out += uint16(UInt16(Time.ppqn))                  // division 960

        out += tempoTrack(bpm: bpm, meter: meter, length: length, markers: markers)
        for track in tracks {
            out += voiceTrack(track, length: length)
        }
        return out
    }

    // MARK: Track 0 — tempo map

    private static func tempoTrack(bpm: Double, meter: Meter, length: Tick,
                                   markers: [(at: Tick, label: String)]) -> [UInt8] {
        var events: [UInt8] = []
        // Set tempo: microseconds per quarter note, rounded.
        let usPerQuarter = UInt32((60_000_000.0 / bpm).rounded())
        events += vlq(0) + [0xFF, 0x51, 0x03,
                            UInt8((usPerQuarter >> 16) & 0xFF),
                            UInt8((usPerQuarter >> 8) & 0xFF),
                            UInt8(usPerQuarter & 0xFF)]
        // Time signature: nn, dd = log2(denominator), 24 clocks/click,
        // 8 thirty-seconds per quarter.
        let dd: UInt8 = meter.beatUnit == 8 ? 3 : 2
        events += vlq(0) + [0xFF, 0x58, 0x04, UInt8(meter.beatsPerBar), dd, 0x18, 0x08]
        // Markers, time-sorted.
        var time: Tick = 0
        for marker in markers.sorted(by: { $0.at < $1.at }) {
            let text = Array(marker.label.utf8)
            events += vlq(marker.at - time) + [0xFF, 0x06] + vlq(Tick(text.count)) + text
            time = marker.at
        }
        events += endOfTrack(from: time, to: length)
        return chunk(events)
    }

    // MARK: Voice tracks

    // Same-tick ordering: offs → ccs (pre-strike values, spec §11.3) → ons.
    private enum EventKind: Int { case off = 0, cc = 1, on = 2 }

    private static func voiceTrack(_ track: SMFTrack, length: Tick) -> [UInt8] {
        var events: [UInt8] = []
        events += vlq(0) + [0xFF, 0x03] + vlq(Tick(track.name.utf8.count))
            + Array(track.name.utf8)

        // 1. Ratchet expansion (M §13.5): r retriggers across the gate,
        //    sub-gate ≈ 90% of the slice.
        var expanded: [(at: Tick, note: UInt8, velocity: UInt8, off: Tick)] = []
        for n in track.notes {
            if n.ratchet > 1 {
                let slice = max(1, n.gate / Tick(n.ratchet))
                for k in 0..<Tick(n.ratchet) {
                    let at = n.at + k * slice
                    let gate = max(1, slice * 9 / 10)
                    expanded.append((at, n.midiNote, n.velocity, at + gate))
                }
            } else {
                expanded.append((n.at, n.midiNote, n.velocity, n.at + n.gate))
            }
        }
        expanded.sort { $0.at < $1.at || ($0.at == $1.at && $0.note < $1.note) }

        // 2. Note-off integrity (FR-IO-8): clip a note's off to the next
        //    same-pitch onset so on/off pairs can never interleave.
        for i in expanded.indices {
            for j in (i + 1)..<expanded.count where expanded[j].note == expanded[i].note {
                expanded[i].off = min(expanded[i].off, expanded[j].at)
                break
            }
        }

        // 3. Emit with offs ordered before ons at equal ticks.
        var timed: [(tick: Tick, kind: EventKind, index: Int, bytes: [UInt8])] = []
        for (index, n) in expanded.enumerated() {
            timed.append((n.at, .on, index, [0x90 | track.channel, n.note, n.velocity]))
            timed.append((n.off, .off, index, [0x80 | track.channel, n.note, 0]))
        }
        for (index, cc) in track.ccs.enumerated() {
            timed.append((cc.at, .cc, expanded.count + index,
                          [0xB0 | track.channel, cc.controller, cc.value]))
        }
        timed.sort {
            if $0.tick != $1.tick { return $0.tick < $1.tick }
            if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
            return $0.index < $1.index
        }

        var time: Tick = 0
        for event in timed {
            events += vlq(event.tick - time) + event.bytes
            time = event.tick
        }
        events += endOfTrack(from: time, to: length)
        return chunk(events)
    }

    // MARK: Byte helpers

    /// Variable-length quantity (delta times, meta lengths).
    static func vlq(_ value: Tick) -> [UInt8] {
        precondition(value >= 0 && value <= 0x0FFF_FFFF, "VLQ out of range")
        var buffer: [UInt8] = [UInt8(value & 0x7F)]
        var rest = value >> 7
        while rest > 0 {
            buffer.append(UInt8(rest & 0x7F) | 0x80)
            rest >>= 7
        }
        return buffer.reversed()
    }

    private static func endOfTrack(from time: Tick, to length: Tick) -> [UInt8] {
        vlq(max(0, length - time)) + [0xFF, 0x2F, 0x00]
    }

    private static func chunk(_ events: [UInt8]) -> [UInt8] {
        Array("MTrk".utf8) + uint32(UInt32(events.count)) + events
    }

    private static func uint32(_ v: UInt32) -> [UInt8] {
        [UInt8(v >> 24), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    }

    private static func uint16(_ v: UInt16) -> [UInt8] {
        [UInt8(v >> 8), UInt8(v & 0xFF)]
    }
}
