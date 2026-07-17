import SwiftUI
import AppKit
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

            // Snapshot slots (FR-L-6): click = recall (next bar),
            // ⌥-click = save.
            HStack(spacing: 4) {
                Text("SNAP")
                    .font(AppFont.fieldLabel)
                    .tracking(AppTracking.field)
                    .foregroundStyle(AppColor.ink4)
                ForEach(0..<6, id: \.self) { slot in
                    snapshotButton(slot)
                }
            }

            Rectangle().fill(AppColor.line).frame(width: 1, height: 20)

            Button {
                ui.perform(.rerollUnlocked)
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

            Button {
                ui.perform(.fireBPart)
            } label: {
                Text("B")
                    .font(AppFont.monoBold(13))
                    .foregroundStyle(AppColor.ink2)
                    .frame(width: 30, height: 26)
                    .background(AppColor.bgPanel2)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColor.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!ui.isPlaying)
            .help("B-part: start a progression, swap the bass, drop the bed — one move at the next bar (MIDI-learnable)")

            Button {
                ui.spendTension()
            } label: {
                Text("T·\(ui.tensionRemaining)")
                    .font(AppFont.monoBold(11))
                    .foregroundStyle(ui.tensionRemaining > 0 ? AppColor.ink2 : AppColor.ink4)
                    .frame(width: 34, height: 26)
                    .background(AppColor.bgPanel2)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColor.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(!ui.isPlaying || ui.tensionRemaining == 0)
            .help("Tension budget (M §4.4): spend one of \(ui.tensionRemaining) out-of-key allowances — a sustained minor 2nd against the root at the next bar")

            Rectangle().fill(AppColor.line).frame(width: 1, height: 20)

            // Arranger autopilot (FR-A-1/6): advisory — AUTO toggles it,
            // ">>" fires the next change at the next bar.
            HStack(spacing: 4) {
                Text("ARR")
                    .font(AppFont.fieldLabel)
                    .tracking(AppTracking.field)
                    .foregroundStyle(AppColor.ink4)

                Button {
                    ui.setArrangerEnabled(ui.arrangement == nil)
                } label: {
                    Text("AUTO")
                        .font(AppFont.sansBold(9.5))
                        .tracking(AppTracking.label)
                        .foregroundStyle(ui.arrangement != nil ? AppColor.tangerine : AppColor.ink2)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(ui.arrangement != nil ? AppColor.tangerineGlow : AppColor.bgPanel2)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(ui.arrangement != nil ? AppColor.tangerineLine : AppColor.line,
                                    lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Arranger autopilot: builds, varies, subtracts and ends the piece by itself — you stay in charge (every move is also a manual control)")

                if let status = ui.arrangement {
                    Text("\(phaseLabel(status.phase)) · \(status.barsInPhase)")
                        .font(AppFont.monoMedium(10))
                        .foregroundStyle(AppColor.ink3)
                        .frame(height: 26)
                        .padding(.horizontal, 6)
                        .background(AppColor.bgPanel2)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .help("Arranger phase · bars in phase")

                    Button {
                        ui.perform(.advancePhase)
                    } label: {
                        Image(systemName: "forward.frame")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColor.ink2)
                            .frame(width: 26, height: 26)
                            .background(AppColor.bgPanel2)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4)
                                .stroke(AppColor.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!ui.isPlaying)
                    .help("Advance now: fire the arranger's next change at the next bar (MIDI-learnable)")
                }

                Button {
                    ui.setAmbientMode(!ui.ambientMode)
                } label: {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ui.ambientMode ? AppColor.cyan : AppColor.ink3)
                        .frame(width: 26, height: 26)
                        .background(ui.ambientMode ? AppColor.cyanGlow : AppColor.bgPanel2)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(ui.ambientMode ? AppColor.cyanLine : AppColor.line,
                                    lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(ui.isPlaying)
                .help("Ambient mode: ~1 change per minute, patterns legitimize over 16 plays (set while stopped)")

                // Density macro (FR-A-3): 0–1, binds at the next bar.
                HStack(spacing: 4) {
                    Text("DENS")
                        .font(AppFont.fieldLabel)
                        .tracking(AppTracking.field)
                        .foregroundStyle(AppColor.ink4)
                    Slider(value: Binding(get: { ui.density },
                                          set: { ui.setDensity($0) }),
                           in: 0...1)
                        .controlSize(.mini)
                        .tint(AppColor.tangerine)
                        .frame(width: 70)
                    Text(String(format: "%.0f%%", ui.density * 100))
                        .font(AppFont.monoMedium(9))
                        .foregroundStyle(AppColor.ink3)
                        .frame(width: 30, alignment: .trailing)
                }
                .help("Density: caps notes per loop (accents survive first); the arranger raises it at payoff and thins on the way out")
            }

            Spacer()

            Button {
                ui.toggleLearnMode()
            } label: {
                Text(ui.learnMode ? (ui.armedMacro != nil ? "MOVE A KNOB…" : "LEARN: PICK A CONTROL") : "LEARN")
                    .font(AppFont.sansBold(9.5))
                    .tracking(AppTracking.label)
                    .foregroundStyle(ui.learnMode ? AppColor.amber : AppColor.ink2)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(ui.learnMode ? AppColor.amber.opacity(0.18) : AppColor.bgPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(ui.learnMode ? AppColor.amber.opacity(0.45) : AppColor.line,
                                lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("MIDI learn: enable, click a control (degree/re-roll/dice/slot/play), then move a knob or press a pad on your controller (input: 'Berlinan Control')")

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

    private func phaseLabel(_ phase: ArrangementPhase) -> String {
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

    private func snapshotButton(_ slot: Int) -> some View {
        let filled = ui.snapshotSlots[slot] != nil
        return Button {
            if NSEvent.modifierFlags.contains(.option) {
                ui.saveSnapshot(slot: slot)
            } else {
                ui.perform(.recallSlot(slot))
            }
        } label: {
            Text("\(slot + 1)")
                .font(AppFont.monoMedium(11))
                .foregroundStyle(filled ? AppColor.cyan : AppColor.ink4)
                .frame(width: 24, height: 26)
                .background(filled ? AppColor.cyanGlow : AppColor.bgPanel2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4)
                    .stroke(filled ? AppColor.cyanLine : AppColor.line,
                            style: StrokeStyle(lineWidth: 1,
                                               dash: filled ? [] : [3, 2])))
        }
        .buttonStyle(.plain)
        .help("Click = recall at next bar · ⌥-click = save snapshot")
    }

    private func degreeButton(_ degree: Int) -> some View {
        let active = ui.degreeOffset == degree - 1
        return Button {
            ui.perform(.degree(degree))
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
