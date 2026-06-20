import SwiftUI
import MacBroomCore

/// Root menu bar panel: header + live status, then a three-way section switch
/// (AI caches · System caches · Apps uninstaller).
struct MenuBarView: View {
    @EnvironmentObject var state: AppState

    enum Section: String, CaseIterable, Identifiable {
        case ai, system, apps
        var id: String { rawValue }
        var title: String {
            switch self {
            case .ai: return "AI"
            case .system: return "Sistem"
            case .apps: return "Uygulamalar"
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
                ForEach(Section.allCases) { Text($0.title).tag($0) }
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
        .sheet(isPresented: $showingSettings) { SettingsView() }
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
            .help("Hedefleri yeniden bul")
            .disabled(state.phase == .scanning || state.phase == .discovering)
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Ayarlar")
        }
    }

    // MARK: onboarding

    private var onboardingBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tam Disk Erişimi").font(.caption.weight(.semibold))
                Text("Tüm önbellekleri temizlemek için izin verin.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Aç") {
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
        switch state.phase {
        case .idle, .discovering:
            loading("Hedefler aranıyor…")
        case .scanning:
            loading("Seçili hedefler taranıyor…")
        case let .cleaning(done, total):
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                Text("Temizleniyor… \(done)/\(total)").font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 8)
        case let .finished(freed):
            VStack(spacing: 8) {
                Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.green)
                Text("\(Format.bytes(freed)) boşaltıldı").font(.title3.weight(.semibold))
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .error(msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.red).padding(.vertical, 8)
        case .selecting:
            // Per-tab: show this category's results if already analyzed, else
            // its target picker. AI and System are fully independent here.
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

    private var showResults: Bool {
        if case .selecting = state.phase { return state.isScanned(category) }
        return false
    }

    private var cleanControls: some View {
        HStack {
            if showResults {
                Button { state.backToSelection(category: category) } label: {
                    Image(systemName: "chevron.left"); Text("Hedefler")
                }
                .buttonStyle(.borderless).font(.caption)
                Text("\(Format.bytes(state.selectedBytes)) seçili")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if showResults {
                Button("Temizle") { Task { await state.clean() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.selected.isEmpty)
            }
            Button("Çıkış") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
        }
    }
}
