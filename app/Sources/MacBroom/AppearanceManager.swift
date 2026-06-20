import AppKit
import SwiftUI
import MacBroomCore

/// Applies the user's light/dark/system choice app-wide by setting
/// `NSApp.appearance`. The design system's dynamic NSColors resolve against the
/// effective appearance, so both the menu-bar panel and the Settings window
/// follow the override. Published so the Settings picker reflects the choice.
@MainActor
final class AppearanceManager: ObservableObject {
    @Published var mode: AppearanceMode {
        didSet { AppearanceMode.current = mode; apply() }
    }

    init() {
        mode = AppearanceMode.current
        apply()
    }

    func apply() {
        switch mode {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
