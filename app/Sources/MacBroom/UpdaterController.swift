import AppKit
import Sparkle
import SwiftUI

/// Wraps Sparkle's standard updater so MacBroom can auto-update and offer a
/// manual "Check for Updates". The appcast feed URL and the EdDSA public key
/// live in Info.plist (SUFeedURL / SUPublicEDKey); see docs/RELEASING.md for the
/// publish-an-update flow (generate keys, build the appcast, sign the DMG).
///
/// It's a shared singleton (not injected into the menu-bar panel's environment)
/// so the panel never observes/re-renders on Sparkle activity, and the updater
/// starts *after* launch — starting it eagerly during scene setup let its first
/// check interfere with the MenuBarExtra panel becoming key (clicks then stopped
/// registering / the panel dismissed instead of switching tabs).
@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    private let controller: SPUStandardUpdaterController

    /// Mirrors Sparkle's automatic-check preference for the Settings toggle.
    @Published var automaticallyChecks: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }

    private init() {
        // startingUpdater: false → we start it ourselves, deferred, below.
        controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        // Defer the start so it runs well after the app/menu-bar panel is up.
        let c = controller
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { c.startUpdater() }
    }

    /// User-initiated check (shows Sparkle's UI, incl. "you're up to date").
    func checkForUpdates() { controller.checkForUpdates(nil) }
}
