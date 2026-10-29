import Foundation
import UserNotifications
import MacBroomCore

/// Native, localized banners for background auto-cleans.
///
/// Replaces the engine's old `osascript` banner, which macOS attributed to
/// Script Editor (wrong icon, English-only, fired even for a few KB). Posting
/// from the app itself gets MacBroom's icon and the user's chosen language.
@MainActor
enum Notifier {
    /// Below this, an auto-clean is recorded in history but not announced — a
    /// banner for "80 KB freed" is noise, not news.
    static let minimumBytes: Int64 = 100 * 1024 * 1024

    /// `UNUserNotificationCenter.current()` traps when the process has no real
    /// app bundle (e.g. `swift run`, the bare executable). Only touch it from an
    /// assembled `.app` with a bundle identifier.
    private static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    private static let delegate = ForegroundPresenter()
    private static var authorized: Bool?

    /// Ask once for alert permission. Safe to call repeatedly.
    static func setUp() {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = delegate
        center.requestAuthorization(options: [.alert]) { granted, error in
            if let error { NSLog("MacBroom: notification authorization failed: %@", error.localizedDescription) }
            Task { @MainActor in authorized = granted }
        }
    }

    /// Announce an auto-clean. `targetLabel` is the localized target name when
    /// known (in-app run); nil for launchd runs folded from the ledger, which
    /// only carry a byte total.
    static func autoCleaned(freed: Int64, targetLabel: String?) {
        guard isAvailable, freed >= minimumBytes else { return }
        let size = Format.bytes(freed)
        let title = Localization.string(.notifyAutoCleanTitle)
        let body = targetLabel.map { String(format: Localization.string(.notifyFreedFromTarget), size, $0) }
            ?? String(format: Localization.string(.notifyFreedInBackground), size)

        // macOS refuses UNUserNotificationCenter authorization to ad-hoc signed
        // apps ("Notifications are not allowed for this application") — which
        // is every build made without a Developer ID. Those fall back to
        // AppleScript run *inside this process*, so the banner is still
        // attributed to MacBroom (unlike the `osascript` CLI → Script Editor).
        guard authorized != false else {
            postViaAppleScript(title: title, body: body)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func postViaAppleScript(title: String, body: String) {
        func quoted(_ s: String) -> String {
            "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        var error: NSDictionary?
        NSAppleScript(source: "display notification \(quoted(body)) with title \(quoted(title))")?
            .executeAndReturnError(&error)
        if let error { NSLog("MacBroom: AppleScript notification failed: %@", error) }
    }
}

/// MacBroom is a menu bar app, so it is often "active" while its popover is
/// open; without this delegate macOS would swallow the banner in that state.
private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }
}
