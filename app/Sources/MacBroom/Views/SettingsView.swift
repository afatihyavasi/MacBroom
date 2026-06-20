import SwiftUI
import AppKit
import MacBroomCore

/// Settings window (v2): language, deletion policy, Full Disk Access, attribution.
struct SettingsView: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var state: AppState
    @AppStorage("deletionMode") private var deletionMode: String = DeleteMode.permanent.rawValue

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

            // Automatic AI cleaning
            autoCleanSection

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

            // Full Disk Access
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                SHSectionHeader(title: loc.t(.fdaTitle), systemImage: "lock.shield")
                Text(loc.t(.fdaSettingsDesc))
                    .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                Button(loc.t(.openInSettings)) { openFullDiskAccess() }.buttonStyle(.shOutline(.sm))
            }

            SHSeparator()

            // About / attribution
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                SHSectionHeader(title: loc.t(.about), systemImage: "info.circle")
                Text(loc.t(.aboutVersion, appVersion))
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

    // MARK: automatic AI cleaning

    @ViewBuilder private var autoCleanSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SHSectionHeader(title: loc.t(.autoCleanTitle), systemImage: "clock.arrow.circlepath")
            Text(loc.t(.autoCleanDesc)).font(.shCaption).foregroundStyle(Theme.mutedForeground)
            let tools = state.installedTargets(in: .ai)
            if tools.isEmpty {
                Text(loc.t(.autoCleanNoTools)).font(.shCaption).foregroundStyle(Theme.mutedForeground)
            } else {
                VStack(spacing: Theme.Space.xs) {
                    ForEach(tools) { autoCleanRow($0) }
                }
            }
        }
    }

    private func autoCleanRow(_ t: AnalysisTarget) -> some View {
        let freq = state.frequency(for: t.id)
        return HStack(spacing: Theme.Space.sm) {
            AIToolIconView(tool: AITool(rawValue: String(t.id.dropFirst(3))) ?? .other, size: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(t.label).font(.shLabel)
                if freq != .off, let last = state.lastRun(for: t.id) {
                    Text(loc.t(.autoCleanLast, Self.relative.localizedString(for: last, relativeTo: Date())))
                        .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                }
            }
            Spacer()
            Picker("", selection: Binding(
                get: { state.frequency(for: t.id) },
                set: { state.setSchedule($0, for: t.id) }
            )) {
                ForEach(CleanFrequency.allCases) { Text(loc.t($0.titleKey)).tag($0) }
            }
            .pickerStyle(.menu).labelsHidden().fixedSize()
        }
        .padding(Theme.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(freq == .off ? Theme.border : Theme.accent.opacity(0.5), lineWidth: 1)
        )
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated; return f
    }()

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
