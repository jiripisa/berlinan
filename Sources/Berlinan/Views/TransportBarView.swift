import SwiftUI
import BerlinanEngine

/// Transport bar (spec §11.1, design_language.md §5): play/stop, bar:beat,
/// BPM, key, current degree, MIDI status.
struct TransportBarView: View {
    let ui: UIState
    let midiStatus: String
    let midiUp: Bool

    var body: some View {
        HStack(spacing: 16) {
            Button {
                ui.togglePlayback()
            } label: {
                Image(systemName: ui.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ui.isPlaying ? AppColor.rec : AppColor.tangerine)
                    .frame(width: 44, height: 28)
                    .background(ui.isPlaying ? AppColor.recGlow : AppColor.tangerineGlow)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(ui.isPlaying ? AppColor.recLine : AppColor.tangerineLine,
                                lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])

            field("POS") {
                Text(ui.barBeatText)
                    .font(AppFont.timecodeBig)
                    .foregroundStyle(ui.isPlaying ? AppColor.ink : AppColor.ink3)
                    .monospacedDigit()
                    .frame(minWidth: 64, alignment: .trailing)
            }

            field("BPM") {
                Text(String(format: "%.0f", ui.project.bpm))
                    .font(AppFont.timecodeBig)
                    .foregroundStyle(AppColor.ink2)
            }

            field("KEY") {
                Text(ui.keyText)
                    .font(AppFont.monoCaption)
                    .foregroundStyle(AppColor.ink2)
            }

            field("DEG") {
                Text(ui.degreeOffset == 0 ? "1" : String(format: "%+d", ui.degreeOffset))
                    .font(AppFont.monoBold(16))
                    .foregroundStyle(ui.degreeOffset == 0 ? AppColor.ink2 : AppColor.tangerine)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(midiUp ? AppColor.green : AppColor.rec)
                    .frame(width: 6, height: 6)
                    .shadow(color: (midiUp ? AppColor.green : AppColor.rec).opacity(0.6),
                            radius: 2)
                Text(midiStatus)
                    .font(AppFont.monoCaption)
                    .foregroundStyle(AppColor.ink3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColor.toolbarGradient)
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppFont.fieldLabel)
                .tracking(AppTracking.field)
                .foregroundStyle(AppColor.ink4)
            content()
        }
    }
}
