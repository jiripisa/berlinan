/// Offline (headless) render loop — M1's deliverable. Runs the authentic
/// Berlinan cycle per voice: generate → play N verbatim loops → mutate →
/// repeat (Law 1), against the shared transposition schedule, then encodes
/// the result as an SMF.
public enum OfflineRenderer {

    /// Full render to SMF bytes.
    public static func render(project: Project, bars: Int) -> [UInt8] {
        let total = Tick(bars) * project.meter.ticksPerBar
        let resolved = HarmonyScheduler.resolve(project: project)
        var tracks: [SMFTrack] = []
        for config in project.voices {
            let notes = renderVoice(config, project: project, total: total)
            let ccs = ModulationEngine.render(
                lanes: config.ccLanes ?? [], ccMap: config.ccMap ?? [:],
                voiceID: config.id, in: 0..<total, meter: project.meter,
                seed: SeedStream.derive(master: project.masterSeed,
                                        "voice", config.id, "cc"))
            let hint = DelayHint.compute(role: config.role, bpm: project.bpm)
            tracks.append(SMFTrack(
                name: "\(config.id) | ch\(config.channel + 1) | \(config.role.rawValue) | delay: \(hint.division.label)",
                channel: config.channel,
                notes: notes,
                ccs: ccs
            ))
        }
        let markers = resolved.schedule.events
            .filter { Tick($0.bar) * project.meter.ticksPerBar < total }
            .map { (at: Tick($0.bar) * project.meter.ticksPerBar,
                    label: "HARM:\($0.degreeOffset >= 0 ? "+" : "")\($0.degreeOffset)") }
        return SMFWriter.encode(bpm: project.bpm, meter: project.meter,
                                tracks: tracks, length: total, markers: markers)
    }

    /// Note-level render across all voices (test/inspection surface).
    public static func renderNotes(project: Project, bars: Int) -> [RenderedNote] {
        let total = Tick(bars) * project.meter.ticksPerBar
        return project.voices.flatMap { renderVoice($0, project: project, total: total) }
            .sorted { $0.at < $1.at || ($0.at == $1.at && $0.voiceID < $1.voiceID) }
    }

    // MARK: - Per-voice loop

    private static func renderVoice(_ config: VoiceConfig, project: Project,
                                    total: Tick) -> [RenderedNote] {
        let legit = project.legitimization ?? .default
        let velocity = project.velocity ?? VelocityPolicy()
        let resolved = HarmonyScheduler.resolve(project: project)
        var voice = materialize(config, project: project)
        // Bass-reharm participation mask (FR-H-6): uppers frozen, bass follows.
        let stretchBassGates = resolved.bassOnly && voice.role == .bass
        var generation = 1
        var accumBase: Int? = nil
        var accumCycle = 0
        var notes: [RenderedNote] = []
        var t: Tick = 0

        while t < total {
            let segmentEnd = min(t + voice.pattern.length, total)
            let humanSeed = voice.pattern.provenance.seed
            let segment = HarmonyEngine.render(voices: [voice],
                                               schedule: resolved.schedule,
                                               key: project.key,
                                               meter: project.meter,
                                               in: t..<segmentEnd)
            notes += segment.map { n in
                var out = n
                let local = Tick(floorMod(Int(n.at + voice.pattern.startOffset),
                                          Int(voice.pattern.length)))
                out.velocity = velocity.apply(velocity: n.velocity, accent: n.accent,
                                              patternSeed: humanSeed,
                                              localPosition: local)
                if let ramp = config.gateRamp {
                    // Gate arc (FR-MOD-2, M §11.4): duration alone sweeps the
                    // timbre against a slow-release filter envelope.
                    let barIndex = Int(n.at / project.meter.ticksPerBar)
                    let multiplier = ramp.profile[barIndex % ramp.profile.count]
                    out.gate = max(1, Tick(Double(out.gate) * multiplier))
                }
                if stretchBassGates {
                    // Held roots under a reharm walk (M §7.2); same-pitch
                    // overlaps are clipped at the SMF/send layer.
                    out.gate = max(out.gate, project.meter.ticksPerBeat)
                }
                return out
            }

            // Loop boundary: lifecycle countdown, then mutate when allowed
            // (the change binds at the boundary — spec §7.4).
            t += voice.pattern.length
            voice.pattern = Legitimizer.advanceAtLoopBoundary(voice.pattern)
            if Legitimizer.isMutable(voice.pattern) {
                let seed = SeedStream.derive(master: project.masterSeed,
                                             "voice", config.id, "mut", String(generation))
                voice = Legitimizer.mutate(voice, key: project.key,
                                           meter: project.meter, seed: seed,
                                           config: legit)
                generation += 1
                // Mutation replaces the material — the drift restarts.
                accumBase = nil
                accumCycle = 0
            }
            if let accumulator = config.accumulator {
                if accumBase == nil {
                    accumBase = Legitimizer.accumulatorBase(of: voice.pattern)
                    accumCycle = 0
                }
                accumCycle += 1
                Legitimizer.applyAccumulatorDrift(&voice.pattern, base: accumBase!,
                                                  cycle: accumCycle, config: accumulator)
            }
        }
        return notes
    }

    /// Generate a fresh pattern for a voice config (shared with LiveEngine —
    /// regeneration uses different seed labels but the identical build path).
    static func makePattern(_ config: VoiceConfig, project: Project,
                            seedLabels: [String], idSuffix: String) -> Pattern {
        let seed = SeedStream.derive(master: project.masterSeed, labels: seedLabels)
        var pattern = PatternFactory.make(id: "\(config.id)/\(idSuffix)",
                                          config: config.generator,
                                          role: config.role, key: project.key,
                                          meter: project.meter, seed: seed)
        if let steps = config.phaseSteps, steps != 0 {
            let delta = Tick(steps) * (project.meter.ticksPerBeat / 4)
            pattern = PhasingOps.phasedCopy(of: pattern,
                                            newLength: pattern.length + delta,
                                            idSuffix: "phased")
        }
        // Fresh material starts a full legitimization cycle at the configured N.
        pattern.lifecycle = .repeating(remaining: (project.legitimization ?? .default).repeats)
        return pattern
    }

    /// Build the runtime Voice from its config (also LiveEngine's init path).
    static func materialize(_ config: VoiceConfig, project: Project) -> Voice {
        var pattern: Pattern
        if let override = config.overridePattern {
            // Hand-edited material (FR-P-7): verbatim, locked, established —
            // it never mutates and never regenerates.
            pattern = override
            pattern.locked = true
            pattern.lifecycle = .established
        } else {
            pattern = makePattern(config, project: project,
                                  seedLabels: ["voice", config.id, "gen0"],
                                  idSuffix: "gen0")
        }
        // Bass reharm overrides participation: ONLY the bass transposes
        // (FR-H-6) — regardless of the per-voice config flag.
        let participates: Bool
        if HarmonyScheduler.resolve(project: project).bassOnly {
            participates = config.role == .bass
        } else {
            participates = config.participatesInTransposition ?? true
        }
        return Voice(id: config.id, role: config.role, register: config.register,
                     referenceC: config.referenceC, pattern: pattern,
                     participatesInTransposition: participates,
                     anchorPolicy: config.anchorPolicy ?? .none)
    }
}
