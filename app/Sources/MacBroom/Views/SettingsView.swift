import SwiftUI
import AppKit
import MacBroomCore

/// Settings window (v2): language, deletion policy, Full Disk Access, attribution.
struct SettingsView: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var state: AppState
    @EnvironmentObject var appearance: AppearanceManager
    @AppStorage("deletionMode") private var deletionMode: String = DeleteMode.permanent.rawValue
    @State private var fdaGranted = FullDiskAccess.isGranted

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            HStack {
                Text(loc.t(.settingsTitle)).font(.shTitle)
                Spacer()
                Button(loc.t(.done)) { SettingsWindowController.shared.close() }
                    .buttonStyle(.shPrimary(.sm))
                    .keyboardShortcut(.defaultAction)
            }

            // Appearance (light / dark / system)
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                SHSectionHeader(title: loc.t(.appearance), systemImage: "circle.lefthalf.filled")
                Picker("", selection: $appearance.mode) {
                    ForEach(AppearanceMode.allCases) { Text(loc.t($0.titleKey)).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
            }

            // Language
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                SHSectionHeader(title: loc.t(.language), systemImage: "globe")
                Picker("", selection: $loc.language) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu).labelsHidden()
            }

            // Deletion policy
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                SHSectionHeader(title: loc.t(.deletionMethod), systemImage: "trash")
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    ForEach(DeleteMode.allCases) { mode in
                        deletionRow(mode)
                    }
                }
            }

            // Exclusions (tools the user permanently excludes from cleaning)
            exclusionsSection

            // Protected paths (user-defined whitelist — never scanned or deleted)
            protectedPathsSection

            // Full Disk Access — reflect the live permission state.
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                SHSectionHeader(title: loc.t(.fdaTitle), systemImage: "lock.shield")
                if fdaGranted {
                    Label(loc.t(.fdaGranted), systemImage: "checkmark.seal.fill")
                        .font(.shCaption).foregroundStyle(Theme.success)
                } else {
                    Text(loc.t(.fdaSettingsDesc))
                        .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                    Button(loc.t(.openInSettings)) { openFullDiskAccess() }.buttonStyle(.shOutline(.sm))
                }
            }
            .onAppear { fdaGranted = FullDiskAccess.isGranted }

            SHSeparator()

            // Cleaning history
            historySection

            SHSeparator()

            // About / attribution
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                SHSectionHeader(title: loc.t(.about), systemImage: "info.circle")
                Text(loc.t(.aboutVersion, appVersion))
                    .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                Text(loc.t(.totalReclaimed, Format.bytes(state.totalReclaimed)))
                    .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                Text(loc.t(.engineAttribution))
                    .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                Link("github.com/tw93/mole", destination: URL(string: "https://github.com/tw93/mole")!)
                    .font(.shCaption).tint(Theme.accent)
            }
        }
        .padding(Theme.Space.xl)
        }
        .frame(width: 400, height: 560)
        .background(Theme.background)
        .foregroundStyle(Theme.foreground)
    }

    // MARK: exclusions

    @ViewBuilder private var exclusionsSection: some View {
        let tools = state.allInstalledTargets
        if !tools.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                SHSectionHeader(title: loc.t(.exclusionsTitle), systemImage: "nosign")
                Text(loc.t(.exclusionsDesc)).font(.shCaption).foregroundStyle(Theme.mutedForeground)
                VStack(spacing: Theme.Space.xs) {
                    ForEach(tools) { t in
                        Toggle(isOn: Binding(
                            get: { state.isExcluded(t.id) },
                            set: { _ in state.toggleExcluded(t.id) }
                        )) {
                            Text(t.displayLabel(loc)).font(.shCaption)
                        }
                        .toggleStyle(SHCheckboxStyle())
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }

    // MARK: protected paths (whitelist)

    @ViewBuilder private var protectedPathsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SHSectionHeader(title: loc.t(.protectedPathsTitle), systemImage: "hand.raised")
            Text(loc.t(.protectedPathsDesc)).font(.shCaption).foregroundStyle(Theme.mutedForeground)
            if state.protectedPaths.isEmpty {
                Text(loc.t(.protectedPathsEmpty)).font(.shCaption).foregroundStyle(Theme.mutedForeground)
            } else {
                VStack(spacing: Theme.Space.xs) {
                    ForEach(state.protectedPaths, id: \.self) { path in
                        protectedRow(path)
                    }
                }
            }
            Button(loc.t(.protectedPathsAdd)) { addProtectedPath() }
                .buttonStyle(.shOutline(.sm))
        }
    }

    private func protectedRow(_ path: String) -> some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: "lock.fill").font(.system(size: 11))
                .foregroundStyle(Theme.accent).frame(width: 14)
            Text(abbreviate(path)).font(.shCaption).lineLimit(1).truncationMode(.middle)
                .help(path)
            Spacer()
            Button { state.removeProtectedPath(path) } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 13))
                    .foregroundStyle(Theme.mutedForeground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loc.t(.remove))
        }
        .padding(.vertical, 5).padding(.horizontal, Theme.Space.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .strokeBorder(Theme.border, lineWidth: 1))
    }

    /// Show `~` for the home folder so long absolute paths stay readable.
    private func abbreviate(_ path: String) -> String { (path as NSString).abbreviatingWithTildeInPath }

    /// Native picker — choosing a real file/folder avoids typos that would make
    /// a whitelist rule silently match nothing.
    private func addProtectedPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = loc.t(.protectedPathsAdd)
        if panel.runModal() == .OK {
            for url in panel.urls { state.addProtectedPath(url.path) }
        }
    }

    // MARK: cleaning history

    @ViewBuilder private var historySection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SHSectionHeader(title: loc.t(.historyTitle), systemImage: "clock")
            if state.history.isEmpty {
                Text(loc.t(.historyEmpty)).font(.shCaption).foregroundStyle(Theme.mutedForeground)
            } else {
                VStack(spacing: Theme.Space.xs) {
                    ForEach(Array(state.history.prefix(12).enumerated()), id: \.offset) { _, rec in
                        historyRow(rec)
                    }
                }
            }
        }
    }

    private func historyRow(_ rec: CleanRecord) -> some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: rec.iconName).font(.system(size: 12))
                .foregroundStyle(Theme.accent).frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(loc.t(rec.kindKey)).font(.shLabel)
                Text(loc.t(.freedItems, rec.count, Format.bytes(rec.freedBytes)))
                    .font(.shCaption).foregroundStyle(Theme.mutedForeground)
            }
            Spacer()
            Text(loc.relativeTime(for: rec.date))
                .font(.shCaption).foregroundStyle(Theme.mutedForeground)
        }
        .padding(.vertical, 5).padding(.horizontal, Theme.Space.sm)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .strokeBorder(Theme.border, lineWidth: 1))
    }


    /// A selectable deletion-mode card (radio behavior).
    private func deletionRow(_ mode: DeleteMode) -> some View {
        let selected = deletionMode == mode.rawValue
        return Button { deletionMode = mode.rawValue } label: {
            HStack(alignment: .top, spacing: Theme.Space.sm) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Theme.accent : Theme.mutedForeground)
                    .font(.system(size: 13))
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title).font(.shLabel)
                    Text(mode.detail).font(.shCaption).foregroundStyle(Theme.mutedForeground)
                }
                Spacer()
            }
            .padding(Theme.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(selected ? Theme.muted : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(selected ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private func openFullDiskAccess() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
