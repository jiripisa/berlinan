import SwiftUI
import AppKit
import BerlinanEngine

/// Delay Cheat Sheet (FR-MOD-8, design_language.md §5): a studio reference
/// card — per voice the recommended AUDIO delay settings at the project
/// tempo, copyable. The "ducka-ducka" groove lives in the DAW's delay; this
/// tells the producer exactly what to dial in.
struct DelayCheatSheetView: View {
    let services: AppServices

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DELAY CHEAT SHEET")
                .font(AppFont.sansBold(11))
                .tracking(AppTracking.label)
                .foregroundStyle(AppColor.tangerine)
                .padding(.bottom, 2)
            Text("audio delay per voice @ \(Int(services.project.bpm)) BPM · manual §9.1")
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.ink3)
                .padding(.bottom, 12)

            header
            ForEach(services.project.voices, id: \.id) { voice in
                row(for: voice)
            }

            Spacer(minLength: 12)
            Text("feedback ~50% · wet ~50% · ping-pong · low+high cut on repeats\nso echoes recede into the distance")
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.ink4)
        }
        .padding(16)
        .frame(minWidth: 460, minHeight: 260, alignment: .topLeading)
        .background(AppColor.bgWindow)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text("VOICE").frame(width: 110, alignment: .leading)
            Text("DIVISION").frame(width: 90, alignment: .leading)
            Text("TIME").frame(width: 70, alignment: .trailing)
            Spacer()
        }
        .font(AppFont.fieldLabel)
        .tracking(AppTracking.field)
        .foregroundStyle(AppColor.ink4)
        .padding(.vertical, 4)
        .overlay(Rectangle().fill(AppColor.line).frame(height: 1), alignment: .bottom)
    }

    private func row(for voice: VoiceConfig) -> some View {
        let hint = DelayHint.compute(role: voice.role, bpm: services.project.bpm)
        let midiDelayOn = voice.midiDelay?.enabled == true
        return HStack {
            Text(voice.id)
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.ink)
                .frame(width: 110, alignment: .leading)
            Text(hint.division.label)
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.cyan)
                .frame(width: 90, alignment: .leading)
            Text("\(Int(hint.milliseconds.rounded())) ms")
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.ink2)
                .frame(width: 70, alignment: .trailing)
            if midiDelayOn {
                // FR-MOD-8 interplay: don't stack MIDI echoes with audio delay.
                Text("⚠ echoes already in MIDI — disable/lower the audio delay")
                    .font(AppFont.monoCaption)
                    .foregroundStyle(AppColor.amber)
                    .padding(.leading, 8)
            }
            Spacer()
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString("\(voice.id): \(hint.summary)", forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColor.ink3)
            }
            .buttonStyle(.plain)
            .help("Copy settings")
        }
        .padding(.vertical, 6)
        .overlay(Rectangle().fill(AppColor.lineSoft).frame(height: 1), alignment: .bottom)
    }
}
