/// MIDI delay (FR-MOD-7, spec §7.7): the style's signature echo emitted as
/// real MIDI notes — for setups without an audio delay effect. Default OFF;
/// an audio delay in the DAW remains the recommended, higher-fidelity path
/// (the hint warns when both would stack, FR-MOD-8).

extension DelayDivision {
    /// Quarter-based musical ticks (independent of the meter's beat unit).
    public var ticks: Tick {
        switch self {
        case .dotted8th: return Time.ppqn * 3 / 4    // 720
        case .eighth:    return Time.ppqn / 2        // 480
        case .quarter:   return Time.ppqn            // 960
        }
    }
}

public struct MIDIDelayConfig: Codable, Equatable, Sendable {
    /// Default OFF — the audio-delay path stays primary.
    public var enabled: Bool
    public var division: DelayDivision
    /// 1–8 repeats (default 3).
    public var repeats: Int
    /// Per-repeat velocity multiplier (~50% feedback ≈ 0.55).
    public var velocityDecay: Double
    /// Per-repeat gate multiplier.
    public var gateScale: Double

    public init(enabled: Bool = false, division: DelayDivision = .dotted8th,
                repeats: Int = 3, velocityDecay: Double = 0.55,
                gateScale: Double = 0.9) {
        precondition((1...8).contains(repeats))
        precondition((0.3...0.9).contains(velocityDecay))
        precondition((0.5...1.0).contains(gateScale))
        self.enabled = enabled
        self.division = division
        self.repeats = repeats
        self.velocityDecay = velocityDecay
        self.gateScale = gateScale
    }
}

public enum MIDIDelay {

    /// Echoes below this velocity are cut (inaudible tail, spec §7.7).
    static let velocityCutoff: UInt8 = 8

    /// Expand a rendered stream with echo notes. Echoes are tagged, derived
    /// data: the function is idempotent (existing echoes are recomputed from
    /// the sources, never re-echoed). They exist ONLY at the output/export
    /// boundary — patterns, lifecycle, phasing and convergence never see them.
    public static func process(_ notes: [RenderedNote],
                               config: MIDIDelayConfig) -> [RenderedNote] {
        guard config.enabled else { return notes }
        let sources = notes.filter { !$0.isEcho }
        var out = sources
        for source in sources {
            var velocity = Double(source.velocity)
            var gate = Double(source.gate)
            for k in 1...config.repeats {
                velocity = (velocity * config.velocityDecay).rounded()
                gate = max(1, gate * config.gateScale)
                guard velocity >= Double(velocityCutoff) else { break }
                var echo = source
                echo.at = source.at + Tick(k) * config.division.ticks
                echo.velocity = UInt8(velocity)
                echo.gate = Tick(gate)
                echo.isEcho = true
                out.append(echo)
            }
        }
        out.sort {
            if $0.at != $1.at { return $0.at < $1.at }
            if $0.voiceID != $1.voiceID { return $0.voiceID < $1.voiceID }
            return $0.velocity > $1.velocity      // originals before echoes
        }
        return out
    }
}
