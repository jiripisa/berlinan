import SwiftUI
import BerlinanEngine

/// The main window (spec §11): transport bar / voice lanes / convergence
/// footer. Documents and the performance panel arrive in later phases.
struct ContentView: View {
    let services: AppServices
    let ui: UIState

    private struct EditTarget: Identifiable { let id: String }
    @State private var editTarget: EditTarget?
    @State private var showSettings = false

    var body: some View {
        Group {
                VStack(spacing: 0) {
                    TransportBarView(ui: ui,
                                     midiStatus: services.midiStatus,
                                     midiUp: services.midi != nil,
                                     onSettings: { showSettings = true })
                    Rectangle().fill(AppColor.line).frame(height: 1)
                    HarmonyStripView(ui: ui, services: services)
                    Rectangle().fill(AppColor.lineSoft).frame(height: 1)

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(ui.voices, id: \.id) { voice in
                                VoiceLaneView(ui: ui, voice: voice,
                                              onEdit: { editTarget = EditTarget(id: voice.id) })
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
        .sheet(item: $editTarget) { target in
            PatternEditorSheet(ui: ui, voiceID: target.id)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(services: services, ui: ui)
        }
    }
}
