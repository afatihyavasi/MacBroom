import Foundation
import SwiftUI
import MacBroomCore

/// Top-level observable state driving the menu bar UI.
@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable {
        case idle
        case discovering
        case selecting          // user chooses which targets to analyze
        case scanning
        case ready
        case cleaning(done: Int, total: Int)
        case finished(freedBytes: Int64)
        case error(String)
    }

    @Published var phase: Phase = .idle
    @Published var candidates: [CleanCandidate] = []
    @Published var selected: Set<String> = []          // selected candidate paths
    @Published var status: SystemStatus?

    // Discovery / target selection
    @Published var targets: [AnalysisTarget] = []
    @Published var selectedTargets: Set<String> = []   // target ids chosen to analyze
    private var scannedTargets: [String] = []          // targets actually scanned (for clean scope)

    private let engine: EngineBridge

    init(engine: EngineBridge = EngineBridge()) {
        self.engine = engine
    }

    /// User-chosen deletion policy (mirrors @AppStorage("deletionMode")).
    private var deleteMode: DeleteMode {
        DeleteMode(rawValue: UserDefaults.standard.string(forKey: "deletionMode") ?? "") ?? .permanent
    }

    var selectedBytes: Int64 {
        candidates.filter { selected.contains($0.path) }.reduce(0) { $0 + $1.sizeBytes }
    }

    var totalBytes: Int64 { candidates.reduce(0) { $0 + $1.sizeBytes } }

    /// AI-category candidates grouped into tool sections for display.
    var aiGroups: [AIToolGroup] {
        AIToolGroup.group(candidates.filter { $0.category == "ai" })
    }

    /// System-category candidates, largest first.
    var systemCandidates: [CleanCandidate] {
        candidates.filter { $0.category == "system" }.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    func candidates(in category: CleanCategory) -> [CleanCandidate] {
        candidates.filter { $0.category == category.rawValue }
    }

    func selectedBytes(in category: CleanCategory) -> Int64 {
        candidates(in: category).filter { selected.contains($0.path) }.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Tri-state selection for a whole category (true=all, false=none, nil=mixed).
    func selectionState(in category: CleanCategory) -> Bool? {
        let items = candidates(in: category)
        guard !items.isEmpty else { return false }
        let sel = items.filter { selected.contains($0.path) }.count
        if sel == 0 { return false }
        if sel == items.count { return true }
        return nil
    }

    func toggleAll(in category: CleanCategory) {
        let items = candidates(in: category)
        let allSelected = selectionState(in: category) == true
        for c in items {
            if allSelected { selected.remove(c.path) } else { selected.insert(c.path) }
        }
    }

    func isSelected(_ path: String) -> Bool { selected.contains(path) }

    func selectionState(for group: AIToolGroup) -> Bool? {
        let sel = group.candidates.filter { selected.contains($0.path) }.count
        if sel == 0 { return false }
        if sel == group.candidates.count { return true }
        return nil // mixed
    }

    func toggleGroup(_ group: AIToolGroup) {
        let allSelected = selectionState(for: group) == true
        for c in group.candidates {
            if allSelected { selected.remove(c.path) } else { selected.insert(c.path) }
        }
    }

    func refreshStatus() async {
        status = try? await engine.status()
    }

    // MARK: discovery -> selection -> scan

    /// Fast: find what's present and present the selection screen. AI targets
    /// are pre-checked (the safe headline); system targets are opt-in.
    func discover() async {
        phase = .discovering
        do {
            let found = try await engine.discover()
            targets = found
            selectedTargets = Set(found.filter { $0.installed && $0.category == "ai" }.map(\.id))
            phase = .selecting
            await refreshStatus()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func toggleTarget(_ id: String) {
        if selectedTargets.contains(id) { selectedTargets.remove(id) } else { selectedTargets.insert(id) }
    }

    var installedTargets: [AnalysisTarget] { targets.filter { $0.installed } }

    /// Scan only the targets the user selected.
    func scanSelected() async {
        let ids = Array(selectedTargets)
        guard !ids.isEmpty else { return }
        scannedTargets = ids
        phase = .scanning
        do {
            let result = try await engine.scan(targetIds: ids)
            candidates = result.candidates.sorted { $0.sizeBytes > $1.sizeBytes }
            // Pre-select AI caches; system caches stay opt-in.
            selected = Set(candidates.filter { $0.category == "ai" }.map(\.path))
            phase = .ready
            await refreshStatus()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// Return to the target selection screen.
    func backToSelection() {
        candidates = []
        selected = []
        phase = .selecting
    }

    func clean() async {
        let approved = Array(selected)
        guard !approved.isEmpty else { return }
        let total = approved.count
        phase = .cleaning(done: 0, total: total)
        var freed: Int64 = 0
        var done = 0
        do {
            for try await event in engine.clean(approvedPaths: approved, targetIds: scannedTargets, deleteMode: deleteMode) {
                switch event {
                case let .progress(_, bytes):
                    freed += bytes
                    done += 1
                    phase = .cleaning(done: done, total: total)
                case let .done(freedBytes, _):
                    freed = max(freed, freedBytes)
                }
            }
            // Drop cleaned items from the list.
            candidates.removeAll { selected.contains($0.path) }
            selected.removeAll()
            phase = .finished(freedBytes: freed)
            await refreshStatus()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func toggle(_ path: String) {
        if selected.contains(path) { selected.remove(path) } else { selected.insert(path) }
    }

    // MARK: - App uninstaller flow

    enum UninstallFlow: Equatable {
        case browsing
        case loading
        case reviewing(AppInfo)
        case uninstalling(done: Int, total: Int)
        case uninstalled(freedBytes: Int64)
        case error(String)
    }

    @Published var apps: [AppInfo] = []
    @Published var appFlow: UninstallFlow = .browsing
    @Published var appCandidates: [CleanCandidate] = []
    @Published var appSelected: Set<String> = []

    var appSelectedBytes: Int64 {
        appCandidates.filter { appSelected.contains($0.path) }.reduce(0) { $0 + $1.sizeBytes }
    }

    func loadApps() async {
        guard apps.isEmpty else { return }
        appFlow = .loading
        do {
            apps = try await engine.apps().sorted { $0.sizeBytes > $1.sizeBytes }
            appFlow = .browsing
        } catch {
            appFlow = .error(error.localizedDescription)
        }
    }

    func reviewApp(_ app: AppInfo) async {
        appFlow = .loading
        do {
            let result = try await engine.appScan(appPath: app.path)
            appCandidates = result.candidates
            appSelected = Set(appCandidates.map(\.path)) // pre-select all for full removal
            appFlow = .reviewing(app)
        } catch {
            appFlow = .error(error.localizedDescription)
        }
    }

    func toggleAppItem(_ path: String) {
        if appSelected.contains(path) { appSelected.remove(path) } else { appSelected.insert(path) }
    }

    func uninstall() async {
        let approved = Array(appSelected)
        guard !approved.isEmpty else { return }
        let total = approved.count
        appFlow = .uninstalling(done: 0, total: total)
        var freed: Int64 = 0, done = 0
        do {
            for try await event in engine.appClean(approvedPaths: approved, deleteMode: deleteMode) {
                switch event {
                case let .progress(_, bytes): freed += bytes; done += 1
                    appFlow = .uninstalling(done: done, total: total)
                case let .done(freedBytes, _): freed = max(freed, freedBytes)
                }
            }
            appCandidates = []
            appSelected = []
            // Drop the uninstalled app from the list (path no longer exists).
            apps.removeAll { !FileManager.default.fileExists(atPath: $0.path) }
            appFlow = .uninstalled(freedBytes: freed)
        } catch {
            appFlow = .error(error.localizedDescription)
        }
    }

    func backToAppList() {
        appCandidates = []
        appSelected = []
        appFlow = .browsing
    }
}
