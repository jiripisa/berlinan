import SwiftUI
import AppKit

@main
struct BerlinanApp: App {

    @State private var services: AppServices
    @State private var ui: UIState

    init() {
        // Studio-dark only in v1 (design_language.md §6) — the app does not
        // follow the system light mode.
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        let services = AppServices()
        _services = State(initialValue: services)
        _ui = State(initialValue: UIState(services: services))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(services: services, ui: ui)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.automatic)
        .commands {
            // Undo over generative actions (FR-UX-5): restores the state
            // snapshot taken before the last regenerate / re-roll / recall.
            CommandGroup(replacing: .undoRedo) {
                Button("Undo Berlinan Action") { ui.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!ui.canUndo)
            }
            // Documents (spec §10, M3 subset).
            CommandGroup(replacing: .newItem) {
                Button("Open Project…") {
                    if let project = services.openDocument() {
                        ui.loadSlots(project.snapshots)
                    }
                }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(ui.isPlaying)

                Button("Save Project As…") {
                    services.saveDocument(snapshots: ui.snapshotSlots)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }

        // Studio reference card (FR-MOD-8) — appears in the Window menu.
        Window("Delay Cheat Sheet", id: "delayCheatSheet") {
            DelayCheatSheetView(services: services)
        }
        .windowResizability(.contentSize)
    }
}
