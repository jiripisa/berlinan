import SwiftUI
import BerlinanEngine

/// Horizon strip (phase 32): read-only narration of what is about to
/// happen — pending bar-bound changes, the arranger's countdown, and the
/// nearest mutation coming due. The trust layer: never a black box.
struct HorizonStripView: View {
    let ui: UIState

    var body: some View {
        HStack(spacing: 8) {
            Text("HORIZON")
                .font(AppFont.fieldLabel)
                .tracking(AppTracking.field)
                .foregroundStyle(AppColor.ink4)

            if let template = ui.pendingTemplateName {
                chip(icon: "square.grid.2x2",
                     text: "TEMPLATE \(template.uppercased()) · next bar",
                     color: AppColor.cyan)
            }

            if let status = ui.arrangement {
                chip(icon: "wand.and.stars",
                     text: "\(phaseName(status.phase)) · change in ~\(barCount(max(0, status.barsUntilChange)))",
                     color: AppColor.tangerine)
            }

            ForEach(Array(ui.upcomingEvents.prefix(6).enumerated()),
                    id: \.offset) { _, event in
                chip(icon: icon(for: event.kind),
                     text: "\(label(for: event))\(barsAway(event.tick))",
                     color: AppColor.cyan)
            }

            if let mutation = nearestMutation() {
                chip(icon: "arrow.triangle.2.circlepath",
                     text: mutation, color: AppColor.ink3)
            }

            if ui.pendingTemplateName == nil && ui.arrangement == nil
                && ui.upcomingEvents.isEmpty && nearestMutation() == nil {
                Text("steady — nothing scheduled")
                    .font(AppFont.monoCaption)
                    .foregroundStyle(AppColor.ink4)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(AppColor.bgPanel)
        .overlay(Rectangle().fill(AppColor.line).frame(height: 1),
                 alignment: .bottom)
    }

    private func chip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 8, weight: .medium))
            Text(text).font(AppFont.monoMedium(9.5))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    /// " · in N bars" from the bind tick, when the transport runs.
    private func barsAway(_ tick: Tick) -> String {
        guard let now = ui.currentTick, ui.isPlaying else { return " · next bar" }
        let barTicks = ui.project.meter.ticksPerBar
        let away = max(0, Int((tick - min(tick, now)) / barTicks))
        return away <= 1 ? " · next bar" : " · in \(away) bars"
    }

    /// The soonest unlocked voice whose verbatim plays are nearly served.
    private func nearestMutation() -> String? {
        let barTicks = ui.project.meter.ticksPerBar
        return ui.voices.compactMap { voice -> (String, Int)? in
            guard voice.active, !voice.pattern.locked,
                  case .repeating(let remaining) = voice.pattern.lifecycle
            else { return nil }
            let bars = remaining * max(1, Int(voice.pattern.length / barTicks))
            return (ui.voiceName(voice.id), bars)
        }
        .min { $0.1 < $1.1 }
        .map { "\($0.0) may mutate · ~\(barCount($0.1))" }
    }

    private func barCount(_ bars: Int) -> String {
        bars == 1 ? "1 bar" : "\(bars) bars"
    }

    private func phaseName(_ phase: ArrangementPhase) -> String {
        switch phase {
        case .build: "BUILD"
        case .bed: "BED"
        case .variation: "VAR"
        case .bPart: "B-PART"
        case .payoff: "PAYOFF"
        case .subtract: "SUBTR"
        case .ending: "END"
        }
    }

    private func icon(for kind: LiveEngine.UpcomingEvent.Kind) -> String {
        switch kind {
        case .key: "music.note.list"
        case .recall: "clock.arrow.circlepath"
        case .density: "slider.horizontal.3"
        case .bPart: "b.square"
        case .voiceActive: "power"
        case .alternating: "arrow.left.arrow.right"
        case .tension: "bolt"
        case .promoteToLead: "arrow.up.right"
        case .arranger: "wand.and.stars"
        case .advance: "forward.frame"
        case .scene: "camera.filters"
        }
    }

    private func voiceName(_ event: LiveEngine.UpcomingEvent) -> String {
        event.voiceID.map(ui.voiceName) ?? event.detail
    }

    private func label(for event: LiveEngine.UpcomingEvent) -> String {
        switch event.kind {
        case .key: "KEY \(NoteNames.name(root: Int(event.detail) ?? 0))"
        case .recall: "RECALL"
        case .density: "DENS \(event.detail)"
        case .bPart: "B-PART"
        case .voiceActive: "\(voiceName(event).uppercased()) \(event.detail)"
        case .alternating: "ALT \(event.detail)"
        case .tension: "TENSION"
        case .promoteToLead: "LEAD ← \(voiceName(event).uppercased())"
        case .arranger: "AUTO \(event.detail)"
        case .advance: "ADVANCE"
        case .scene: "SCENE \(event.detail)"
        }
    }
}

private enum NoteNames {
    static func name(root: Int) -> String {
        ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"][
            ((root % 12) + 12) % 12]
    }
}
