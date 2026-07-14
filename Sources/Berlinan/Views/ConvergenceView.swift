import SwiftUI
import BerlinanEngine

/// Convergence readout (FR-PH-4, spec §11.3): the LCM of active loop lengths
/// in bars and wall-clock time — cyan, the informational accent.
struct ConvergenceView: View {
    let ui: UIState

    var body: some View {
        HStack(spacing: 8) {
            Text("LCM")
                .font(AppFont.fieldLabel)
                .tracking(AppTracking.field)
                .foregroundStyle(AppColor.ink4)
            Text(text)
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.cyan)
            Spacer()
            Text("engine \(EngineInfo.version)")
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.ink4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppColor.bgPanel3)
    }

    private var text: String {
        let lengths = ui.voices.map(\.pattern.length)
        guard !lengths.isEmpty, let period = Convergence.period(lengths: lengths) else {
            return "∞ (practically)"
        }
        let bars = Convergence.bars(period: period, meter: ui.project.meter)
        let seconds = Convergence.seconds(period: period, bpm: ui.project.bpm)
        let barsText = bars.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(bars)) : String(format: "%.1f", bars)
        return "\(barsText) bars ≈ \(Int(seconds.rounded())) s"
    }
}
