import SwiftUI
import BerlinanEngine

/// Skeleton window: proves the bundle launches, the design tokens render,
/// the engine is linked, and the MIDI port is up. Replaced by the real main
/// window later in M2.
struct ContentView: View {
    let services: AppServices

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

                Text("engine \(EngineInfo.version) — skeleton build (M2)")
                    .font(AppFont.monoCaption)
                    .foregroundStyle(AppColor.ink3)

                HStack(spacing: 6) {
                    Circle()
                        .fill(services.midi != nil ? AppColor.green : AppColor.rec)
                        .frame(width: 6, height: 6)
                    Text(services.midiStatus)
                        .font(AppFont.monoCaption)
                        .foregroundStyle(AppColor.ink2)
                }
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
