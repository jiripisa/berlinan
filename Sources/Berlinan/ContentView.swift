import SwiftUI
import BerlinanEngine

/// The main window (spec §11): transport bar / voice lanes / convergence
/// footer. Documents and the performance panel arrive in later phases.
struct ContentView: View {
    let services: AppServices
    @State private var ui: UIState?

    var body: some View {
        Group {
            if let ui {
                VStack(spacing: 0) {
                    TransportBarView(ui: ui,
                                     midiStatus: services.midiStatus,
                                     midiUp: services.midi != nil)
                    Rectangle().fill(AppColor.line).frame(height: 1)

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
                    ConvergenceView(ui: ui)
                }
            } else {
                AppColor.bgWindow
            }
        }
        .frame(minWidth: 760, minHeight: 380)
        .background(AppColor.bgWindow.ignoresSafeArea())
        .onAppear {
            if ui == nil {
                let state = UIState(services: services)
                state.startMirror()
                ui = state
            }
        }
        .onDisappear {
            ui?.stopMirror()
        }
    }
}
