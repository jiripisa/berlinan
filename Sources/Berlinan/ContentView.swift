import SwiftUI
import BerlinanEngine

/// The main window (spec §11): transport bar / voice lanes / convergence
/// footer. Documents and the performance panel arrive in later phases.
struct ContentView: View {
    let services: AppServices
    let ui: UIState

    var body: some View {
        Group {
                VStack(spacing: 0) {
                    TransportBarView(ui: ui,
                                     midiStatus: services.midiStatus,
                                     midiUp: services.midi != nil)
                    Rectangle().fill(AppColor.line).frame(height: 1)
                    HarmonyStripView(ui: ui, services: services)
                    Rectangle().fill(AppColor.lineSoft).frame(height: 1)

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(ui.voices, id: \.id) { voice in
                                VoiceLaneView(ui: ui, voice: voice)
                            }
                        }
                        .padding(12)
                    }
                    .background(AppColor.bgWindow)

                    Rectangle().fill(AppColor.lineSoft).frame(height: 1)
                    PerformancePanelView(ui: ui)
                    Rectangle().fill(AppColor.lineSoft).frame(height: 1)
                    ConvergenceView(ui: ui)
                }
        }
        .frame(minWidth: 760, minHeight: 380)
        .background(AppColor.bgWindow.ignoresSafeArea())
        .onAppear { ui.startMirror() }
        .onDisappear { ui.stopMirror() }
    }
}
