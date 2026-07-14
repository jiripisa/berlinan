import Testing
@testable import BerlinanEngine

private let key = Key.default                        // C natural minor
private let meter = Meter.fourFour
private let sixteenth: Tick = Time.ppqn / 4
private let eighth: Tick = Time.ppqn / 2
private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat

private func make(_ config: GeneratorConfig, role: VoiceRole = .bedPluck1,
                  seed: UInt64 = 1) -> Pattern {
    PatternFactory.make(id: "t", config: config, role: role, key: key,
                        meter: meter, seed: seed)
}

private let newConfigs: [(String, GeneratorConfig)] = [
    ("walk", .drunkardsWalk(bars: 2, scatter: 2)),
    ("walk/wide", .drunkardsWalk(bars: 1, scatter: 4)),
    ("staged", .stagedPluck(bars: 4)),
    ("arp/up", .arpeggiator(chordDegrees: [0, 2, 4], octaves: 2, direction: .up, rate: .eighth)),
    ("arp/down", .arpeggiator(chordDegrees: [0, 2, 4], octaves: 2, direction: .down, rate: .eighth)),
    ("arp/updown16", .arpeggiator(chordDegrees: [0, 3], octaves: 2, direction: .upDown, rate: .sixteenth)),
]

// MARK: - Shared invariants for the new generators

@Suite("Generators 4-6 — determinism & invariants")
struct NewGeneratorSharedTests {

    @Test("Same seed ⇒ identical; seeds vary content", arguments: newConfigs.map(\.0))
    func determinism(name: String) {
        let config = newConfigs.first { $0.0 == name }!.1
        #expect(make(config, seed: 42) == make(config, seed: 42))
        let variants = Set((1...6).map { make(config, seed: UInt64($0)).notes.description })
        #expect(variants.count > 1)
    }

    @Test("FR-P-2 invariants across 50 seeds", arguments: newConfigs.map(\.0))
    func invariants(name: String) {
        let config = newConfigs.first { $0.0 == name }!.1
        for seed in 1...50 {
            let p = make(config, seed: UInt64(seed))
            #expect(!p.notes.isEmpty)
            #expect(p.firstSoundingIsRoot(scaleCount: key.scale.count),
                    "first sounding must be a root (\(name), seed \(seed))")
            for n in p.notes {
                #expect(n.pitch.accidental == 0)
                #expect((0..<p.length).contains(n.position))
                #expect((96...144).contains(n.gate))
            }
            let resolved = p.notes.map { key.resolve($0.pitch, referenceC: 60) }
            #expect(resolved.max()! - resolved.min()! <= 24)
        }
    }
}

// MARK: - Drunkard's walk (M §13.2)

@Suite("Drunkard's walk")
struct DrunkardsWalkTests {

    @Test("Consecutive sounding pitches move at most `scatter` semitones")
    func scatterBound() {
        for seed in 1...30 {
            let p = make(.drunkardsWalk(bars: 2, scatter: 2), seed: UInt64(seed))
            let ordered = p.notes.sorted { $0.position < $1.position }
            let resolved = ordered.map { key.resolve($0.pitch, referenceC: 60) }
            for (a, b) in zip(resolved, resolved.dropFirst()) {
                // Quantization can stretch a raw chromatic step by at most 1.
                #expect(abs(b - a) <= 2 + 1, "walk jumped \(abs(b - a))")
            }
        }
    }

    @Test("Bursts and rests: gaps exist, density stays below 70%")
    func rhythmShape() {
        for seed in 1...30 {
            let p = make(.drunkardsWalk(bars: 2, scatter: 2), seed: UInt64(seed))
            let steps = Int(p.length / sixteenth)
            #expect(p.notes.count < steps * 7 / 10, "too dense")
            #expect(p.notes.count >= 3)
            // At least one rest gap of ≥ 2 steps somewhere.
            let positions = p.notes.map(\.position).sorted()
            let gaps = zip(positions, positions.dropFirst()).map { $1 - $0 }
            #expect(gaps.contains { $0 >= 2 * sixteenth })
        }
    }
}

// MARK: - Staged pluck (M §5.6)

@Suite("Staged pluck")
struct StagedPluckTests {

    @Test("Home base, octave jump, and the signature closing note")
    func stages() {
        for seed in 1...30 {
            let p = make(.stagedPluck(bars: 4), seed: UInt64(seed))
            #expect(p.length == 4 * bar)
            // Root pinned at position 0 (home base).
            #expect(p.notes.contains {
                $0.position == 0 && floorMod($0.pitch.degree, key.scale.count) == 0
            })
            // Octave jump present (root an octave up).
            #expect(p.notes.contains {
                floorMod($0.pitch.degree, key.scale.count) == 0
                    && key.resolve($0.pitch, referenceC: 60) >= 72
            })
            // Signature: accented note on the very last 16th step.
            let last = p.notes.first { $0.position == p.length - sixteenth }
            #expect(last != nil && last!.accent, "missing signature note (seed \(seed))")
            // All positions on the 16th grid.
            #expect(p.notes.allSatisfy { $0.position % sixteenth == 0 })
        }
    }
}

// MARK: - Arpeggiator expansion (M §5.9)

@Suite("Arpeggiator expansion")
struct ArpeggiatorTests {

    @Test("Cycle length = tones × octaves × rate (3×2 eighths = 3 beats — polymeter!)")
    func cycleLength() {
        let p = make(.arpeggiator(chordDegrees: [0, 2, 4], octaves: 2,
                                  direction: .up, rate: .eighth))
        #expect(p.length == 6 * eighth)          // 3 beats — phases against 4/4
        #expect(p.notes.count == 6)
        #expect(p.notes.map(\.position) == (0..<6).map { Tick($0) * eighth })
    }

    @Test("Up = strictly ascending resolved pitches")
    func upAscending() {
        let p = make(.arpeggiator(chordDegrees: [0, 2, 4], octaves: 2,
                                  direction: .up, rate: .eighth))
        let resolved = p.notes.sorted { $0.position < $1.position }
            .map { key.resolve($0.pitch, referenceC: 60) }
        #expect(resolved == resolved.sorted())
        #expect(Set(resolved).count == resolved.count)
    }

    @Test("Down starts on a root pitch class and descends from it")
    func downFromRoot() {
        let p = make(.arpeggiator(chordDegrees: [0, 2, 4], octaves: 2,
                                  direction: .down, rate: .eighth))
        let ordered = p.notes.sorted { $0.position < $1.position }
        let resolved = ordered.map { key.resolve($0.pitch, referenceC: 60) }
        #expect(floorMod(resolved[0] - key.root, 12) == 0, "must start on a root")
        // After the rotation point the sequence wraps — check the first run descends.
        #expect(resolved[1] < resolved[0])
    }

    @Test("UpDown visits the turning point once (no repeated endpoints)")
    func upDown() {
        let p = make(.arpeggiator(chordDegrees: [0, 3], octaves: 2,
                                  direction: .upDown, rate: .sixteenth))
        // 4 tones up + 2 interior on the way down = 6 steps of 16ths.
        #expect(p.notes.count == 6)
        let resolved = p.notes.sorted { $0.position < $1.position }
            .map { key.resolve($0.pitch, referenceC: 60) }
        #expect(resolved.max() == resolved[3])   // peak in the middle, visited once
        #expect(resolved.filter { $0 == resolved.max()! }.count == 1)
    }
}

// MARK: - Gate/pitch decoupling (FR-P-4, M §6.4)

@Suite("Decoupled gate/pitch render")
struct DecoupledTests {

    private func decoupled(pitchCount: Int, gatePattern: [Bool],
                           step: Tick = eighth) -> Pattern {
        Pattern.decoupled(
            id: "d",
            pitches: (0..<pitchCount).map { DegreePitch(degree: $0) },
            gates: gatePattern.map { GateStep(on: $0, width: 0.5) },
            stepTicks: step,
            provenance: Provenance(generator: .handEdited, version: 1, seed: 0))
    }

    @Test("8 pitches v 6 gates: 24-step composite, correct onset count")
    func eightVsSix() {
        let gates = [true, true, false, true, false, true]        // 4 of 6 on
        let p = decoupled(pitchCount: 8, gatePattern: gates)
        #expect(p.length == 24 * eighth)                          // LCM(8,6)=24
        let occ = p.occurrences(in: 0..<p.length)
        #expect(occ.count == 16)                                  // 24 × 4/6
        // Both cycles advance EVERY step: pitch at step k = k mod 8.
        for o in occ {
            let step = Int(o.at / eighth)
            #expect(o.note.pitch.degree == step % 8, "step \(step)")
            #expect(gates[step % 6])
        }
    }

    @Test("Silent steps where the gate is off")
    func silences() {
        let gates = [true, false]
        let p = decoupled(pitchCount: 3, gatePattern: gates)      // LCM(3,2)=6 steps
        #expect(p.length == 6 * eighth)
        let onsets = p.occurrences(in: 0..<p.length).map { Int($0.at / eighth) }
        #expect(onsets == [0, 2, 4])                              // even steps only
        #expect(!p.hasOnset(atGlobalTick: eighth))
        #expect(p.hasOnset(atGlobalTick: 2 * eighth))
    }

    @Test("Manual's 7v8 pairing re-syncs after 56 steps")
    func sevenVsEight() {
        let p = decoupled(pitchCount: 8, gatePattern: Array(repeating: true, count: 7))
        #expect(p.length == 56 * eighth)
        #expect(p.occurrences(in: 0..<p.length).count == 56)
    }

    @Test("Window chaining stays seam-safe in decoupled mode")
    func windowChaining() {
        let gates = [true, true, false, true, false, true]
        let p = decoupled(pitchCount: 8, gatePattern: gates)
        let whole = p.occurrences(in: 0..<(2 * p.length))
        var chained: [(at: Tick, note: PatternNote)] = []
        var t: Tick = 0
        while t < 2 * p.length {
            let end = min(t + 700, 2 * p.length)
            chained += p.occurrences(in: t..<end)
            t = end
        }
        #expect(chained.map(\.at) == whole.map(\.at))
        #expect(chained.map(\.note) == whole.map(\.note))
    }
}

// MARK: - Pattern ops (FR-P-5/6)

@Suite("Pattern ops")
struct PatternOpsTests {

    private func source(seed: UInt64 = 3) -> Pattern {
        make(.seedProcedure(bars: 1, mutations: 4), seed: seed)
    }

    @Test("duplicateAndTweak: first half verbatim, later reps mutated, deterministic")
    func duplicateAndTweak() {
        let original = source()
        var anyChanged = false
        for seed in UInt64(1)...10 {
            let grown = PatternOps.duplicateAndTweak(original, times: 4, key: key,
                                                     meter: meter, seed: seed)
            #expect(grown.length == 4 * original.length)
            #expect(grown == PatternOps.duplicateAndTweak(original, times: 4, key: key,
                                                          meter: meter, seed: seed))
            // Reps 0 and 1 must be verbatim copies of the original.
            for rep in 0...1 {
                let offset = Tick(rep) * original.length
                let repNotes = grown.notes
                    .filter { $0.position >= offset && $0.position < offset + original.length }
                    .map { n -> PatternNote in var m = n; m.position -= offset; return m }
                    .sorted { $0.position < $1.position }
                #expect(repNotes == original.notes.sorted { $0.position < $1.position },
                        "rep \(rep) must be verbatim (seed \(seed))")
            }
            if grown.notes.count != original.notes.count * 4
                || !grown.notes.allSatisfy({ n in
                    original.notes.contains { o in
                        floorMod(Int(n.position), Int(original.length)) == o.position
                            && n.pitch == o.pitch
                    }
                }) {
                anyChanged = true
            }
            // In-scale throughout.
            #expect(grown.notes.allSatisfy { $0.pitch.accidental == 0 })
        }
        #expect(anyChanged, "no seed produced a tweak")
    }

    @Test("moveAccents keeps pitches, times, velocities and gates intact")
    func moveAccents() {
        var original = source()
        original.notes[0].accent = true
        for seed in UInt64(1)...10 {
            let moved = PatternOps.moveAccents(original, seed: seed)
            #expect(moved.notes.map(\.position) == original.notes.map(\.position))
            #expect(moved.notes.map(\.pitch) == original.notes.map(\.pitch))
            #expect(moved.notes.map(\.velocity) == original.notes.map(\.velocity))
            #expect(moved.notes.map(\.gate) == original.notes.map(\.gate))
        }
        var anyMoved = false
        for seed in UInt64(1)...10 {
            let moved = PatternOps.moveAccents(original, seed: seed)
            if moved.notes.map(\.accent) != original.notes.map(\.accent) { anyMoved = true }
        }
        #expect(anyMoved)
    }
}
