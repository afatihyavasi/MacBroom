import SwiftUI
import MacBroomCore

/// Root menu bar panel (v2 shadcn design): header + live status, then a
/// three-way section switch (AI caches · System caches · Apps uninstaller).
struct MenuBarView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager

    enum Section: String, CaseIterable, Identifiable {
        case ai, system, apps
        var id: String { rawValue }
        var titleKey: L10n {
            switch self {
            case .ai: return .tabAI
            case .system: return .tabSystem
            case .apps: return .tabApps
            }
        }
    }
    @State private var section: Section = .ai
    @State private var showingSettings = false
    @AppStorage("didOnboard") private var didOnboard = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            header
            if !didOnboard { onboardingBanner }
            if let status = state.status { StatusPanelView(status: status) }

            SHTabs(selection: $section,
                   items: Section.allCases.map { ($0, loc.t($0.titleKey)) })

            content.frame(maxWidth: .infinity, maxHeight: .infinity)

            if section != .apps {
                SHSeparator()
                cleanControls
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(Theme.Space.lg)
        .background(Theme.background)
        .foregroundStyle(Theme.foreground)
        .background(tabShortcuts)
        .task {
            await state.refreshStatus()
            if case .idle = state.phase { await state.discover() }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView().environmentObject(loc)
        }
    }

    // MARK: header

    private var header: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: "wand.and.stars.inverse")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text("MacBroom").font(.shTitle)
            Spacer()
            SHIconButton(system: "arrow.clockwise", help: loc.t(.refreshHelp)) {
                Task { await state.discover() }
            }
            .disabled(state.isBusy)
            .keyboardShortcut("r", modifiers: .command)
            SHIconButton(system: "gearshape", help: loc.t(.settingsHelp)) {
                showingSettings = true
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }

    /// Invisible buttons that wire ⌘1/⌘2/⌘3 to the tabs.
    private var tabShortcuts: some View {
        Group {
            Button("") { section = .ai }.keyboardShortcut("1", modifiers: .command)
            Button("") { section = .system }.keyboardShortcut("2", modifiers: .command)
            Button("") { section = .apps }.keyboardShortcut("3", modifiers: .command)
        }
        .opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
    }

    // MARK: onboarding

    private var onboardingBanner: some View {
        HStack(spacing: Theme.Space.sm) {
            Image(systemName: "lock.shield").foregroundStyle(Theme.warning)
            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(loc.t(.fdaTitle)).font(.shLabel)
                Text(loc.t(.fdaBannerDesc)).font(.shCaption).foregroundStyle(Theme.mutedForeground)
            }
            Spacer()
            Button(loc.t(.open)) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }
            .buttonStyle(.shOutline(.sm))
            SHIconButton(system: "xmark") { didOnboard = true }
        }
        .padding(Theme.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.warning.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.warning.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: content

    @ViewBuilder private var content: some View {
        switch section {
        case .apps: UninstallView()
        case .ai, .system: cleanContent
        }
    }

    /// The cleaning category for the current tab (Apps handled separately).
    private var category: CleanCategory { section == .system ? .system : .ai }

    @ViewBuilder private var cleanContent: some View {
        // A transient state is shown on a tab only if it owns it (`phaseCategory`
        // == this tab, or nil for a global discovery state). Otherwise the tab
        // falls through to its own resting view.
        let owns = state.phaseCategory == nil || state.phaseCategory == category
        switch state.phase {
        case .idle, .discovering:
            loading(loc.t(.searchingTargets))
        case .scanning where owns:
            loading(loc.t(.scanningTargets))
        case let .cleaning(done, total, freed) where owns:
            cleaningView(done: done, total: total, freed: freed)
        case let .finished(freed, failed, permissionBlocked) where owns:
            cacheResult(freed: freed, failed: failed, permissionBlocked: permissionBlocked)
        case let .error(msg) where owns:
            resultView(icon: "exclamationmark.triangle.fill", tint: Theme.destructive,
                       title: msg, action: loc.t(.back)) { state.dismissCacheResult() }
        default:
            if state.isScanned(category) {
                if category == .ai { AICacheView() } else { SystemCacheView() }
            } else {
                AnalysisSelectionView(category: category)
            }
        }
    }

    private func cleaningView(done: Int, total: Int, freed: Int64) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            SHProgressBar(value: Double(done) / Double(max(total, 1)))
            Text(freed > 0
                 ? loc.t(.cleaningProgressBytes, done, total, Format.bytes(freed))
                 : loc.t(.cleaningProgress, done, total))
                .font(.shCaption).foregroundStyle(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, Theme.Space.sm)
    }

    private func resultView(icon: String, tint: Color, title: String,
                            action: String, perform: @escaping () -> Void) -> some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: icon).font(.system(size: 30)).foregroundStyle(tint)
            Text(title).font(.shHeadline).multilineTextAlignment(.center)
            Button(action, action: perform).buttonStyle(.shOutline(.sm))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Cache-clean outcome. Celebrates a full success; on partial failure tells
    /// the user how many items remained and offers Full Disk Access when the
    /// cause looks like a permission wall.
    @ViewBuilder
    private func cacheResult(freed: Int64, failed: Int, permissionBlocked: Bool) -> some View {
        VStack(spacing: Theme.Space.md) {
            if failed == 0 {
                Image(systemName: "sparkles").font(.system(size: 30)).foregroundStyle(Theme.success)
                Text(loc.t(.freed, Format.bytes(freed))).font(.shHeadline)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30)).foregroundStyle(Theme.warning)
                Text(loc.t(.removedPartial, Format.bytes(freed), failed))
                    .font(.shHeadline).multilineTextAlignment(.center)
                if permissionBlocked {
                    Text(loc.t(.someProtected))
                        .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                        .multilineTextAlignment(.center).padding(.horizontal, Theme.Space.sm)
                    Button(loc.t(.openFDA)) {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                    }.buttonStyle(.shPrimary(.sm))
                } else {
                    Text(loc.t(.itemsInUse))
                        .font(.shCaption).foregroundStyle(Theme.mutedForeground)
                        .multilineTextAlignment(.center).padding(.horizontal, Theme.Space.sm)
                }
            }
            Button(loc.t(.done)) { state.dismissCacheResult() }.buttonStyle(.shOutline(.sm))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loading(_ text: String) -> some View {
        VStack(spacing: Theme.Space.md) {
            ProgressView().controlSize(.small)
            Text(text).font(.shBody).foregroundStyle(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: clean controls

    /// True exactly when this tab is showing its results list.
    private var showResults: Bool {
        guard state.isScanned(category) else { return false }
        let owns = state.phaseCategory == nil || state.phaseCategory == category
        switch state.phase {
        case .idle, .discovering: return false
        case .selecting: return true
        case .scanning, .cleaning, .finished, .error: return !owns
        }
    }

    private var cleanControls: some View {
        HStack(spacing: Theme.Space.sm) {
            if showResults {
                Button { state.backToSelection(category: category) } label: {
                    HStack(spacing: 3) { Image(systemName: "chevron.left"); Text(loc.t(.backTargets)) }
                }
                .buttonStyle(.shGhost(.sm))
                Text(loc.t(.selectedSuffix, Format.bytes(state.selectedBytes(in: category))))
                    .font(.shCaption).foregroundStyle(Theme.mutedForeground)
            }
            Spacer()
            if showResults {
                Button(loc.t(.clean)) { Task { await state.clean(category: category) } }
                    .buttonStyle(.shPrimary(.sm))
                    .disabled(!state.hasSelection(in: category))
            }
            Button(loc.t(.quit)) { NSApplication.shared.terminate(nil) }
                .buttonStyle(.shGhost(.sm))
                .keyboardShortcut("q", modifiers: .command)
        }
    }
}
