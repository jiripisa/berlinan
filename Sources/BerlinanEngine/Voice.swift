/// Voice roles per the manual's architecture (M §10.1).
public enum VoiceRole: String, Codable, CaseIterable, Sendable {
    case bedPluck1, bedPluck2, bass, pad, lead, drone, rhythm, aux

    /// The name a musician reads in the UI (FR-UX-7). The raw value stays
    /// the document/export identifier.
    public var displayName: String {
        switch self {
        case .bedPluck1: "Pluck 1"
        case .bedPluck2: "Pluck 2"
        case .bass:      "Bass"
        case .pad:       "Pad"
        case .lead:      "Lead"
        case .drone:     "Drone"
        case .rhythm:    "Heartbeat"
        case .aux:       "Aux"
        }
    }
}

/// UI labels for a list of voices (FR-UX-7): voice id → role name. A role
/// used by several voices is numbered in document order ("Lead 1",
/// "Lead 2") so labels never collide.
public enum VoiceLabels {
    public static func make(_ voices: [(id: String, role: VoiceRole)]) -> [String: String] {
        var counts: [VoiceRole: Int] = [:]
        for voice in voices { counts[voice.role, default: 0] += 1 }
        var seen: [VoiceRole: Int] = [:]
        var labels: [String: String] = [:]
        for voice in voices {
            let name = voice.role.displayName
            if counts[voice.role, default: 0] > 1 {
                seen[voice.role, default: 0] += 1
                labels[voice.id] = "\(name) \(seen[voice.role]!)"
            } else {
                labels[voice.id] = name
            }
        }
        return labels
    }
}

/// The bass anchor rule (FR-V-5, M §6.6): while phasing runs, the bass
/// guarantees onsets on beats 1 and 3 so the listener never loses the meter.
public enum AnchorPolicy: String, Codable, Sendable {
    case beats1and3
    case beat1
    case none

    /// Local ticks within one bar that must carry an onset.
    public func requiredLocalTicks(meter: Meter) -> [Tick] {
        switch self {
        case .none:
            return []
        case .beat1:
            return [0]
        case .beats1and3:
            // "Beat 3" = halfway through a 4-beat bar (2 beats in). For meters
            // with fewer than 3 beats fall back to the downbeat only.
            return meter.beatsPerBar >= 3 ? [0, 2 * meter.ticksPerBeat] : [0]
        }
    }
}

/// One output lane with a musical role (spec §6.3). This is the ENGINE view
/// of a voice — MIDI routing, CC maps, and modulation lanes are added by
/// later phases/the runtime layer; keeping them out here keeps the engine
/// dependency-free and the document format growable.
public struct Voice: Codable, Equatable, Sendable {
    public var id: String
    public var role: VoiceRole
    /// Register window with octave fold (FR-V-3).
    public var register: RegisterWindow
    /// MIDI note of this voice's reference C (combines the spec's refC +
    /// refOctave into one number; e.g. bass 36, bed 60).
    public var referenceC: Int
    public var pattern: Pattern
    /// Per-voice opt-out from global transposition (M §7.1 — e.g. the lead
    /// keeps improvising in the home key while the bed transposes).
    public var participatesInTransposition: Bool
    public var anchorPolicy: AnchorPolicy
    /// Hard cap of notes per bar (M Law 3, FR-V-6). nil = role default.
    public var densityCap: Int?

    public init(id: String, role: VoiceRole, register: RegisterWindow,
                referenceC: Int, pattern: Pattern,
                participatesInTransposition: Bool = true,
                anchorPolicy: AnchorPolicy = .none, densityCap: Int? = nil) {
        precondition((0...127).contains(referenceC), "referenceC must be a MIDI note")
        self.id = id
        self.role = role
        self.register = register
        self.referenceC = referenceC
        self.pattern = pattern
        self.participatesInTransposition = participatesInTransposition
        self.anchorPolicy = anchorPolicy
        self.densityCap = densityCap
    }

    /// FR-V-5 check, rotation-aware. The pattern loops at its own length while
    /// bars repeat at the meter's length, so anchors are verified at every
    /// required tick across one full LCM(patternLength, barLength) cycle —
    /// a sub-bar or odd-length loop only passes if EVERY bar's anchors are hit.
    public func satisfiesAnchor(meter: Meter) -> Bool {
        let required = anchorPolicy.requiredLocalTicks(meter: meter)
        guard !required.isEmpty else { return true }
        let cycle = lcm(pattern.length, meter.ticksPerBar)
        let bars = cycle / meter.ticksPerBar
        for barIndex in 0..<bars {
            for tick in required {
                if !pattern.hasOnset(atGlobalTick: barIndex * meter.ticksPerBar + tick) {
                    return false
                }
            }
        }
        return true
    }
}
