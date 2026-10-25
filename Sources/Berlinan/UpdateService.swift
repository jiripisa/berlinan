import Foundation
import Observation
import Sparkle

/// Auto-update (FR-UX-8, phase 56) on Sparkle: the feed and the EdDSA key
/// come from Info.plist (`SUFeedURL`, `SUPublicEDKey`). When enabled, every
/// launch asks the feed for a newer version; Sparkle's standard dialog
/// offers it and installs only after the user agrees.
@MainActor
@Observable
final class UpdateService {

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    private var updater: SPUUpdater { controller.updater }

    /// Mirrors Sparkle's own persisted setting (default on via
    /// `SUEnableAutomaticChecks`).
    private(set) var checksAtLaunch: Bool
    private(set) var canCheck = false
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    init() {
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: nil,
                                                  userDriverDelegate: nil)
        checksAtLaunch = controller.updater.automaticallyChecksForUpdates
        canCheck = controller.updater.canCheckForUpdates
        canCheckObservation = controller.updater.observe(\.canCheckForUpdates,
                                                         options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.canCheck = self.updater.canCheckForUpdates
            }
        }
        // "At launch", not Sparkle's daily schedule: ask now when enabled.
        if checksAtLaunch {
            updater.checkForUpdatesInBackground()
        }
    }

    func setChecksAtLaunch(_ on: Bool) {
        updater.automaticallyChecksForUpdates = on
        checksAtLaunch = on
    }

    /// "Check for Updates…": always shows a result, also "you're up to date".
    func checkNow() {
        controller.checkForUpdates(nil)
    }

    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}
