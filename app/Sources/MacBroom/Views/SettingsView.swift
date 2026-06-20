import SwiftUI
import AppKit
import MacBroomCore

/// Settings sheet: deletion policy, Full Disk Access, and attribution.
struct SettingsView: View {
    @EnvironmentObject var loc: LocalizationManager
    @AppStorage("deletionMode") private var deletionMode: String = DeleteMode.permanent.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(loc.t(.settingsTitle)).font(.title2.weight(.semibold))
                Spacer()
                Button(loc.t(.done)) { dismiss() }.keyboardShortcut(.defaultAction)
            }

            // Language
            VStack(alignment: .leading, spacing: 6) {
                Label(loc.t(.language), systemImage: "globe").font(.headline)
                Picker("", selection: $loc.language) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Divider()

            // Deletion policy
            VStack(alignment: .leading, spacing: 6) {
                Label(loc.t(.deletionMethod), systemImage: "trash").font(.headline)
                Picker("", selection: $deletionMode) {
                    ForEach(DeleteMode.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                Text(DeleteMode(rawValue: deletionMode)?.detail ?? "")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            // Full Disk Access
            VStack(alignment: .leading, spacing: 6) {
                Label(loc.t(.fdaTitle), systemImage: "lock.shield").font(.headline)
                Text(loc.t(.fdaSettingsDesc))
                    .font(.caption).foregroundStyle(.secondary)
                Button(loc.t(.openInSettings)) { openFullDiskAccess() }
            }

            Divider()

            // About / attribution
            VStack(alignment: .leading, spacing: 4) {
                Label(loc.t(.about), systemImage: "info.circle").font(.headline)
                Text(loc.t(.aboutVersion, appVersion))
                    .font(.caption).foregroundStyle(.secondary)
                Text(loc.t(.engineAttribution))
                    .font(.caption).foregroundStyle(.secondary)
                Link("github.com/tw93/mole", destination: URL(string: "https://github.com/tw93/mole")!)
                    .font(.caption)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private func openFullDiskAccess() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
