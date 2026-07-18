import func Darwin.sin

/// Modulation output (M §11; FR-MOD-2/3/4/5): the sequencer emits CC lanes
/// and gate-length arcs as compositional data. All rates live in MUSICAL time
/// (bars), never Hz — the manual's slow-LFO doctrine ties timbre cycles to
/// 8/16/32-bar units (M §11.2).

public enum LFOShape: String, Codable, Sendable {
    case sine, triangle, sawUp, sawDown, square, sampleHold
}

public struct CCLane: Codable, Equatable, Sendable {
    /// Named target resolved through the voice's CC map (FR-MOD-5),
    /// e.g. "filter" → CC 74. Unmapped lanes are skipped.
    public var target: String
    public var shape: LFOShape
    /// Cycle length in bars, 0.5–64 (M §11.2).
    public var cycleBars: Double
    /// Full swing 0–1 of the CC range.
    public var depth: Double
    /// Center 0–1.
    public var center: Double
    /// Phase offset 0..<1.
    public var phase: Double
    /// S&H values land this many ticks BEFORE the step onset (M §11.3).
    public var preStrikeTicks: Tick

    public init(target: String, shape: LFOShape, cycleBars: Double,
                depth: Double, center: Double, phase: Double = 0,
                preStrikeTicks: Tick = 10) {
        precondition((0.5...64).contains(cycleBars))
        precondition((0...1).contains(depth) && (0...1).contains(center))
        precondition((0..<1).contains(phase))
        precondition(preStrikeTicks >= 0)
        self.target = target
        self.shape = shape
        self.cycleBars = cycleBars
        self.depth = depth
        self.center = center
        self.phase = phase
        self.preStrikeTicks = preStrikeTicks
    }
}

/// Gate-length arc (FR-MOD-2, M §11.4): per-bar gate multipliers — note
/// duration alone sweeps the timbre against a slow-release filter envelope.
public struct GateRampProgram: Codable, Equatable, Sendable {
    /// One multiplier per bar, cycled; 0.25–4.0.
    public var profile: [Double]

    public var arcBars: Int { profile.count }

    public init(profile: [Double]) {
        precondition(!profile.isEmpty)
        precondition(profile.allSatisfy { (0.25...4.0).contains($0) })
        self.profile = profile
    }
}

/// A named timbre destination (phase 34, M §11): per-voice CC target
/// values, morphed over bars by `.morphToScene` or the arranger's phase map.
public struct CCScene: Codable, Equatable, Sendable {
    public var name: String
    /// voiceID → CC-map target name → 0–1.
    public var values: [String: [String: Double]]

    public init(name: String, values: [String: [String: Double]]) {
        self.name = name
        self.values = values
    }
}

public struct RenderedCC: Equatable, Sendable {
    public var voiceID: String
    public var at: Tick
    public var controller: UInt8
    public var value: UInt8

    public init(voiceID: String, at: Tick, controller: UInt8, value: UInt8) {
        self.voiceID = voiceID
        self.at = at
        self.controller = controller
        self.value = value
    }
}

public enum ModulationEngine {

    /// Emission grid: one value per lane per 1/96 note (FR-MOD-4).
    static let gridTicks: Tick = Time.ppqn / 24        // 40

    /// Render a voice's CC lanes over a half-open window. Chunk-safe by
    /// construction: the delta filter compares against the PREVIOUS grid
    /// point's computed value (stateless), so chained windows reproduce the
    /// whole-range stream exactly.
    public static func render(lanes: [CCLane], ccMap: [String: UInt8],
                              voiceID: String, in range: Range<Tick>,
                              meter: Meter, seed: UInt64) -> [RenderedCC] {
        guard range.lowerBound < range.upperBound else { return [] }
        var result: [RenderedCC] = []
        for (laneIndex, lane) in lanes.enumerated() {
            guard let controller = ccMap[lane.target] else { continue }
            switch lane.shape {
            case .sampleHold:
                result += sampleHold(lane, controller: controller, voiceID: voiceID,
                                     laneIndex: laneIndex, in: range, seed: seed)
            default:
                result += continuous(lane, controller: controller, voiceID: voiceID,
                                     in: range, meter: meter)
            }
        }
        result.sort { $0.at < $1.at || ($0.at == $1.at && $0.controller < $1.controller) }
        return result
    }

    // MARK: - Continuous shapes

    private static func continuous(_ lane: CCLane, controller: UInt8,
                                   voiceID: String, in range: Range<Tick>,
                                   meter: Meter) -> [RenderedCC] {
        let cycleTicks = lane.cycleBars * Double(meter.ticksPerBar)

        func value(at tick: Tick) -> UInt8 {
            var x = (Double(tick) / cycleTicks + lane.phase)
                .truncatingRemainder(dividingBy: 1)
            if x < 0 { x += 1 }
            let wave: Double
            switch lane.shape {
            case .sine:     wave = sin(2 * .pi * x)
            case .triangle: wave = x < 0.5 ? 4 * x - 1 : 3 - 4 * x
            case .sawUp:    wave = 2 * x - 1
            case .sawDown:  wave = 1 - 2 * x
            case .square:   wave = x < 0.5 ? 1 : -1
            case .sampleHold: preconditionFailure("handled separately")
            }
            let v01 = max(0, min(1, lane.center + lane.depth / 2 * wave))
            return UInt8((v01 * 127).rounded())
        }

        var result: [RenderedCC] = []
        let firstGrid = (range.lowerBound + gridTicks - 1) / gridTicks * gridTicks
        var tick = firstGrid
        while tick < range.upperBound {
            let v = value(at: tick)
            // Emit on change only; tick 0 always emits (synth state sync).
            if tick == 0 || v != value(at: tick - gridTicks) {
                result.append(RenderedCC(voiceID: voiceID, at: tick,
                                         controller: controller, value: v))
            }
            tick += gridTicks
        }
        return result
    }

    // MARK: - Sample & hold (M §11.3)

    private static func sampleHold(_ lane: CCLane, controller: UInt8,
                                   voiceID: String, laneIndex: Int,
                                   in range: Range<Tick>,
                                   seed: UInt64) -> [RenderedCC] {
        let stepTicks = Time.ppqn / 2                   // 8th-note steps

        func value(step: Int) -> UInt8 {
            let roll = SeedStream.derive(master: seed, "cc", String(laneIndex),
                                         "sh", String(step))
            let uniform = Double(roll % 100_000) / 100_000.0
            let v01 = max(0, min(1, lane.center + lane.depth * (uniform - 0.5)))
            return UInt8((v01 * 127).rounded())
        }

        // Emission time of step k: k·step − preStrike (clamped at 0).
        func emission(ofStep step: Int) -> Tick {
            max(0, Tick(step) * stepTicks - lane.preStrikeTicks)
        }

        var result: [RenderedCC] = []
        var step = max(0, Int((range.lowerBound + lane.preStrikeTicks) / stepTicks))
        // Back up one step in case its (pre-strike) emission falls in range.
        step = max(0, step - 1)
        while true {
            let at = emission(ofStep: step)
            if at >= range.upperBound { break }
            if at >= range.lowerBound {
                let v = value(step: step)
                if step == 0 || v != value(step: step - 1) {
                    result.append(RenderedCC(voiceID: voiceID, at: at,
                                             controller: controller, value: v))
                }
            }
            step += 1
        }
        return result
    }
}
