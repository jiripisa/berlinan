import SwiftUI
import BerlinanEngine

/// Project settings (phase 19; runtime changes arrive in M4 per FR-GS-5).
/// Applying rebuilds the transport over the modified project — patterns
/// regenerate deterministically from the same seeds in the new key/meter.
struct SettingsSheet: View {
    let services: AppServices
    @Environment(\.dismiss) private var dismiss

    @State private var root = 0
    @State private var mode: ModeID = .naturalMinor
    @State private var bpm = 90.0
    @State private var meterIndex = 0

    private static let noteNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
    /// Meter presets with the manual's groupings (M §9.3).
    private static let meters: [(label: String, meter: Meter)] = [
        ("4/4", .fourFour),
        ("3/4", Meter(beatsPerBar: 3, beatUnit: 4)),
        ("6/8", Meter(beatsPerBar: 6, beatUnit: 8, grouping: [3, 3])),
        ("7/8 (4+3)", Meter(beatsPerBar: 7, beatUnit: 8, grouping: [4, 3])),
        ("7/8 (3+4)", Meter(beatsPerBar: 7, beatUnit: 8, grouping: [3, 4])),
        ("5/4 (3+2)", Meter(beatsPerBar: 5, beatUnit: 4, grouping: [3, 2])),
        ("5/8 (3+2)", Meter(beatsPerBar: 5, beatUnit: 8, grouping: [3, 2])),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PROJECT SETTINGS")
                .font(AppFont.sansBold(11))
                .tracking(AppTracking.label)
                .foregroundStyle(AppColor.tangerine)

            HStack(spacing: 12) {
                labeled("ROOT") {
                    Picker("", selection: $root) {
                        ForEach(0..<12, id: \.self) { Text(Self.noteNames[$0]).tag($0) }
                    }
                    .labelsHidden().frame(width: 70)
                }
                labeled("MODE") {
                    Picker("", selection: $mode) {
                        ForEach(ModeID.allCases.filter { $0 != .custom }, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .labelsHidden().frame(width: 160)
                }
            }

            HStack(spacing: 12) {
                labeled("BPM") {
                    HStack(spacing: 6) {
                        Text("\(Int(bpm))")
                            .font(AppFont.timecodeBig)
                            .foregroundStyle(AppColor.ink)
                            .frame(width: 44, alignment: .trailing)
                        Stepper("", value: $bpm, in: 40...220, step: 1)
                            .labelsHidden()
                    }
                }
                labeled("METER") {
                    Picker("", selection: $meterIndex) {
                        ForEach(Self.meters.indices, id: \.self) {
                            Text(Self.meters[$0].label).tag($0)
                        }
                    }
                    .labelsHidden().frame(width: 120)
                }
            }

            Text("applying regenerates the patterns in the new key/meter\n(seeds unchanged — the material stays recognizable)")
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.ink4)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Apply") {
                    var project = services.project
                    project.key = Key(root: root, scale: .preset(mode))
                    project.bpm = bpm
                    project.meter = Self.meters[meterIndex].meter
                    services.applyProject(project)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 420)
        .background(AppColor.bgWindow)
        .onAppear {
            let project = services.project
            root = project.key.root
            mode = project.key.scale.mode
            bpm = project.bpm
            meterIndex = Self.meters.firstIndex {
                $0.meter == project.meter
            } ?? 0
        }
    }

    private func labeled(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(AppFont.fieldLabel)
                .tracking(AppTracking.field)
                .foregroundStyle(AppColor.ink4)
            content()
        }
    }
}
