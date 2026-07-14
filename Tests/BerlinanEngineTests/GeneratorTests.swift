import Testing
@testable import BerlinanEngine

private let key = Key.default                        // C natural minor
private let meter = Meter.fourFour
private let sixteenth: Tick = Time.ppqn / 4          // 240
private let beat: Tick = Time.ppqn

private func make(_ config: GeneratorConfig, role: VoiceRole = .bedPluck1,
                  seed: UInt64 = 1) -> Pattern {
    PatternFactory.make(id: "t", config: config, role: role, key: key,
                        meter: meter, seed: seed)
}

/// Shared FR-P-2 invariants every generator must satisfy.
private func assertInvariants(_ p: Pattern,
                              sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(!p.notes.isEmpty, sourceLocation: sourceLocation)
    #expect(p.firstSoundingIsRoot(scaleCount: key.scale.count),
            "first sounding note must be root", sourceLocation: sourceLocation)
    for n in p.notes {
        #expect(n.pitch.accidental == 0, "no accidentals outside tension budget",
                sourceLocation: sourceLocation)
        #expect((0..<p.length).contains(n.position), sourceLocation: sourceLocation)
        #expect((96...144).contains(n.gate), "gates 40–60% of a 16th step",
                sourceLocation: sourceLocation)
    }
    let resolved = p.notes.map { key.resolve($0.pitch, referenceC: 60) }
    #expect(resolved.max()! - resolved.min()! <= 24, "span ≤ 2 octaves",
            sourceLocation: sourceLocation)
}

private let allConfigs: [(String, GeneratorConfig, VoiceRole)] = [
    ("seedProcedure/bed", .seedProcedure(bars: 1, mutations: 4), .bedPluck1),
    ("seedProcedure/2bars", .seedProcedure(bars: 2, mutations: 6), .bedPluck2),
    ("seedProcedure/bass", .seedProcedure(bars: 1, mutations: 4), .bass),
    ("hml/high", .highMidLow(register: .high), .bedPluck1),
    ("hml/mid", .highMidLow(register: .mid), .bedPluck2),
    ("hml/low", .highMidLow(register: .low), .bass),
    ("pulsingBass", .pulsingBass(accents: 3), .bass),
]

// MARK: - Cross-generator suites

@Suite("Generator determinism (NFR-4)")
struct GeneratorDeterminismTests {

    @Test("Same seed ⇒ identical pattern", arguments: allConfigs.map(\.0))
    func sameSeed(name: String) {
        let (_, config, role) = allConfigs.first { $0.0 == name }!
        let a = make(config, role: role, seed: 99)
        let b = make(config, role: role, seed: 99)
        #expect(a == b)
    }

    @Test("Varying seeds vary the note content")
    func seedsMatter() {
        // Across several seeds at least two distinct note arrays must appear
        // (a single fixed output would mean the rng is unused).
        for (_, config, role) in allConfigs where config.usesRandomness {
            let variants = Set((1...6).map { seed in
                make(config, role: role, seed: UInt64(seed)).notes.description
            })
            #expect(variants.count > 1, "generator ignored its seed: \(config)")
        }
    }
}

@Suite("Generator invariants (FR-P-2)")
struct GeneratorInvariantTests {

    @Test("All generators, many seeds", arguments: allConfigs.map(\.0))
    func invariants(name: String) {
        let (_, config, role) = allConfigs.first { $0.0 == name }!
        for seed in 1...50 {
            assertInvariants(make(config, role: role, seed: UInt64(seed)))
        }
    }

    @Test("Provenance records generator and seed")
    func provenance() {
        let p = make(.seedProcedure(bars: 1, mutations: 4), seed: 7)
        #expect(p.provenance.generator == .seedProcedure)
        #expect(p.provenance.seed == 7)
        #expect(make(.highMidLow(register: .high)).provenance.generator == .highMidLow)
        #expect(make(.pulsingBass(accents: 3), role: .bass).provenance.generator == .pulsingBass)
    }
}

// MARK: - Seed procedure specifics (M §5.2, §5.3)

@Suite("Seed procedure")
struct SeedProcedureTests {

    @Test("Bed roles: beats 1 and 3 keep onsets (timing-locked)")
    func lockedBeats() {
        for seed in 1...30 {
            let p = make(.seedProcedure(bars: 1, mutations: 4), seed: UInt64(seed))
            #expect(p.hasOnset(atGlobalTick: 0))
            #expect(p.hasOnset(atGlobalTick: 2 * beat))
        }
    }

    @Test("Requested bar count sets the loop length")
    func barCount() {
        #expect(make(.seedProcedure(bars: 1, mutations: 4)).length == meter.ticksPerBar)
        #expect(make(.seedProcedure(bars: 2, mutations: 4)).length == 2 * meter.ticksPerBar)
    }

    @Test("Bass role: roots only, anchor-satisfying (FR-V-5, M §7.1)")
    func bassRole() {
        for seed in 1...30 {
            let p = make(.seedProcedure(bars: 1, mutations: 4), role: .bass, seed: UInt64(seed))
            let v = Voice(id: "b", role: .bass,
                          register: RegisterWindow(low: 24, high: 48),
                          referenceC: 36, pattern: p, anchorPolicy: .beats1and3)
            #expect(v.satisfiesAnchor(meter: meter))
            for n in p.notes {
                #expect(floorMod(n.pitch.degree, key.scale.count) == 0,
                        "bass stays on roots for transposability")
            }
        }
    }

    @Test("Sparseness: a 1-bar bed pattern stays within 3–7 notes (M Law 3)")
    func sparseness() {
        for seed in 1...30 {
            let p = make(.seedProcedure(bars: 1, mutations: 4), seed: UInt64(seed))
            #expect((3...7).contains(p.notes.count))
        }
    }
}

// MARK: - High/Mid/Low specifics (M §5.3)

@Suite("High/Mid/Low")
struct HighMidLowTests {

    @Test("High register contains the 5th-up (+4 degrees) contour tone")
    func highContour() {
        for seed in 1...20 {
            let p = make(.highMidLow(register: .high), seed: UInt64(seed))
            #expect(p.notes.contains { $0.pitch.degree == 4 })
        }
    }

    @Test("Mid register: stair steps ±4, beats 1 and 3 stay root on the grid")
    func midContour() {
        for seed in 1...20 {
            let p = make(.highMidLow(register: .mid), seed: UInt64(seed))
            let atZero = p.notes.first { $0.position == 0 }
            let atBeat3 = p.notes.first { $0.position == 2 * beat }
            #expect(atZero?.pitch.degree == 0)
            #expect(atBeat3?.pitch.degree == 0)
            #expect(p.notes.contains { $0.pitch.degree == 4 })
            #expect(p.notes.contains { $0.pitch.degree == -4 })
        }
    }

    @Test("Low register: exactly two onsets — beats 1 and 3, roots")
    func lowContour() {
        for seed in 1...20 {
            let p = make(.highMidLow(register: .low), role: .bass, seed: UInt64(seed))
            #expect(p.notes.count == 2)
            #expect(p.notes.map(\.position).sorted() == [0, 2 * beat])
            #expect(p.notes.allSatisfy { $0.pitch.degree == 0 })
        }
    }
}

// MARK: - Pulsing bass specifics (M §5.5)

@Suite("Pulsing bass")
struct PulsingBassTests {

    @Test("Every 16th step carries an onset; majority stays on the root")
    func density() {
        for seed in 1...30 {
            let p = make(.pulsingBass(accents: 3), role: .bass, seed: UInt64(seed))
            #expect(p.notes.count == 16)
            #expect(Set(p.notes.map(\.position)) == Set((0..<16).map { Tick($0) * sixteenth }))
            let roots = p.notes.filter { floorMod($0.pitch.degree, key.scale.count) == 0
                                         && $0.pitch.octave == 0 }
            #expect(roots.count >= 12, "≥ 75% of steps stay on the root")
        }
    }

    @Test("Exactly the off-root/octave-moved notes are accented and louder")
    func accents() {
        for seed in 1...30 {
            let p = make(.pulsingBass(accents: 3), role: .bass, seed: UInt64(seed))
            let baseline = p.notes.filter { !$0.accent }.map(\.velocity).max()!
            for n in p.notes {
                let moved = n.pitch.degree != 0 || n.pitch.octave != 0
                #expect(n.accent == moved)
                if n.accent { #expect(n.velocity > baseline) }
            }
            #expect(p.notes.filter(\.accent).count <= 4)
        }
    }

    @Test("First step is the root (transposable groove — 'the groove is C')")
    func firstStepRoot() {
        for seed in 1...30 {
            let p = make(.pulsingBass(accents: 3), role: .bass, seed: UInt64(seed))
            let first = p.notes.min { $0.position < $1.position }!
            #expect(first.position == 0)
            #expect(first.pitch.degree == 0 && first.pitch.octave == 0)
        }
    }
}
