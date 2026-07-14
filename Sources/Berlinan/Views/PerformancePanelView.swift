import SwiftUI
import BerlinanEngine

/// Performance panel (spec §11.4, M2 subset): degree buttons 1–7 for global
/// diatonic transposition (binds at the next bar), re-roll, capture export.
struct PerformancePanelView: View {
    let ui: UIState

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Text("DEG")
                    .font(AppFont.fieldLabel)
                    .tracking(AppTracking.field)
                    .foregroundStyle(AppColor.ink4)
                ForEach(1...7, id: \.self) { degree in
                    degreeButton(degree)
                }
            }

            Rectangle().fill(AppColor.line).frame(width: 1, height: 20)

            Button {
                ui.rerollAllUnlocked()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "dice")
                        .font(.system(size: 10, weight: .medium))
                    Text("RE-ROLL UNLOCKED")
                        .font(AppFont.sansBold(9.5))
                        .tracking(AppTracking.label)
                }
                .foregroundStyle(AppColor.ink2)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(AppColor.bgPanel)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColor.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Regenerate every unlocked voice at its next loop")

            Spacer()

            Menu {
                ForEach([8, 16, 32, 64], id: \.self) { bars in
                    Button("Last \(bars) bars…") { ui.exportCapture(lastBars: bars) }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 10, weight: .medium))
                    Text("EXPORT CAPTURE")
                        .font(AppFont.sansBold(9.5))
                        .tracking(AppTracking.label)
                }
                .foregroundStyle(AppColor.ink2)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(AppColor.bgPanel)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColor.line, lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Export the last N whole bars of everything played (.mid)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColor.bgPanel)
    }

    private func degreeButton(_ degree: Int) -> some View {
        let active = ui.degreeOffset == degree - 1
        return Button {
            ui.pressDegree(degree)
        } label: {
            Text("\(degree)")
                .font(AppFont.monoBold(13))
                .foregroundStyle(active ? AppColor.tangerine : AppColor.ink2)
                .frame(width: 30, height: 26)
                .background(active ? AppColor.tangerineGlow : AppColor.bgPanel2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4)
                    .stroke(active ? AppColor.tangerineLine : AppColor.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character("\(degree)")), modifiers: [])
        .help("Transpose all voices to degree \(degree) at the next bar")
    }
}
