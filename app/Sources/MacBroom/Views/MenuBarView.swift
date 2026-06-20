import SwiftUI
import MacBroomCore

/// Root menu bar panel: header + live status, then a three-way section switch
/// (AI caches · System caches · Apps uninstaller).
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
        VStack(alignment: .leading, spacing: 12) {
            header
            if !didOnboard {
                onboardingBanner
            }
            if let status = state.status {
                StatusPanelView(status: status)
            }
            Divider()

            Picker("", selection: $section) {
                ForEach(Section.allCases) { Text(loc.t($0.titleKey)).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            content
                .frame(maxHeight: .infinity)

            if section != .apps {
                Divider()
                cleanControls
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(14)
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
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars.inverse")
                .font(.title3).foregroundStyle(.tint)
            Text("MacBroom").font(.headline)
            Spacer()
            Button { Task { await state.discover() } } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help(loc.t(.refreshHelp))
            .disabled(state.phase == .scanning || state.phase == .discovering)
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help(loc.t(.settingsHelp))
        }
    }

    // MARK: onboarding

    private var onboardingBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.t(.fdaTitle)).font(.caption.weight(.semibold))
                Text(loc.t(.fdaBannerDesc))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button(loc.t(.open)) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }
            .controlSize(.small)
            Button { didOnboard = true } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless).controlSize(.small)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
    }

    // MARK: content

    @ViewBuilder private var content: some View {
        switch section {
        case .apps:
            UninstallView()
        case .ai, .system:
            cleanContent
        }
    }

    /// The cleaning category for the current tab (Apps handled separately).
    private var category: CleanCategory { section == .system ? .system : .ai }

    @ViewBuilder private var cleanContent: some View {
        // A transient state is shown on a tab only if it owns it (`phaseCategory`
        // == this tab, or nil for a global discovery state). Otherwise the tab
        // falls through to its own resting view — so scanning/cleaning/finishing
        // one tab never hijacks the other.
        let owns = state.phaseCategory == nil || state.phaseCategory == category
        switch state.phase {
        case .idle, .discovering:
            loading(loc.t(.searchingTargets))
        case .scanning where owns:
            loading(loc.t(.scanningTargets))
        case let .cleaning(done, total) where owns:
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                Text(loc.t(.cleaningProgress, done, total)).font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 8)
        case let .finished(freed) where owns:
            VStack(spacing: 10) {
                Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.green)
                Text(loc.t(.freed, Format.bytes(freed))).font(.title3.weight(.semibold))
                Button(loc.t(.done)) { state.dismissCacheResult() }.buttonStyle(.link)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .error(msg) where owns:
            VStack(spacing: 10) {
                Label(msg, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red)
                Button(loc.t(.back)) { state.dismissCacheResult() }.buttonStyle(.link)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 8)
        default:
            // Resting (or a transient state owned by the OTHER tab): show this
            // category's results if already analyzed, else its target picker.
            if state.isScanned(category) {
                if category == .ai { AICacheView() } else { SystemCacheView() }
            } else {
                AnalysisSelectionView(category: category)
            }
        }
    }

    private func loading(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: clean controls

    /// True exactly when this tab is showing its results list (so the Clean
    /// controls belong on screen). Mirrors the `default` branch of `cleanContent`.
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
        HStack {
            if showResults {
                Button { state.backToSelection(category: category) } label: {
                    Image(systemName: "chevron.left"); Text(loc.t(.backTargets))
                }
                .buttonStyle(.borderless).font(.caption)
                Text(loc.t(.selectedSuffix, Format.bytes(state.selectedBytes(in: category))))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if showResults {
                Button(loc.t(.clean)) { Task { await state.clean(category: category) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!state.hasSelection(in: category))
            }
            Button(loc.t(.quit)) { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
        }
    }
}
