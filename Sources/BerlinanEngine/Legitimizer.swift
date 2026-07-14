/// Law 1 as code — "repetition legitimizes" (M Law 1, §13.1; FR-L-1/2/3).
///
/// A pattern's randomness binds exactly once, at mutation time; it then plays
/// verbatim for N repeats before the next change is even possible. There is
/// deliberately NO per-step play probability anywhere in the engine — the
/// author of the source material tested and rejected it ("it breaks the
/// legitimization").
public enum Legitimizer {

    public struct Config: Codable, Equatable, Sendable {
        /// Total verbatim plays of new material (N; "generate once, repeat
        /// 3× = 4 total"). FR-L-1: default 4, configurable 2–32.
        public var repeats: Int

        public init(repeats: Int = 4) {
            precondition((2...32).contains(repeats), "repeats must be 2–32")
            self.repeats = repeats
        }

        public static let `default` = Config()
    }

    // MARK: - Lifecycle (FR-L-1)

    /// Called at each pattern loop boundary: counts down the verbatim
    /// repeats; `.established` is stable until a mutation resets it.
    public static func advanceAtLoopBoundary(_ pattern: Pattern) -> Pattern {
        var p = pattern
        switch p.lifecycle {
        case .repeating(let remaining) where remaining > 1:
            p.lifecycle = .repeating(remaining: remaining - 1)
        case .repeating:
            p.lifecycle = .established
        case .established:
            break
        }
        return p
    }

    /// Only established, unlocked patterns may change (Law 1 + FR-V-4).
    public static func isMutable(_ pattern: Pattern) -> Bool {
        pattern.lifecycle == .established && !pattern.locked
    }

    // MARK: - Mutation (FR-L-2)

    /// One constrained mutation pass over the voice's pattern. Identity for
    /// locked or still-repeating patterns. The result's lifecycle restarts at
    /// `.repeating(N−1)` so the change is legitimized before the next one.
    public static func mutate(_ voice: Voice, key: Key, meter: Meter,
                              seed: UInt64,
                              config: Config = .default) -> Voice {
        guard isMutable(voice.pattern) else { return voice }

        var rng = SplitMix64(seed: seed)
        var p = voice.pattern
        let count = key.scale.count
        let isBass = voice.role == .bass
        let step = meter.ticksPerBeat / 4
        let anchors = Set(voice.anchorPolicy.requiredLocalTicks(meter: meter)
            .flatMap { tick -> [Tick] in
                let bars = Int(p.length / meter.ticksPerBar)
                return (0..<max(bars, 1)).map { Tick($0) * meter.ticksPerBar + tick }
            })

        // 1. Degree shifts — 30% per non-first note, span-guarded (spec §7.4).
        //    Bass pitch never moves: roots stay roots for reharmonization and
        //    global transposition (M §7.1/§7.2).
        if !isBass {
            let firstPos = p.notes.map(\.position).min()
            for idx in p.notes.indices where p.notes[idx].position != firstPos {
                guard Double.random(in: 0..<1, using: &rng) < 0.30 else { continue }
                let delta = Int.random(in: -count...count, using: &rng)
                guard delta != 0 else { continue }
                var candidate = p.notes[idx]
                candidate.pitch.degree += delta
                var probe = p.notes
                probe[idx] = candidate
                let resolved = probe.map { key.resolve($0.pitch, referenceC: 60) }
                if resolved.max()! - resolved.min()! <= 24 {
                    p.notes[idx] = candidate
                }
            }
        }

        // 2. Time nudge — one non-anchor note, ±1–2 steps, collision-safe.
        if Double.random(in: 0..<1, using: &rng) < 0.30 {
            let movable = p.notes.indices.filter { !anchors.contains(p.notes[$0].position) }
            if let idx = movable.randomElement(using: &rng) {
                let delta = Tick([-2, -1, 1, 2].randomElement(using: &rng)!) * step
                let target = p.notes[idx].position + delta
                let occupied = Set(p.notes.map(\.position))
                if target >= 0, target < p.length, !occupied.contains(target) {
                    p.notes[idx].position = target
                }
            }
        }

        // 3. Accent move — "keep the notes, move the accents" (M §5.8).
        if Double.random(in: 0..<1, using: &rng) < 0.30, !p.notes.isEmpty {
            if let from = p.notes.indices.first(where: { p.notes[$0].accent }),
               let to = p.notes.indices.filter({ !p.notes[$0].accent })
                   .randomElement(using: &rng) {
                p.notes[from].accent = false
                p.notes[to].accent = true
            } else if let idx = p.notes.indices.randomElement(using: &rng) {
                p.notes[idx].accent.toggle()
            }
        }

        // 4. Intermittent ratchet (M §13.5, FR-L-5 groundwork): ratchets are
        //    cleared every mutation — they last exactly one legitimization
        //    cycle — then one note MAY get a 2–3× retrigger.
        for idx in p.notes.indices { p.notes[idx].ratchet = 1 }
        if Double.random(in: 0..<1, using: &rng) < 0.15,
           let idx = p.notes.indices.randomElement(using: &rng) {
            p.notes[idx].ratchet = Int.random(in: 2...3, using: &rng)
        }

        // Legitimize the change: N total verbatim plays before the next
        // mutation is possible.
        p.lifecycle = .repeating(remaining: config.repeats)

        var out = voice
        out.pattern = p
        return out
    }
}
