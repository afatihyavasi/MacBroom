import SwiftUI
import MacBroomCore

/// The one permission ask, shown in place of the target list the first time the
/// user hits Analyze without Full Disk Access.
///
/// Either path ends the per-folder prompts: with FDA macOS stops asking, and
/// without it the engine runs fenced off from protected folders
/// (`PrivacySandbox`). While the user is in System Settings we poll the grant
/// and continue on our own, so there is no "come back and press Analyze again".
struct FullDiskAccessGateView: View {
    @EnvironmentObject var loc: LocalizationManager
    /// Called once the user has decided; `granted` tells which way.
    let onDone: (_ granted: Bool) -> Void

    @State private var waiting = false

    var body: some View {
        VStack(spacing: Theme.Space.md) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 30)).foregroundStyle(Theme.accent)
            Text(loc.t(.fdaGateTitle)).font(.shHeadline).multilineTextAlignment(.center)
            Text(loc.t(.fdaGateBody))
                .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                .multilineTextAlignment(.center).padding(.horizontal, Theme.Space.sm)
                .fixedSize(horizontal: false, vertical: true)

            if waiting {
                HStack(spacing: Theme.Space.xs) {
                    ProgressView().controlSize(.small)
                    Text(loc.t(.fdaGateWaiting)).font(.shCaption).foregroundStyle(Theme.mutedForeground)
                }
            }

            Button(loc.t(.openFDA)) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                waiting = true
            }
            .buttonStyle(.shPrimary(.sm))

            Button(loc.t(.fdaGateLimited)) { onDone(false) }
                .buttonStyle(.shGhost(.sm))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: waiting) {
            // FDA applies to the running process as soon as it is toggled on,
            // so a 1 s poll is enough to pick it up without a relaunch.
            guard waiting else { return }
            while !Task.isCancelled {
                if FullDiskAccess.isGranted { onDone(true); return }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}
