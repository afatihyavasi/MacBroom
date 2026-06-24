import Sparkle
import SwiftUI

/// Wraps Sparkle's standard updater so MacBroom can auto-update and offer a
/// manual "Check for Updates". The appcast feed URL and the EdDSA public key
/// live in Info.plist (SUFeedURL / SUPublicEDKey); see docs/RELEASING.md for the
/// publish-an-update flow (generate keys, build the appcast, sign the DMG).
@MainActor
final class UpdaterController: ObservableObject {
    private let controller: SPUStandardUpdaterController

    /// Mirrors Sparkle's automatic-check preference for the Settings toggle.
    @Published var automaticallyChecks: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
    }

    /// User-initiated check (shows Sparkle's UI, incl. "you're up to date").
    func checkForUpdates() { controller.checkForUpdates(nil) }
}
