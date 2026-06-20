import SwiftUI

@main
struct MacBroomApp: App {
    @StateObject private var state = AppState()
    @StateObject private var loc = LocalizationManager()
    @StateObject private var appearance = AppearanceManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(state)
                .environmentObject(loc)
                .environmentObject(appearance)
                // Fixed panel size: content scrolls internally so switching
                // tabs/phases never resizes (and thus never "jumps") the window.
                .frame(width: 380, height: 560)
        } label: {
            // Menu bar icon. A filled broom-ish glyph; swapped for a custom
            // template asset during the polish stage.
            Image(systemName: "wand.and.stars.inverse")
        }
        .menuBarExtraStyle(.window)
    }
}
