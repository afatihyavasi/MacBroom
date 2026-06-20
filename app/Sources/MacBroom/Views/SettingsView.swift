import SwiftUI
import AppKit
import MacBroomCore

/// Settings sheet: deletion policy, Full Disk Access, and attribution.
struct SettingsView: View {
    @AppStorage("deletionMode") private var deletionMode: String = DeleteMode.permanent.rawValue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Ayarlar").font(.title2.weight(.semibold))
                Spacer()
                Button("Bitti") { dismiss() }.keyboardShortcut(.defaultAction)
            }

            // Deletion policy
            VStack(alignment: .leading, spacing: 6) {
                Label("Silme yöntemi", systemImage: "trash").font(.headline)
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
                Label("Tam Disk Erişimi", systemImage: "lock.shield").font(.headline)
                Text("Bazı sistem önbelleklerini temizlemek için MacBroom'a Tam Disk Erişimi vermeniz gerekir.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Sistem Ayarları'nda Aç") { openFullDiskAccess() }
            }

            Divider()

            // About / attribution
            VStack(alignment: .leading, spacing: 4) {
                Label("Hakkında", systemImage: "info.circle").font(.headline)
                Text("MacBroom \(appVersion) · GPL-3.0")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Temizleme motoru tw93/mole (GPL-3.0) tarafından sağlanır.")
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
