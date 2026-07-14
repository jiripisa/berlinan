import Foundation
import Testing
@testable import BerlinanEngine

private let beat: Tick = Time.ppqn
private let bar: Tick = 4 * beat
private let sixteenth: Tick = Time.ppqn / 4

/// The demo fixture is defined once in the engine (Project.demo) — the same
/// value backs the golden master, the committed JSON, and `berlinan-cli demo`.
private func demoProject() -> Project { .demo }

private func pedalProject() -> Project {
    var p = demoProject()
    p.transposition = .pedal
    return p
}

// MARK: - Velocity policy (FR-MOD-1)

@Suite("Velocity policy")
struct VelocityPolicyTests {

    @Test("Accent adds the boost, clamped to 1–127")
    func accentBoost() {
        let policy = VelocityPolicy(accentBoost: 20, humanizeRange: 0)
        #expect(policy.apply(velocity: 100, accent: true, patternSeed: 1, localPosition: 0) == 120)
        #expect(policy.apply(velocity: 100, accent: false, patternSeed: 1, localPosition: 0) == 100)
        #expect(policy.apply(velocity: 120, accent: true, patternSeed: 1, localPosition: 0) == 127)
    }

    @Test("Humanization stays within ±range and is deterministic")
    func humanizeBounds() {
        let policy = VelocityPolicy(accentBoost: 0, humanizeRange: 10)
        for position in stride(from: Tick(0), to: bar, by: Tick.Stride(sixteenth)) {
            let v = policy.apply(velocity: 100, accent: false, patternSeed: 7, localPosition: position)
            #expect((90...110).contains(Int(v)))
            let again = policy.apply(velocity: 100, accent: false, patternSeed: 7, localPosition: position)
            #expect(v == again)
        }
    }

    @Test("Offsets re-roll when the pattern seed changes (new legitimization cycle)")
    func rerollAcrossGenerations() {
        let policy = VelocityPolicy(accentBoost: 0, humanizeRange: 10)
        var anyDifferent = false
        for position in stride(from: Tick(0), to: bar, by: Tick.Stride(sixteenth)) {
            let a = policy.apply(velocity: 100, accent: false, patternSeed: 7, localPosition: position)
            let b = policy.apply(velocity: 100, accent: false, patternSeed: 8, localPosition: position)
            if a != b { anyDifferent = true }
        }
        #expect(anyDifferent)
    }
}

// MARK: - Project format

@Suite("Project format")
struct ProjectFormatTests {

    @Test("JSON round-trip")
    func roundTrip() throws {
        let p = demoProject()
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(Project.self, from: data)
        #expect(back == p)
    }

    @Test("The committed demo file decodes and matches the in-code fixture")
    func committedFileMatches() throws {
        let url = Bundle.module.url(forResource: "Goldens/demo_project", withExtension: "json")
        let data = try Data(contentsOf: try #require(url))
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        #expect(decoded == demoProject())
    }
}

// MARK: - Offline renderer

@Suite("Offline renderer")
struct OfflineRendererTests {

    @Test("Byte determinism (FR-UX-1)")
    func determinism() {
        let a = OfflineRenderer.render(project: demoProject(), bars: 8)
        let b = OfflineRenderer.render(project: demoProject(), bars: 8)
        #expect(a == b)
    }

    @Test("Law 1 in the render: bars 0–3 of the bed are verbatim repeats")
    func lawOneRepeats() {
        var project = pedalProject()
        // 1-bar bed loop only (drop the 15-step voice for exact bar alignment).
        project.voices = [project.voices[0]]
        let notes = OfflineRenderer.renderNotes(project: project, bars: 8)
        let byBar = Dictionary(grouping: notes) { Int($0.at / bar) }
        func signature(_ bar: Int) -> [String] {
            (byBar[bar] ?? []).map { "\($0.at % (4 * beat))/\($0.midiNote)/\($0.velocity)" }
        }
        #expect(signature(1) == signature(0))
        #expect(signature(2) == signature(0))
        #expect(signature(3) == signature(0))
    }

    @Test("Mutation kicks in after the legitimization cycle for some master seed")
    func mutationHappens() {
        var anyChanged = false
        for seed in UInt64(1)...8 {
            var project = pedalProject()
            project.masterSeed = seed
            project.voices = [project.voices[0]]
            let notes = OfflineRenderer.renderNotes(project: project, bars: 12)
            let byBar = Dictionary(grouping: notes) { Int($0.at / bar) }
            func signature(_ bar: Int) -> [String] {
                (byBar[bar] ?? []).map { "\($0.at % (4 * beat))/\($0.midiNote)/\($0.velocity)" }
            }
            if signature(4) != signature(0) || signature(8) != signature(4) {
                anyChanged = true
            }
        }
        #expect(anyChanged, "no mutation across 8 master seeds — scheduler broken")
    }

    @Test("phaseSteps −1 gives a 15-step loop that drifts against the bar")
    func phasedVoiceDrifts() {
        var project = pedalProject()
        project.voices = [project.voices[1]]          // the phased bed voice
        // Long legitimization so the loop content is stable while we measure.
        project.legitimization = Legitimizer.Config(repeats: 32)
        let notes = OfflineRenderer.renderNotes(project: project, bars: 4)
        let loop = 15 * sixteenth
        let first = notes.first!
        // The same local note must reappear exactly one loop later.
        let second = notes.first { $0.at == first.at + loop && $0.midiNote == first.midiNote }
        #expect(second != nil)
    }

    @Test("Transposition schedule shapes the bass (bar 8 = VI = Ab pitch class)")
    func transpositionApplied() {
        let notes = OfflineRenderer.renderNotes(project: demoProject(), bars: 10)
        let bassBar8 = notes.filter { $0.voiceID == "bass" && $0.at >= 8 * bar && $0.at < 9 * bar }
        #expect(!bassBar8.isEmpty)
        // Pulsing bass majority sits on the (transposed) root: degree 0 + 5 = Ab.
        let abCount = bassBar8.filter { Int($0.midiNote) % 12 == 8 }.count
        #expect(abCount * 4 >= bassBar8.count * 3, "≥ 75% of bar-8 bass on Ab")
    }

    @Test("HARM markers land in the file")
    func markers() {
        let bytes = OfflineRenderer.render(project: demoProject(), bars: 16)
        let needle = [UInt8(0xFF), 0x06, UInt8("HARM:+5".utf8.count)] + Array("HARM:+5".utf8)
        #expect(containsSub(bytes, needle))
    }
}

// MARK: - Golden master (FR-UX-1, spec §12.1)

@Suite("Golden master")
struct GoldenMasterTests {

    @Test("render(demo, 16 bars) byte-equals the committed golden")
    func demo16() throws {
        let url = Bundle.module.url(forResource: "Goldens/demo16", withExtension: "mid")
        let golden = [UInt8](try Data(contentsOf: try #require(url)))
        let rendered = OfflineRenderer.render(project: demoProject(), bars: 16)
        #expect(rendered == golden,
                "Engine output changed. If intentional, regenerate the golden and justify in the commit message.")
    }
}

private func containsSub(_ haystack: [UInt8], _ needle: [UInt8]) -> Bool {
    guard needle.count <= haystack.count else { return false }
    return (0...(haystack.count - needle.count)).contains { start in
        Array(haystack[start..<(start + needle.count)]) == needle
    }
}
