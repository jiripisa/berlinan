/// The project document (spec §6.6, M1 subset): everything the renderer
/// needs, JSON-encodable. Decoding happens in the CLI/app layer — the engine
/// only defines the Codable types.

public struct VoiceConfig: Codable, Equatable, Sendable {
    public var id: String
    public var role: VoiceRole
    public var register: RegisterWindow
    public var referenceC: Int
    public var generator: GeneratorConfig
    /// MIDI channel 0–15 (displayed 1-based).
    public var channel: UInt8
    /// FR-PH-2 in the document format: change the generated loop length by
    /// this many 16th steps (e.g. −1 → a 15-step copy of a 16-step pattern).
    public var phaseSteps: Int?
    public var anchorPolicy: AnchorPolicy?
    public var participatesInTransposition: Bool?
    /// CC modulation lanes (FR-MOD-3); targets resolved via `ccMap`.
    public var ccLanes: [CCLane]?
    /// Named CC targets → controller numbers (FR-MOD-5), e.g. "filter": 74.
    public var ccMap: [String: UInt8]?
    /// Gate-length arc (FR-MOD-2).
    public var gateRamp: GateRampProgram?
    /// Metropolix-style per-cycle drift (FR-L-4).
    public var accumulator: AccumulatorConfig?
    /// Hand-edited pattern (FR-P-7): used verbatim (locked) instead of the
    /// generator when present — hand edits survive in the document.
    public var overridePattern: Pattern?
    /// MIDI delay (FR-MOD-7); nil = off.
    public var midiDelay: MIDIDelayConfig?

    public init(id: String, role: VoiceRole, register: RegisterWindow,
                referenceC: Int, generator: GeneratorConfig, channel: UInt8,
                phaseSteps: Int? = nil, anchorPolicy: AnchorPolicy? = nil,
                participatesInTransposition: Bool? = nil,
                ccLanes: [CCLane]? = nil, ccMap: [String: UInt8]? = nil,
                gateRamp: GateRampProgram? = nil,
                accumulator: AccumulatorConfig? = nil,
                overridePattern: Pattern? = nil,
                midiDelay: MIDIDelayConfig? = nil) {
        self.id = id
        self.role = role
        self.register = register
        self.referenceC = referenceC
        self.generator = generator
        self.channel = channel
        self.phaseSteps = phaseSteps
        self.anchorPolicy = anchorPolicy
        self.participatesInTransposition = participatesInTransposition
        self.ccLanes = ccLanes
        self.ccMap = ccMap
        self.gateRamp = gateRamp
        self.accumulator = accumulator
        self.overridePattern = overridePattern
        self.midiDelay = midiDelay
    }
}

/// Metropolix-style accumulator (FR-L-4, M §13.5): at every loop boundary the
/// LAST sounding note drifts by `degreeStep` degrees, wrapping to the base
/// after `wrap` cycles. Deterministic drift — the manual's endorsed
/// "persistent variation" — and therefore exempt from the verbatim rule.
public struct AccumulatorConfig: Codable, Equatable, Sendable {
    public var degreeStep: Int
    public var wrap: Int

    public init(degreeStep: Int, wrap: Int) {
        precondition((-2...2).contains(degreeStep) && degreeStep != 0)
        precondition((2...16).contains(wrap))
        self.degreeStep = degreeStep
        self.wrap = wrap
    }
}

public struct Project: Codable, Equatable, Sendable {
    public var formatVersion: Int
    public var masterSeed: UInt64
    public var bpm: Double
    public var key: Key
    public var meter: Meter
    public var voices: [VoiceConfig]
    /// Legacy hand-written schedule; used when `harmony` is nil.
    public var transposition: TranspositionSchedule
    /// Harmony mode (FR-H-4/5/6). nil = the legacy schedule above, so 0.2.0
    /// project files stay valid.
    public var harmony: HarmonyModeConfig?
    public var legitimization: Legitimizer.Config?
    public var velocity: VelocityPolicy?
    /// Persisted snapshot slots (FR-L-6, spec §6.6).
    public var snapshots: [LiveEngine.StateSnapshot?]?
    /// Arrangement autopilot (FR-A-1/2/6). nil = disabled (performance
    /// mode); 1.0 documents stay valid.
    public var arrangement: ArrangementConfig?
    /// Density macro seed value (FR-A-3); nil = 1.0 (full density).
    public var density: Double?
    /// B-part bundle configuration (FR-A-5); nil = the default S4 move.
    public var bPart: BPartConfig?
    /// Alternating phrase scheduler (FR-MEL-3); nil = off.
    public var alternating: AlternatingConfig?
    /// Tension budget (FR-H-7): out-of-key allowances per piece; nil = 2.
    public var tensionBudget: Int?
    /// Slides (phase 33): lets mutations set/clear tie steps on bass and
    /// lead voices. nil/false = the pre-1.2 mutation stream, byte-identical.
    public var slidesEnabled: Bool?
    /// CC scenes (phase 34): named timbre destinations. nil = none.
    public var ccScenes: [CCScene]?
    /// Arranger phase → scene name (phase 34); fires an 8-bar morph on the
    /// transition into the phase. nil = the arranger leaves CC alone.
    public var sceneByPhase: [String: String]?

    public init(formatVersion: Int = 1, masterSeed: UInt64, bpm: Double,
                key: Key, meter: Meter, voices: [VoiceConfig],
                transposition: TranspositionSchedule = .pedal,
                harmony: HarmonyModeConfig? = nil,
                legitimization: Legitimizer.Config? = nil,
                velocity: VelocityPolicy? = nil,
                snapshots: [LiveEngine.StateSnapshot?]? = nil,
                arrangement: ArrangementConfig? = nil) {
        self.formatVersion = formatVersion
        self.masterSeed = masterSeed
        self.bpm = bpm
        self.key = key
        self.meter = meter
        self.voices = voices
        self.transposition = transposition
        self.harmony = harmony
        self.legitimization = legitimization
        self.velocity = velocity
        self.snapshots = snapshots
        self.arrangement = arrangement
    }
}

extension Project {

    /// The default 3-voice Berlin School template (FR-V-2, M §16 defaults):
    /// two phasing bed plucks (16 vs 15 steps), a pulsing bass, and an
    /// i→VI→iv→i→v→i transposition walk at 90 BPM in C minor. Also serves as
    /// the golden-master fixture and the `berlinan-cli demo` output.
    public static let demo = Project(
        formatVersion: 1,
        masterSeed: 0xBE12_71A9,
        bpm: 90,
        key: Key.default,
        meter: .fourFour,
        voices: [
            VoiceConfig(id: "bedPluck1", role: .bedPluck1,
                        register: RegisterWindow(low: 55, high: 79), referenceC: 60,
                        generator: .seedProcedure(bars: 1, mutations: 4), channel: 0,
                        // A slow filter breath (M §11.2 — 16-bar cycle).
                        ccLanes: [CCLane(target: "filter", shape: .sine,
                                         cycleBars: 16, depth: 0.3, center: 0.6)],
                        ccMap: ["filter": 74]),
            VoiceConfig(id: "bedPluck2", role: .bedPluck2,
                        register: RegisterWindow(low: 60, high: 84), referenceC: 60,
                        generator: .seedProcedure(bars: 1, mutations: 4), channel: 1,
                        phaseSteps: -1),
            VoiceConfig(id: "bass", role: .bass,
                        register: RegisterWindow(low: 24, high: 48), referenceC: 36,
                        generator: .pulsingBass(accents: 3), channel: 2,
                        anchorPolicy: .beats1and3),
        ],
        transposition: TranspositionSchedule(events: [
            TranspositionEvent(bar: 8, degreeOffset: 5),
            TranspositionEvent(bar: 12, degreeOffset: 3),
            TranspositionEvent(bar: 16, degreeOffset: 0),
            TranspositionEvent(bar: 24, degreeOffset: 4),
            TranspositionEvent(bar: 28, degreeOffset: 0),
        ])
    )

    /// The full 1.1 palette (phase 36; mirrors examples/full_ensemble):
    /// two beds, a bass-melody walk, a chord-layer pad, a lead ready for
    /// melody promotion, and the heartbeat kick.
    public static let fullEnsemble: Project = {
        var p = Project.demo
        p.bpm = 96
        p.masterSeed = 2_477_861_893
        p.voices[2] = VoiceConfig(id: "bass", role: .bass,
                                  register: RegisterWindow(low: 24, high: 48),
                                  referenceC: 36,
                                  generator: .bassMelody(bars: 16), channel: 2)
        p.voices.append(VoiceConfig(
            id: "pad", role: .pad,
            register: RegisterWindow(low: 48, high: 72), referenceC: 60,
            generator: .chordLayer(periodBars: 7), channel: 3,
            ccLanes: [CCLane(target: "filter", shape: .sine,
                             cycleBars: 32, depth: 0.4, center: 0.5)],
            ccMap: ["filter": 74]))
        p.voices.append(VoiceConfig(
            id: "lead", role: .lead,
            register: RegisterWindow(low: 60, high: 96), referenceC: 72,
            generator: .stagedPluck(bars: 2), channel: 4))
        p.voices.append(VoiceConfig(
            id: "kick", role: .rhythm,
            register: RegisterWindow(low: 36, high: 47), referenceC: 36,
            generator: .heartbeat, channel: 9))
        return p
    }()

    /// The generative radio (phase 36): a drone-led, ambient-arranged
    /// setup with a timbre journey mapped to the arranger's phases.
    public static let ambientDrift: Project = {
        var p = Project(
            formatVersion: 1,
            masterSeed: 0x0A3B_11ED,
            bpm: 72,
            key: Key.default,
            meter: .fourFour,
            voices: [
                VoiceConfig(id: "drone", role: .drone,
                            register: RegisterWindow(low: 36, high: 60),
                            referenceC: 48,
                            generator: .drone(bars: 8), channel: 0,
                            ccMap: ["filter": 74]),
                VoiceConfig(id: "bedPluck1", role: .bedPluck1,
                            register: RegisterWindow(low: 55, high: 79),
                            referenceC: 60,
                            generator: .seedProcedure(bars: 1, mutations: 3),
                            channel: 1,
                            ccMap: ["filter": 74]),
                VoiceConfig(id: "bedPluck2", role: .bedPluck2,
                            register: RegisterWindow(low: 60, high: 84),
                            referenceC: 60,
                            generator: .seedProcedure(bars: 1, mutations: 3),
                            channel: 2, phaseSteps: -1,
                            ccMap: ["filter": 74]),
                VoiceConfig(id: "pad", role: .pad,
                            register: RegisterWindow(low: 48, high: 72),
                            referenceC: 60,
                            generator: .chordLayer(periodBars: 7), channel: 3,
                            ccMap: ["filter": 74]),
            ],
            transposition: .pedal)
        p.arrangement = .ambientPlateau
        p.ccScenes = [
            CCScene(name: "closed", values: [
                "drone": ["filter": 0.25], "bedPluck1": ["filter": 0.3],
                "bedPluck2": ["filter": 0.3], "pad": ["filter": 0.2],
            ]),
            CCScene(name: "open", values: [
                "drone": ["filter": 0.6], "bedPluck1": ["filter": 0.75],
                "bedPluck2": ["filter": 0.75], "pad": ["filter": 0.65],
            ]),
        ]
        p.sceneByPhase = ["bed": "closed", "payoff": "open",
                          "subtract": "closed"]
        return p
    }()
}
