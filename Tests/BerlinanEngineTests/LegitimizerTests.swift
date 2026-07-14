import Testing
@testable import BerlinanEngine

private let key = Key.default
private let meter = Meter.fourFour
private let beat: Tick = Time.ppqn

private func freshVoice(role: VoiceRole = .bedPluck1, seed: UInt64 = 5) -> Voice {
    let config: GeneratorConfig = role == .bass
        ? .seedProcedure(bars: 1, mutations: 4)
        : .seedProcedure(bars: 1, mutations: 4)
    let p = PatternFactory.make(id: "\(role.rawValue)/gen0", config: config,
                                role: role, key: key, meter: meter, seed: seed)
    return Voice(id: role.rawValue, role: role,
                 register: RegisterWindow(low: role == .bass ? 24 : 48,
                                          high: role == .bass ? 48 : 84),
                 referenceC: role == .bass ? 36 : 60, pattern: p,
                 anchorPolicy: role == .bass ? .beats1and3 : .none)
}

private func established(_ voice: Voice) -> Voice {
    var v = voice
    v.pattern.lifecycle = .established
    return v
}

// MARK: - Lifecycle (FR-L-1)

@Suite("Legitimization lifecycle")
struct LifecycleTests {

    @Test("Countdown: repeating(3) → 3 boundaries → established, then stable")
    func countdown() {
        var p = freshVoice().pattern
        #expect(p.lifecycle == .repeating(remaining: 3))
        p = Legitimizer.advanceAtLoopBoundary(p)
        #expect(p.lifecycle == .repeating(remaining: 2))
        p = Legitimizer.advanceAtLoopBoundary(p)
        #expect(p.lifecycle == .repeating(remaining: 1))
        p = Legitimizer.advanceAtLoopBoundary(p)
        #expect(p.lifecycle == .established)
        p = Legitimizer.advanceAtLoopBoundary(p)
        #expect(p.lifecycle == .established)
    }

    @Test("Fresh generator output plays exactly N=4 times before becoming mutable")
    func fourPlays() {
        var p = freshVoice().pattern
        var plays = 0
        while !Legitimizer.isMutable(p) {
            plays += 1        // the loop iteration that just sounded
            p = Legitimizer.advanceAtLoopBoundary(p)
            if plays > 10 { break }
        }
        #expect(plays == 4)   // Law 1: generate once + repeat 3× = 4 total
    }

    @Test("Locked patterns are never mutable")
    func lockedNotMutable() {
        var v = established(freshVoice())
        v.pattern.locked = true
        #expect(!Legitimizer.isMutable(v.pattern))
    }
}

// MARK: - Mutation gating (Law 1, FR-V-4)

@Suite("Mutation gating")
struct MutationGatingTests {

    @Test("Identity while still repeating — randomness must not re-roll mid-cycle")
    func identityWhileRepeating() {
        let v = freshVoice()     // .repeating(3)
        let out = Legitimizer.mutate(v, key: key, meter: meter, seed: 1)
        #expect(out == v)
    }

    @Test("Identity for locked patterns")
    func identityWhenLocked() {
        var v = established(freshVoice())
        v.pattern.locked = true
        let out = Legitimizer.mutate(v, key: key, meter: meter, seed: 1)
        #expect(out == v)
    }
}

// MARK: - Mutation behavior (FR-L-2)

@Suite("Mutation operators")
struct MutationTests {

    @Test("Deterministic per seed; some seed in 1…10 produces a change")
    func deterministicAndEffective() {
        let v = established(freshVoice())
        var changed = false
        for seed in UInt64(1)...10 {
            let a = Legitimizer.mutate(v, key: key, meter: meter, seed: seed)
            let b = Legitimizer.mutate(v, key: key, meter: meter, seed: seed)
            #expect(a == b)
            if a.pattern.notes != v.pattern.notes { changed = true }
        }
        #expect(changed)
    }

    @Test("Post-mutation invariants hold (bed voice, 50 seeds)")
    func bedInvariants() {
        let v = established(freshVoice())
        for seed in UInt64(1)...50 {
            let out = Legitimizer.mutate(v, key: key, meter: meter, seed: seed)
            let p = out.pattern
            #expect(p.firstSoundingIsRoot(scaleCount: key.scale.count))
            #expect(p.notes.allSatisfy { $0.pitch.accidental == 0 })
            #expect(p.notes.allSatisfy { (0..<p.length).contains($0.position) })
            let resolved = p.notes.map { key.resolve($0.pitch, referenceC: 60) }
            #expect(resolved.max()! - resolved.min()! <= 24)
            #expect(p.notes.filter { $0.ratchet > 1 }.count <= 1)
        }
    }

    @Test("Bass: anchors preserved, roots only (50 seeds)")
    func bassInvariants() {
        let v = established(freshVoice(role: .bass))
        for seed in UInt64(1)...50 {
            let out = Legitimizer.mutate(v, key: key, meter: meter, seed: seed)
            #expect(out.satisfiesAnchor(meter: meter))
            #expect(out.pattern.notes.allSatisfy {
                floorMod($0.pitch.degree, key.scale.count) == 0
            })
        }
    }

    @Test("Mutation resets the lifecycle to repeating(N−1)")
    func lifecycleReset() {
        let v = established(freshVoice())
        for seed in UInt64(1)...10 {
            let out = Legitimizer.mutate(v, key: key, meter: meter, seed: seed)
            #expect(out.pattern.lifecycle == .repeating(remaining: 3))
        }
    }

    @Test("Custom N flows into the reset")
    func customRepeats() {
        let v = established(freshVoice())
        let cfg = Legitimizer.Config(repeats: 8)
        let out = Legitimizer.mutate(v, key: key, meter: meter, seed: 3, config: cfg)
        #expect(out.pattern.lifecycle == .repeating(remaining: 7))
    }

    @Test("Loop-stability: a mutated pattern renders identically every repeat (FR-L-3)")
    func loopStable() {
        let v = established(freshVoice())
        let out = Legitimizer.mutate(v, key: key, meter: meter, seed: 9)
        let p = out.pattern
        let loop0 = p.occurrences(in: 0..<p.length)
        for k in 1...4 {
            let shifted = p.occurrences(in: (Tick(k) * p.length)..<(Tick(k + 1) * p.length))
            #expect(shifted.map(\.note) == loop0.map(\.note))
            #expect(shifted.map { $0.at - Tick(k) * p.length } == loop0.map(\.at))
        }
    }
}
