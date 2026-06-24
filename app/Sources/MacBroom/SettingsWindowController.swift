import AppKit
import SwiftUI

/// Hosts the Settings UI in a real AppKit window.
///
/// Why not a SwiftUI `Window` + `openWindow`? In a MenuBarExtra-primary
/// LSUIElement app, `openWindow(id:)` proved unreliable (it didn't present the
/// Settings window at all). A directly-managed `NSWindow` is deterministic: we
/// flip the activation policy to `.regular` so an accessory app can actually
/// front a normal window, show it, and revert to `.accessory` on close so the
/// app stays a pure menu-bar app (no lingering Dock icon).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(state: AppState, loc: LocalizationManager, appearance: AppearanceManager, updater: UpdaterController) {
        mbDebug("SettingsWindowController.show called")
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsView()
                    .environmentObject(state).environmentObject(loc)
                    .environmentObject(appearance).environmentObject(updater)
            )
            let w = NSWindow(contentViewController: hosting)
            w.title = "MacBroom"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
        if let w = window { ManagedWindows.opened(w) }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Close from the in-view "Done" button.
    func close() { window?.performClose(nil) }

    func windowWillClose(_ notification: Notification) {
        if let w = notification.object as? NSWindow { ManagedWindows.closed(w) }
    }
}
