import Foundation
import BerlinanEngine

let usage = """
berlinan-cli — headless renderer for the Berlinan generative sequencer

USAGE:
  berlinan-cli --version                    print engine version
  berlinan-cli --help                       show this help
  berlinan-cli demo -o <project.json>       write the default demo project
  berlinan-cli render <project.json> --bars <n> -o <out.mid>
                                            render a project to a Standard MIDI File
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(64)
}

func flagValue(_ args: [String], _ flag: String) -> String? {
    guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
    return args[idx + 1]
}

let args = Array(CommandLine.arguments.dropFirst())

switch args.first {
case "--version":
    print("berlinan-cli \(EngineInfo.version)")

case "demo":
    guard let out = flagValue(args, "-o") else { fail("demo: missing -o <project.json>") }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
        try (try encoder.encode(Project.demo)).write(to: URL(fileURLWithPath: out))
        print("Wrote demo project: \(out)")
    } catch {
        fail("demo: \(error.localizedDescription)")
    }

case "render":
    guard args.count >= 2 else { fail("render: missing <project.json>\n\n\(usage)") }
    let projectPath = args[1]
    guard let barsText = flagValue(args, "--bars"), let bars = Int(barsText), bars > 0 else {
        fail("render: missing or invalid --bars <n>")
    }
    guard let out = flagValue(args, "-o") else { fail("render: missing -o <out.mid>") }

    let project: Project
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: projectPath))
        project = try JSONDecoder().decode(Project.self, from: data)
        try project.validate()
    } catch let error as Project.ValidationError {
        fail("render: invalid project — \(error.description)")
    } catch {
        fail("render: cannot read project — \(error.localizedDescription)")
    }

    let bytes = OfflineRenderer.render(project: project, bars: bars)
    do {
        try Data(bytes).write(to: URL(fileURLWithPath: out))
    } catch {
        fail("render: cannot write output — \(error.localizedDescription)")
    }

    // Producer summary incl. the convergence period (FR-PH-4).
    let lengths = project.voices.map { config -> Tick in
        let seed = SeedStream.derive(master: project.masterSeed, "voice", config.id, "gen0")
        var pattern = PatternFactory.make(id: config.id, config: config.generator,
                                          role: config.role, key: project.key,
                                          meter: project.meter, seed: seed)
        if let steps = config.phaseSteps, steps != 0 {
            pattern = pattern.withLength(pattern.length + Tick(steps) * (project.meter.ticksPerBeat / 4))
        }
        return pattern.length
    }
    let noteNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
    print("Rendered \(bars) bars @ \(project.bpm) BPM, "
        + "\(noteNames[project.key.root]) \(project.key.scale.mode.rawValue), "
        + "\(project.meter.beatsPerBar)/\(project.meter.beatUnit)")
    for (config, length) in zip(project.voices, lengths) {
        let steps = length / (project.meter.ticksPerBeat / 4)
        print("  \(config.id) [ch \(config.channel + 1)] — loop \(steps) steps")
    }
    if let period = Convergence.period(lengths: lengths) {
        let bars = Convergence.bars(period: period, meter: project.meter)
        let secs = Convergence.seconds(period: period, bpm: project.bpm)
        print("Convergence: \(bars) bars ≈ \(Int(secs.rounded())) s")
    } else {
        print("Convergence: ∞ (practically)")
    }
    print("Output: \(out)")

case "--help", nil:
    print(usage)

default:
    fail("unknown argument: \(args[0])\n\n\(usage)")
}
