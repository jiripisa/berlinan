/// The phasing engine — the style's deterministic variation machine (M §6).

extension Pattern {

    /// Non-destructive length change (FR-P-3, M §6.1). Truncation drops notes
    /// at or beyond the new end — "cutting a note off mid-loop is fine";
    /// extension keeps everything and adds silence.
    public func withLength(_ newLength: Tick) -> Pattern {
        precondition(newLength > 0, "pattern length must be positive")
        var copy = self
        copy.length = newLength
        copy.notes = notes.filter { $0.position < newLength }
        copy.startOffset = Tick(floorMod(Int(startOffset), Int(newLength)))
        return copy
    }

    /// Start-point rotation as a copy (M §6.2). Composes with any existing
    /// offset; normalizes into 0..<length.
    public func rotated(by delta: Tick) -> Pattern {
        var copy = self
        copy.startOffset = Tick(floorMod(Int(startOffset + delta), Int(length)))
        return copy
    }
}

public enum PhasingOps {

    /// FR-PH-2 — the one-action "phase this voice" primitive: a copy of the
    /// pattern with a different loop length (typically −1 step / −1 bar,
    /// M §6.1 table) ready to be assigned to another voice (or back to the
    /// same one).
    public static func phasedCopy(of pattern: Pattern, newLength: Tick,
                                  idSuffix: String) -> Pattern {
        var copy = pattern.withLength(newLength)
        copy.id = "\(pattern.id)/\(idSuffix)"
        return copy
    }
}

// MARK: - Convergence (FR-PH-4)

public enum Convergence {

    /// LCM of the active loop lengths — the tick period after which all
    /// voices re-align. Returns nil on Int64 overflow, which the UI shows as
    /// "∞ (practically)" (spec §7.3).
    public static func period(lengths: [Tick]) -> Tick? {
        precondition(!lengths.isEmpty && lengths.allSatisfy { $0 > 0 })
        var acc: Tick = lengths[0]
        for len in lengths.dropFirst() {
            let g = gcd(acc, len)
            let (product, overflow) = (acc / g).multipliedReportingOverflow(by: len)
            if overflow { return nil }
            acc = product
        }
        return acc
    }

    /// Convergence period expressed in bars of the current meter.
    public static func bars(period: Tick, meter: Meter) -> Double {
        Double(period) / Double(meter.ticksPerBar)
    }

    /// Wall-clock length of the period at the current tempo.
    public static func seconds(period: Tick, bpm: Double) -> Double {
        Double(period) / Double(Time.ppqn) * 60.0 / bpm
    }
}

// MARK: - Multi-voice event stream (FR-PH-1)

/// One note onset of one voice in the merged ensemble stream.
public struct EnsembleEvent: Equatable, Sendable {
    public var voiceID: String
    public var at: Tick
    public var note: PatternNote
}

public enum PhasingEngine {

    /// Merged, time-sorted note onsets of all voices over a half-open global
    /// tick range. Each voice loops at its own length against the shared grid
    /// — this is the note-stream primitive that harmony (phase 07) and
    /// rendering (phases 08–09) transform further.
    public static func events(voices: [Voice], in range: Range<Tick>) -> [EnsembleEvent] {
        var result: [EnsembleEvent] = []
        for voice in voices {
            for occ in voice.pattern.occurrences(in: range) {
                result.append(EnsembleEvent(voiceID: voice.id, at: occ.at, note: occ.note))
            }
        }
        // Stable, fully deterministic order: time, then voice id, then loop
        // position (voices never share an id).
        result.sort {
            if $0.at != $1.at { return $0.at < $1.at }
            if $0.voiceID != $1.voiceID { return $0.voiceID < $1.voiceID }
            return $0.note.position < $1.note.position
        }
        return result
    }
}
