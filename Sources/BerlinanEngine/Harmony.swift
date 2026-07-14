/// Global diatonic transposition — the style's primary harmony mechanism
/// (M §7.1; FR-H-1/2/3). Because pitches live in degree space (spec §6.2),
/// transposition is an integer ADD; the scale can never be left.

/// One transposition change. Bar-indexed BY CONSTRUCTION — the type cannot
/// express a mid-bar change (FR-H-3).
public struct TranspositionEvent: Codable, Equatable, Sendable {
    public var bar: Int
    /// Diatonic degree offset (−7…+7 covers the manual's progressions).
    public var degreeOffset: Int

    public init(bar: Int, degreeOffset: Int) {
        precondition(bar >= 0, "bar must be non-negative")
        self.bar = bar
        self.degreeOffset = degreeOffset
    }
}

/// A bar-indexed timeline of transposition offsets. Empty = pedal on the
/// root (FR-H-1). Progressions are expressed as event lists (M §7.1 —
/// "progressions as transposition sequences").
public struct TranspositionSchedule: Codable, Equatable, Sendable {
    /// Sorted by bar; for duplicate bars the later entry (in input order)
    /// wins and earlier ones are dropped.
    public private(set) var events: [TranspositionEvent]

    public init(events: [TranspositionEvent] = []) {
        // Last-wins per bar, then sort (stable keyed dedup).
        var byBar: [Int: TranspositionEvent] = [:]
        for event in events { byBar[event.bar] = event }
        self.events = byBar.values.sorted { $0.bar < $1.bar }
    }

    /// The offset in force at the given bar: the latest event at or before
    /// it, 0 before the first event.
    public func offset(atBar bar: Int) -> Int {
        var result = 0
        for event in events {
            if event.bar > bar { break }
            result = event.degreeOffset
        }
        return result
    }

    public static let pedal = TranspositionSchedule()
}

/// A MIDI-ready note: the output of the completed pitch pipeline
/// (degrees → transpose → resolve → register fold). Consumed by SMF export
/// (phase 08) and, later, the live scheduler (M2).
public struct RenderedNote: Equatable, Sendable {
    public var voiceID: String
    public var at: Tick
    public var midiNote: UInt8
    public var velocity: UInt8
    public var gate: Tick
    public var accent: Bool
    public var ratchet: Int

    public init(voiceID: String, at: Tick, midiNote: UInt8, velocity: UInt8,
                gate: Tick, accent: Bool, ratchet: Int) {
        self.voiceID = voiceID
        self.at = at
        self.midiNote = midiNote
        self.velocity = velocity
        self.gate = gate
        self.accent = accent
        self.ratchet = ratchet
    }
}

public enum HarmonyEngine {

    /// Where a change requested at `requestTick` lands (FR-H-3): the next
    /// boundary of the given quantum; a request exactly on a boundary binds
    /// to that boundary. Returns a bar index (always a multiple of
    /// `quantumBars`).
    public static func quantizedEventBar(requestTick: Tick, meter: Meter,
                                         quantumBars: Int = 1) -> Int {
        precondition(quantumBars >= 1)
        precondition(requestTick >= 0)
        let quantum = Tick(quantumBars) * meter.ticksPerBar
        let index = Tick(floorDiv(Int(requestTick + quantum - 1), Int(quantum)))
        return Int(index) * quantumBars
    }

    /// The complete note pipeline: ensemble stream → per-onset transposition
    /// (participating voices only, FR-H-2) → degree resolution → register
    /// fold. The offset binds per ONSET — notes sounding across a change keep
    /// their pitch (spec §7.5: no retuning mid-note).
    public static func render(voices: [Voice], schedule: TranspositionSchedule,
                              key: Key, meter: Meter,
                              in range: Range<Tick>) -> [RenderedNote] {
        let voicesByID = Dictionary(uniqueKeysWithValues: voices.map { ($0.id, $0) })
        return PhasingEngine.events(voices: voices, in: range).map { event in
            let voice = voicesByID[event.voiceID]!
            var pitch = event.note.pitch
            if voice.participatesInTransposition {
                let bar = Int(floorDiv(Int(event.at), Int(meter.ticksPerBar)))
                pitch.degree += schedule.offset(atBar: bar)
            }
            let resolved = key.resolve(pitch, referenceC: voice.referenceC)
            return RenderedNote(
                voiceID: event.voiceID,
                at: event.at,
                midiNote: voice.register.fold(resolved),
                velocity: event.note.velocity,
                gate: event.note.gate,
                accent: event.note.accent,
                ratchet: event.note.ratchet
            )
        }
    }
}
