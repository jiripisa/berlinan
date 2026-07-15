import SwiftUI
import BerlinanEngine

/// Transport bar (spec §11.1, design_language.md §5): play/stop, bar:beat,
/// BPM, key, current degree, MIDI status.
struct TransportBarView: View {
    let ui: UIState
    let midiStatus: String
    let midiUp: Bool
    var onSettings: () -> Void = {}

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
                Text(ui.bpmText)
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

            Button {
                ui.newSeed()
            } label: {
                Image(systemName: "dice")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColor.tangerine)
                    .frame(width: 28, height: 24)
                    .background(AppColor.tangerineGlow)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(AppColor.tangerineLine, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: [])
            .help("New seed — a whole new musical universe (live: at the next bar; ⌘Z undoes)")

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColor.ink2)
                    .frame(width: 28, height: 24)
                    .background(AppColor.bgPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(AppColor.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Project settings (key + tempo work while playing)")

            Menu {
                Button("INT — Berlinan is clock master") { ui.setSyncExternal(false) }
                Button("EXT — follow incoming MIDI clock") { ui.setSyncExternal(true) }
            } label: {
                Text(ui.syncMode == .externalClock ? "EXT" : "INT")
                    .font(AppFont.monoBold(10))
                    .foregroundStyle(ui.syncMode == .externalClock ? AppColor.cyan : AppColor.ink2)
                    .frame(width: 34, height: 22)
                    .background(ui.syncMode == .externalClock ? AppColor.cyanGlow : AppColor.bgPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(ui.syncMode == .externalClock ? AppColor.cyanLine : AppColor.line,
                                lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(ui.isPlaying)
            .help("Clock source (FR-IO-4). EXT: Berlinan follows Start/Stop and tempo of incoming MIDI clock (enable Sync OUT to Berlinan in Ableton)")

            HStack(spacing: 6) {
                Circle()
                    .fill(midiUp ? AppColor.green : AppColor.rec)
                    .frame(width: 6, height: 6)
                    .shadow(color: (midiUp ? AppColor.green : AppColor.rec).opacity(0.6),
                            radius: 2)
                Text(ui.syncMode == .externalClock && !ui.isPlaying
                     ? "EXT — waiting for clock" : midiStatus)
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
