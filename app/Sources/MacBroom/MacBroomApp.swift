import SwiftUI

@main
struct MacBroomApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(state)
                .frame(width: 360)
        } label: {
            // Menu bar icon. A filled broom-ish glyph; swapped for a custom
            // template asset during the polish stage.
            Image(systemName: "wand.and.stars.inverse")
        }
        .menuBarExtraStyle(.window)
    }
}
