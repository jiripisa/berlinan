import SwiftUI
import BerlinanEngine

/// Phase-01 skeleton window: proves the bundle launches, the design tokens
/// render, and the engine is linked. Replaced by the real main window in M2.
struct ContentView: View {
    var body: some View {
        ZStack {
            AppColor.bgWindow.ignoresSafeArea()

            VStack(spacing: 10) {
                Text("BERLINAN")
                    .font(AppFont.sansBold(14))
                    .tracking(AppTracking.label * 2)
                    .foregroundStyle(AppColor.tangerine)

                Text("generative berlin school sequencer")
                    .font(AppFont.monoCaption)
                    .tracking(AppTracking.caption)
                    .foregroundStyle(AppColor.ink2)

                Text("engine \(EngineInfo.version) — skeleton build (M1 / phase 01)")
                    .font(AppFont.monoCaption)
                    .foregroundStyle(AppColor.ink3)
            }
            .padding(24)
            .background(AppColor.bgPanel)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppColor.line, lineWidth: 1)
            )
        }
        .frame(minWidth: 640, minHeight: 400)
    }
}
