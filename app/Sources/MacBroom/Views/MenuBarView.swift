import SwiftUI
import AppKit
import MacBroomCore

/// Root menu bar panel (v2 shadcn design): header + live status, then a
/// three-way section switch (AI caches · System caches · Apps uninstaller).
struct MenuBarView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var appearance: AppearanceManager

    /// A tab is either a cleaning category (derived from `CleanCategory`) or the
    /// Apps uninstaller. The cache tabs come straight from `CleanCategory.allCases`
    /// and Apps is appended, so a future category case yields a tab for free.
    enum Section: Hashable, Identifiable {
        case category(CleanCategory)
        case automation
        case apps

        var id: String {
            switch self {
            case .category(let c): return c.rawValue
            case .automation: return "automation"
            case .apps: return "apps"
            }
        }

        /// The ordered tab list: every cleaning category, then Automation, then Apps.
        static var allCases: [Section] {
            CleanCategory.allCases.map(Section.category) + [.automation, .apps]
        }

        var titleKey: L10n {
            switch self {
            case .category(.ai): return .tabAI
            case .category(.system): return .tabSystem
            case .automation: return .tabAutomation
            case .apps: return .tabApps
            }
        }
    }
    @State private var section: Section = .category(.ai)
    @AppStorage("didOnboard") private var didOnboard = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            header
            if !didOnboard { onboardingBanner }
            if let status = state.status { StatusPanelView(status: status) }

            SHTabs(selection: $section,
                   items: Section.allCases.map { ($0, loc.t($0.titleKey)) })

            content.frame(maxWidth: .infinity, maxHeight: .infinity)

            if category != nil {
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
            // Make the menu-bar panel the key window so its controls receive
            // clicks. An accessory app's panel can open non-key, which swallows
            // taps (tabs won't switch, buttons don't fire). Deferred to the next
            // runloop so the panel is fully presented first.
            DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
            await state.refreshStatus()
            if case .idle = state.phase { await state.discover() }
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
            SHIconButton(system: "chart.bar.doc.horizontal", help: loc.t(.diskAnalysisOpen)) {
                // Disk Analysis opens in its own AppKit window (the tab strip is
                // full at 4) — see DiskAnalysisWindowController.
                DiskAnalysisWindowController.shared.show(state: state, loc: loc)
            }
            SHIconButton(system: "gearshape", help: loc.t(.settingsHelp)) {
                // Settings opens in its own AppKit window (deterministic for a
                // menu-bar app; see SettingsWindowController) so its NSMenu
                // pickers can't dismiss this panel.
                SettingsWindowController.shared.show(state: state, loc: loc, appearance: appearance, updater: UpdaterController.shared)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }

    /// Invisible buttons that wire ⌘1…⌘N to the tabs, in their displayed order
    /// (so a 4th tab automatically gets ⌘4). Only the first 9 are addressable.
    private var tabShortcuts: some View {
        Group {
            ForEach(Array(Section.allCases.prefix(9).enumerated()), id: \.element.id) { index, tab in
                Button("") { section = tab }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
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
        case .category:   cleanContent
        case .automation: AutomationView()
        case .apps:       UninstallView()
        }
    }

    /// The cleaning category for the current tab, or nil for Automation/Apps.
    private var category: CleanCategory? {
        if case .category(let c) = section { return c }
        return nil
    }

    @ViewBuilder private var cleanContent: some View {
        // Only rendered for a cleaning tab, so `category` is always non-nil here.
        if let category {
            // A transient state is shown on a tab only if it owns it
            // (`phaseCategory` == this tab, or nil for a global discovery state).
            // Otherwise the tab falls through to its own resting view.
            let owns = state.phaseCategory == nil || state.phaseCategory == category
            switch state.phase {
            case .idle, .discovering:
                loading(loc.t(.searchingTargets))
            case .scanning where owns:
                loading(loc.t(.scanningTargets))
            case let .cleaning(done, total, freed) where owns:
                cleaningView(done: done, total: total, freed: freed)
            case let .finished(freed, count, failed, permissionBlocked) where owns:
                cacheResult(freed: freed, count: count, failed: failed, permissionBlocked: permissionBlocked)
            case let .error(msg) where owns:
                resultView(icon: "exclamationmark.triangle.fill", tint: Theme.destructive,
                           title: msg, action: loc.t(.back)) { state.dismissCacheResult() }
            default:
                if state.isScanned(category) {
                    if category == .ai { AICacheView() } else { CategoryCacheView(category: category) }
                } else {
                    AnalysisSelectionView(category: category)
                }
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
    private func cacheResult(freed: Int64, count: Int, failed: Int, permissionBlocked: Bool) -> some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: failed == 0 ? "sparkles" : "exclamationmark.triangle.fill")
                .font(.system(size: 30)).foregroundStyle(failed == 0 ? Theme.success : Theme.warning)
            // Always show how many items were removed + how much space freed.
            Text(loc.t(.freedItems, count, Format.bytes(freed)))
                .font(.shHeadline).multilineTextAlignment(.center)
            if failed > 0 {
                Text(loc.t(.couldntRemove, failed))
                    .font(.shCaption).foregroundStyle(Theme.warning)
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
        guard let category, state.isScanned(category) else { return false }
        let owns = state.phaseCategory == nil || state.phaseCategory == category
        switch state.phase {
        case .idle, .discovering: return false
        case .selecting: return true
        case .scanning, .cleaning, .finished, .error: return !owns
        }
    }

    @ViewBuilder private var cleanControls: some View {
        if let category {
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
}
