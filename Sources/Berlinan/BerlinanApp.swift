import SwiftUI
import AppKit

@main
struct BerlinanApp: App {

    init() {
        // Studio-dark only in v1 (design_language.md §6) — the app does not
        // follow the system light mode.
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowStyle(.automatic)
    }
}
