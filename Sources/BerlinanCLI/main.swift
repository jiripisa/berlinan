import Foundation
import BerlinanEngine

let usage = """
berlinan-cli — headless renderer for the Berlinan generative sequencer

USAGE:
  berlinan-cli --version              print engine version
  berlinan-cli --help                 show this help
  berlinan-cli render <project.json> --bars <n> -o <out.mid>
                                      render a project to a Standard MIDI File
"""

let args = Array(CommandLine.arguments.dropFirst())

switch args.first {
case "--version":
    print("berlinan-cli \(EngineInfo.version)")
case "render":
    // Implemented in phase 09 (M1) once SMF export and generators exist.
    FileHandle.standardError.write(Data("render: not implemented yet (M1 phase 09)\n".utf8))
    exit(2)
case "--help", nil:
    print(usage)
default:
    FileHandle.standardError.write(Data("unknown argument: \(args[0])\n\n\(usage)\n".utf8))
    exit(64)
}
