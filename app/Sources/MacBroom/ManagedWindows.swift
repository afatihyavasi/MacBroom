import AppKit

/// Tracks the app's standalone windows (Settings / Automation / Disk Analysis)
/// so the GLOBAL activation policy is only reverted to `.accessory` when the
/// LAST one closes. Otherwise closing one window would demote the app to a pure
/// menu-bar agent while another window is still open — orphaning it (lost Dock
/// presence, hard to re-focus).
@MainActor
enum ManagedWindows {
    private static var open = Set<ObjectIdentifier>()

    /// One of our windows became visible — ensure the app can front a real window.
    static func opened(_ window: NSWindow) {
        open.insert(ObjectIdentifier(window))
        NSApp.setActivationPolicy(.regular)
    }

    /// One of our windows is closing — revert to menu-bar-only iff it was the last.
    static func closed(_ window: NSWindow) {
        open.remove(ObjectIdentifier(window))
        if open.isEmpty { NSApp.setActivationPolicy(.accessory) }
    }
}
