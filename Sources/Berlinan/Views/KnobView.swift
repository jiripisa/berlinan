import SwiftUI

/// Small rotary control (phase 61, CC LFO depth/phase): drag up/down —
/// about 150 pt sweeps the whole range. Tangerine arc = the value.
struct KnobView: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    let label: String
    var readout: (Double) -> String = { "\(Int(($0 * 100).rounded()))%" }
    var disabled = false
    var help: String = ""

    @State private var dragStart: Double? = nil

    private var fraction: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .stroke(AppColor.lineStrong, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                Circle()
                    .trim(from: 0.125, to: 0.125 + 0.75 * fraction)
                    .stroke(disabled ? AppColor.ink4 : AppColor.tangerine,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            .rotationEffect(.degrees(90))
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .gesture(drag)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(AppFont.fieldLabel)
                    .tracking(AppTracking.field)
                    .foregroundStyle(disabled ? AppColor.ink4 : AppColor.ink3)
                Text(readout(value))
                    .font(AppFont.monoCaption)
                    .monospacedDigit()
                    .foregroundStyle(disabled ? AppColor.ink4 : AppColor.ink2)
            }
        }
        .help(help)
        .allowsHitTesting(!disabled)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                let start = dragStart ?? value
                if dragStart == nil { dragStart = start }
                let span = range.upperBound - range.lowerBound
                let moved = start - Double(gesture.translation.height) / 150 * span
                value = min(range.upperBound, max(range.lowerBound, moved))
            }
            .onEnded { _ in dragStart = nil }
    }
}
