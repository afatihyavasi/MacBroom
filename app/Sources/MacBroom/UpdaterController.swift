import SwiftUI
// NOTE: Sparkle is intentionally NOT imported / instantiated right now. We're
// isolating whether Sparkle's updater is what breaks the menu-bar panel's
// click handling (the panel stopped registering clicks once auto-update landed).
// The type + API are kept so the rest of the app compiles unchanged; if disabling
// the updater restores clicks, Sparkle is confirmed as the cause and we'll either
// drop it or wire it up in a way that doesn't fight the panel for key focus.

@MainActor
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    /// Kept for the Settings toggle; inert while the updater is disabled.
    @Published var automaticallyChecks: Bool = false

    private init() {}

    /// No-op while Sparkle is disabled for diagnosis.
    func checkForUpdates() {}
}
