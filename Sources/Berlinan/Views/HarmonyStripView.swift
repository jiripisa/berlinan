import SwiftUI
import BerlinanEngine

/// Harmony strip (FR-H-9, spec §11.3): active mode, upcoming transposition
/// events, next-event countdown. Mode picker is enabled while stopped.
struct HarmonyStripView: View {
    let ui: UIState
    let services: AppServices

    var body: some View {
        HStack(spacing: 12) {
            Text("HARMONY")
                .font(AppFont.fieldLabel)
                .tracking(AppTracking.field)
                .foregroundStyle(AppColor.ink3)

            Menu {
                Button("Manual schedule (demo walk)") { services.setHarmonyMode(nil) }
                Menu("Progression") {
                    ForEach(Progression.presets, id: \.name) { preset in
                        Button(preset.name) {
                            services.setHarmonyMode(.progression(preset))
                        }
                    }
                }
                Button("Weighted random (sweet/dark)") {
                    services.setHarmonyMode(.weightedRandom(
                        weights: HarmonyModeConfig.defaultWeights,
                        minPeriodBars: 8, maxPeriodBars: 16))
                }
                Menu("Bass reharmonization") {
                    ForEach(Progression.presets, id: \.name) { preset in
                        Button(preset.name) {
                            services.setHarmonyMode(.bassReharm(preset))
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(modeLabel)
                        .font(AppFont.monoCaption)
                        .foregroundStyle(ui.isPlaying ? AppColor.ink3 : AppColor.ink)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(AppColor.ink3)
                }
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(AppColor.bgPanel2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColor.line, lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(ui.isPlaying)
            .help(ui.isPlaying ? "Stop playback to change the harmony mode"
                               : "Harmony mode (FR-H-4/5/6)")

            if let next = ui.nextHarmonyEventText {
                Text(next)
                    .font(AppFont.monoCaption)
                    .foregroundStyle(AppColor.cyan)
            }

            Spacer()

            // Upcoming events as chips (nearest 4).
            HStack(spacing: 4) {
                ForEach(ui.upcomingHarmonyEvents.prefix(4), id: \.bar) { event in
                    Text("\(event.degreeOffset == 0 ? "1" : String(format: "%+d", event.degreeOffset))@\(event.bar + 1)")
                        .font(AppFont.monoCaption)
                        .foregroundStyle(AppColor.ink3)
                        .padding(.horizontal, 6)
                        .frame(height: 18)
                        .background(AppColor.bgPanel2)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppColor.bgPanel3)
    }

    private var modeLabel: String {
        switch services.project.harmony {
        case nil: return "manual schedule"
        case .progression(let p): return "prog: \(p.name)"
        case .weightedRandom: return "weighted random"
        case .bassReharm(let p): return "bass reharm: \(p.name)"
        }
    }
}
