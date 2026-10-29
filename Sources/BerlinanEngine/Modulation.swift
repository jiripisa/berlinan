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
    /// Direct CC number (phase 61); wins over `target`. nil = resolve
    /// `target` through the voice's CC map (documents before phase 61).
    public var controller: UInt8?
    /// Display name of the controlled parameter, e.g.
    /// "Arturia MicroFreak › Cutoff" (phase 61). nil = none.
    public var label: String?

    public init(target: String, shape: LFOShape, cycleBars: Double,
                depth: Double, center: Double, phase: Double = 0,
                preStrikeTicks: Tick = 10, controller: UInt8? = nil,
                label: String? = nil) {
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
        self.controller = controller
        self.label = label
    }
}

// MARK: - Editing (phase 61)

extension CCLane {
    /// FR-MOD-3: up to four lanes per voice.
    public static let maxPerVoice = 4

    /// A fresh lane for the editor: CC 74 (filter), then 71 (resonance),
    /// then 74 again; the demo's slow 16-bar breath, Min 57 / Max 95.
    public static func makeDefault(index: Int) -> CCLane {
        CCLane(target: "", shape: .sine, cycleBars: 16, depth: 0.3,
               center: 0.6, controller: index == 1 ? 71 : 74)
    }

    public func resolvedController(ccMap: [String: UInt8]) -> UInt8? {
        controller ?? ccMap[target]
    }

    /// Lower end of the swing in CC values (0–127).
    public var minValue: Int { Self.ccValue(center - depth / 2) }
    /// Upper end of the swing in CC values (0–127).
    public var maxValue: Int { Self.ccValue(center + depth / 2) }

    /// Swing between two CC values: clamped to 0–127, swapped when reversed.
    public mutating func setRange(min low: Int, max high: Int) {
        let a = Swift.max(0, Swift.min(127, low))
        let b = Swift.max(0, Swift.min(127, high))
        let (lo, hi) = a <= b ? (a, b) : (b, a)
        center = Double(lo + hi) / 254
        depth = Double(hi - lo) / 127
    }

    /// The depth knob: widen/narrow around the fixed center, never past
    /// 0 or 127.
    public mutating func setDepthKeepingCenter(_ newDepth: Double) {
        let limit = 2 * Swift.min(center, 1 - center)
        depth = Swift.max(0, Swift.min(newDepth, limit))
    }

    private static func ccValue(_ v01: Double) -> Int {
        Int((Swift.max(0, Swift.min(1, v01)) * 127).rounded())
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
    /// `syncTick`: the first emission point at or after it always emits,
    /// even when the value did not change — tick 0 for a fresh start, the
    /// bind tick of a live lane edit (phase 61) so the synth follows at once.
    public static func render(lanes: [CCLane], ccMap: [String: UInt8],
                              voiceID: String, in range: Range<Tick>,
                              meter: Meter, seed: UInt64,
                              syncTick: Tick = 0) -> [RenderedCC] {
        guard range.lowerBound < range.upperBound else { return [] }
        var result: [RenderedCC] = []
        for (laneIndex, lane) in lanes.enumerated() {
            guard let controller = lane.resolvedController(ccMap: ccMap) else { continue }
            switch lane.shape {
            case .sampleHold:
                result += sampleHold(lane, controller: controller, voiceID: voiceID,
                                     laneIndex: laneIndex, in: range, seed: seed,
                                     syncTick: syncTick)
            default:
                result += continuous(lane, controller: controller, voiceID: voiceID,
                                     in: range, meter: meter, syncTick: syncTick)
            }
        }
        result.sort { $0.at < $1.at || ($0.at == $1.at && $0.controller < $1.controller) }
        return result
    }

    // MARK: - Continuous shapes

    private static func continuous(_ lane: CCLane, controller: UInt8,
                                   voiceID: String, in range: Range<Tick>,
                                   meter: Meter, syncTick: Tick) -> [RenderedCC] {
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
        let syncGrid = (syncTick + gridTicks - 1) / gridTicks * gridTicks
        var tick = firstGrid
        while tick < range.upperBound {
            let v = value(at: tick)
            // Emit on change only; the sync point always emits (synth state sync).
            if tick == syncGrid || v != value(at: tick - gridTicks) {
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
                                   seed: UInt64, syncTick: Tick) -> [RenderedCC] {
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

        // The first step whose emission lands at or after the sync tick.
        let syncStep = syncTick <= 0
            ? 0
            : Int((syncTick + lane.preStrikeTicks + stepTicks - 1) / stepTicks)

        var result: [RenderedCC] = []
        var step = max(0, Int((range.lowerBound + lane.preStrikeTicks) / stepTicks))
        // Back up one step in case its (pre-strike) emission falls in range.
        step = max(0, step - 1)
        while true {
            let at = emission(ofStep: step)
            if at >= range.upperBound { break }
            if at >= range.lowerBound {
                let v = value(step: step)
                if step == syncStep || v != value(step: step - 1) {
                    result.append(RenderedCC(voiceID: voiceID, at: at,
                                             controller: controller, value: v))
                }
            }
            step += 1
        }
        return result
    }
}
