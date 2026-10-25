import SwiftUI

/// App settings (Berlinan ▸ Settings…, ⌘,) — machine-wide preferences, as
/// opposed to the per-project SettingsSheet. Phase 56: auto-update.
struct AppSettingsView: View {
    let updates: UpdateService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("UPDATES")
                .font(AppFont.sansBold(11))
                .tracking(AppTracking.label)
                .foregroundStyle(AppColor.tangerine)

            Toggle(isOn: Binding(get: { updates.checksAtLaunch },
                                 set: { updates.setChecksAtLaunch($0) })) {
                Text("Check for updates when Berlinan starts")
                    .font(AppFont.body)
                    .foregroundStyle(AppColor.ink)
            }
            .toggleStyle(.checkbox)

            Text("When a new version is out, Berlinan offers it. Nothing is downloaded or installed until you agree.")
                .font(AppFont.monoCaption)
                .foregroundStyle(AppColor.ink3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Version \(updates.version)")
                    .font(AppFont.monoCaption)
                    .foregroundStyle(AppColor.ink3)
                Spacer()
                Button("Check Now") { updates.checkNow() }
                    .disabled(!updates.canCheck)
            }
        }
        .padding(18)
        .frame(width: 420)
        .background(AppColor.bgWindow)
        .preferredColorScheme(.dark)
    }
}
