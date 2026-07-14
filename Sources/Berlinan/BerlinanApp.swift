import SwiftUI
import AppKit

@main
struct BerlinanApp: App {

    @State private var services = AppServices()

    init() {
        // Studio-dark only in v1 (design_language.md §6) — the app does not
        // follow the system light mode.
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(services: services)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.automatic)

        // Studio reference card (FR-MOD-8) — appears in the Window menu.
        Window("Delay Cheat Sheet", id: "delayCheatSheet") {
            DelayCheatSheetView(services: services)
        }
        .windowResizability(.contentSize)
    }
}
