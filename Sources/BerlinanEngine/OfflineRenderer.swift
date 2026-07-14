/// Offline (headless) render loop — M1's deliverable. Runs the authentic
/// Berlinan cycle per voice: generate → play N verbatim loops → mutate →
/// repeat (Law 1), against the shared transposition schedule, then encodes
/// the result as an SMF.
public enum OfflineRenderer {

    /// Full render to SMF bytes.
    public static func render(project: Project, bars: Int) -> [UInt8] {
        let total = Tick(bars) * project.meter.ticksPerBar
        var tracks: [SMFTrack] = []
        for config in project.voices {
            let notes = renderVoice(config, project: project, total: total)
            tracks.append(SMFTrack(
                name: "\(config.id) | ch\(config.channel + 1) | \(config.role.rawValue)",
                channel: config.channel,
                notes: notes
            ))
        }
        let markers = project.transposition.events
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
        var voice = materialize(config, project: project)
        var generation = 1
        var notes: [RenderedNote] = []
        var t: Tick = 0

        while t < total {
            let segmentEnd = min(t + voice.pattern.length, total)
            let humanSeed = voice.pattern.provenance.seed
            let segment = HarmonyEngine.render(voices: [voice],
                                               schedule: project.transposition,
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
        let pattern = makePattern(config, project: project,
                                  seedLabels: ["voice", config.id, "gen0"],
                                  idSuffix: "gen0")
        return Voice(id: config.id, role: config.role, register: config.register,
                     referenceC: config.referenceC, pattern: pattern,
                     participatesInTransposition: config.participatesInTransposition ?? true,
                     anchorPolicy: config.anchorPolicy ?? .none)
    }
}
