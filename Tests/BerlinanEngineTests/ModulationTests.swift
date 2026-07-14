import Testing
@testable import BerlinanEngine

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat
private let grid: Tick = Time.ppqn / 24      // 40 ticks — 1/96 note (FR-MOD-4)
private let meter = Meter.fourFour

private func lane(shape: LFOShape, cycleBars: Double = 1, depth: Double = 1,
                  center: Double = 0.5, phase: Double = 0,
                  target: String = "filter") -> CCLane {
    CCLane(target: target, shape: shape, cycleBars: cycleBars,
           depth: depth, center: center, phase: phase)
}

private let filterMap: [String: UInt8] = ["filter": 74]

private func render(_ lanes: [CCLane], in range: Range<Tick>,
                    map: [String: UInt8] = filterMap,
                    seed: UInt64 = 1) -> [RenderedCC] {
    ModulationEngine.render(lanes: lanes, ccMap: map, voiceID: "v",
                            in: range, meter: meter, seed: seed)
}

// MARK: - Continuous shapes

@Suite("CC LFO lanes")
struct CCLaneTests {

    @Test("Sine: known values at known phases, grid-aligned, clamped 0–127")
    func sineBasics() {
        let events = render([lane(shape: .sine)], in: 0..<bar)
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { $0.at % grid == 0 })
        #expect(events.allSatisfy { $0.controller == 74 })
        // t=0: sin(0)=0 → center 0.5 → 64 (rounded).
        #expect(events.first!.at == 0)
        #expect(abs(Int(events.first!.value) - 64) <= 1)
        // Quarter cycle (bar/4): sin(π/2)=1 → center+depth/2 = 1.0 → 127.
        let peak = events.first { $0.at == bar / 4 }
        #expect(peak != nil && peak!.value == 127)
        // Three quarters: trough → 0.
        let trough = events.first { $0.at == 3 * bar / 4 }
        #expect(trough != nil && trough!.value == 0)
    }

    @Test("Delta filter: a flat lane emits exactly one initial value")
    func flatLane() {
        let events = render([lane(shape: .sine, depth: 0)], in: 0..<(4 * bar))
        #expect(events.count == 1)
        #expect(events[0].at == 0)
        #expect(abs(Int(events[0].value) - 64) <= 1)
    }

    @Test("Chunk-safety: chained windows equal the whole render (stateless delta)")
    func chunkSafe() {
        let lanes = [lane(shape: .triangle, cycleBars: 2),
                     lane(shape: .sampleHold, cycleBars: 1, target: "filter")]
        let whole = render(lanes, in: 0..<(4 * bar))
        var chained: [RenderedCC] = []
        var t: Tick = 0
        while t < 4 * bar {
            let end = min(t + 777, 4 * bar)
            chained += render(lanes, in: t..<end)
            t = end
        }
        // Windows other than the first must not re-emit the initial value —
        // equality of the full streams proves it.
        #expect(chained == whole)
    }

    @Test("Unmapped target skips the lane")
    func unmapped() {
        let events = render([lane(shape: .sine, target: "wavetable")], in: 0..<bar)
        #expect(events.isEmpty)
    }

    @Test("sawUp rises monotonically within one cycle")
    func sawUp() {
        let events = render([lane(shape: .sawUp, cycleBars: 1)], in: 0..<(bar - grid))
        let values = events.map(\.value)
        #expect(values == values.sorted())
        #expect(values.first! < values.last!)
    }
}

// MARK: - Sample & hold (M §11.3)

@Suite("Sample & hold pre-strike")
struct SampleHoldTests {

    @Test("Steps on the 8th grid, offset preStrike ticks early, deterministic")
    func stepping() {
        let l = lane(shape: .sampleHold)
        let a = render([l], in: 0..<(2 * bar), seed: 5)
        let b = render([l], in: 0..<(2 * bar), seed: 5)
        #expect(a == b)
        let c = render([l], in: 0..<(2 * bar), seed: 6)
        #expect(a != c)
        // Emissions at k*480 − 10 (first step clamps to 0).
        let eighth = Time.ppqn / 2
        for event in a.dropFirst() {
            #expect((event.at + 10) % eighth == 0,
                    "S&H emission at \(event.at) is off the pre-strike grid")
        }
        #expect(a.first?.at == 0)
    }

    @Test("Values bounded by center ± depth/2")
    func bounds() {
        let l = lane(shape: .sampleHold, depth: 0.5, center: 0.5)
        let events = render([l], in: 0..<(8 * bar), seed: 9)
        // 0.25...0.75 of 127 → 32...95 (rounding slack ±1).
        #expect(events.allSatisfy { (31...96).contains(Int($0.value)) })
        #expect(Set(events.map(\.value)).count > 3, "S&H must actually vary")
    }
}

// MARK: - Gate ramps (FR-MOD-2, M §11.4)

@Suite("Gate ramps")
struct GateRampTests {

    @Test("Per-bar multipliers scale note gates")
    func rampApplies() {
        var project = Project.demo
        project.transposition = .pedal
        project.voices = [project.voices[0]]
        var withRamp = project
        withRamp.voices[0].gateRamp = GateRampProgram(profile: [0.5, 2.0])

        let plain = OfflineRenderer.renderNotes(project: project, bars: 2)
        let ramped = OfflineRenderer.renderNotes(project: withRamp, bars: 2)
        #expect(plain.count == ramped.count)
        for (p, r) in zip(plain, ramped) {
            let barIndex = Int(p.at / bar)
            let multiplier = barIndex % 2 == 0 ? 0.5 : 2.0
            let expected = max(1, Tick(Double(p.gate) * multiplier))
            #expect(r.gate == expected, "at \(p.at): \(r.gate) vs \(expected)")
        }
    }
}

// MARK: - Delay hints (FR-MOD-8)

@Suite("Delay hints")
struct DelayHintTests {

    @Test("Division by role, milliseconds from the manual's formula")
    func hints() {
        let bed = DelayHint.compute(role: .bedPluck1, bpm: 90)
        #expect(bed.division == .dotted8th)
        #expect(abs(bed.milliseconds - 500.0) < 1e-9)      // (60000/90)/4*3

        let bass = DelayHint.compute(role: .bass, bpm: 90)
        #expect(bass.division == .eighth)
        #expect(abs(bass.milliseconds - 333.333333) < 1e-3)

        let lead = DelayHint.compute(role: .lead, bpm: 90)
        #expect(lead.division == .quarter)
        #expect(abs(lead.milliseconds - 666.666666) < 1e-3)

        #expect(bed.feedback == 0.5 && bed.wet == 0.5 && bed.pingPong && bed.filterRepeats)
    }
}

// MARK: - SMF integration

@Suite("SMF CC emission")
struct SMFCCTests {

    @Test("A project with a CC lane lands 0xB0 events in the file")
    func ccInFile() {
        let bytes = OfflineRenderer.render(project: .demo, bars: 4)
        // Demo carries a filter lane on bedPluck1 (channel 0) → 0xB0 74 vv.
        var found = false
        for i in 0..<(bytes.count - 2) where bytes[i] == 0xB0 && bytes[i + 1] == 74 {
            found = true
            break
        }
        #expect(found, "expected CC74 events on channel 0")
    }
}
