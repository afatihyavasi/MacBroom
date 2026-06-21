import AppKit
import SwiftUI

/// Hosts the Disk Analysis (large-file finder) UI in its own AppKit window.
///
/// Same rationale as SettingsWindowController / AutomationWindowController: a
/// menu-bar (.accessory) app needs a real window with a `.regular` activation
/// policy to reliably present + focus, and reverts to `.accessory` on close so
/// the app stays a pure menu-bar app (no lingering Dock icon).
///
/// Disk Analysis is a separate window — NOT a tab — because the menu-bar panel's
/// tab strip is already full (AI · System · Developer · Apps).
@MainActor
final class DiskAnalysisWindowController: NSObject, NSWindowDelegate {
    static let shared = DiskAnalysisWindowController()
    private var window: NSWindow?

    func show(state: AppState, loc: LocalizationManager) {
        NSApp.setActivationPolicy(.regular)
        if window == nil {
            let hosting = NSHostingController(
                rootView: DiskAnalysisView().environmentObject(state).environmentObject(loc)
            )
            let w = NSWindow(contentViewController: hosting)
            w.title = "MacBroom"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 520, height: 600))
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
