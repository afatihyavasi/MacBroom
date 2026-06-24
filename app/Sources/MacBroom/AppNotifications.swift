import Foundation
import UserNotifications
import MacBroomCore

/// Native, MacBroom-attributed notifications via UNUserNotificationCenter.
///
/// Replaces the engine's osascript banner (which macOS attributed to "Script
/// Editor") for app-driven auto-cleans. A shared singleton so the
/// UNUserNotificationCenter delegate (held weakly) stays alive.
final class AppNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotifications()
    private override init() { super.init() }

    /// Set the delegate and request authorization once, at launch.
    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Post a "freed X" banner after a successful auto-clean.
    func postCleaned(freed: Int64, tool: String) {
        guard freed > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "MacBroom"
        content.body = tool + " · " + String(format: Localization.string(.freed), Format.bytes(freed))
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Present banners even when the (menu-bar) app is frontmost.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
