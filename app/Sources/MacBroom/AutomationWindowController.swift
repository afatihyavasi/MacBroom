import AppKit
import SwiftUI

/// Hosts the AI automation panel in its own AppKit window (same rationale as
/// SettingsWindowController: a menu-bar/.accessory app needs a real window with
/// a .regular activation policy to reliably present + focus, and so its NSMenu
/// pickers can't dismiss the menu-bar panel).
@MainActor
final class AutomationWindowController: NSObject, NSWindowDelegate {
    static let shared = AutomationWindowController()
    private var window: NSWindow?

    func show(state: AppState, loc: LocalizationManager) {
        NSApp.setActivationPolicy(.regular)
        if window == nil {
            let hosting = NSHostingController(
                rootView: AutomationView().environmentObject(state).environmentObject(loc)
            )
            let w = NSWindow(contentViewController: hosting)
            w.title = "MacBroom"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() { window?.performClose(nil) }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
