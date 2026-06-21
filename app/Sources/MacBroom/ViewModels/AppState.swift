import Foundation
import SwiftUI
import MacBroomCore

/// Top-level observable state driving the menu bar UI.
@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable {
        case idle
        case discovering
        case selecting          // interactive: per-tab picker or results
        case scanning
        case cleaning(done: Int, total: Int, freedBytes: Int64)
        case finished(freedBytes: Int64, failed: Int, permissionBlocked: Bool)
        case error(String)
    }

    /// A long-running cache operation is in flight (gate refresh/destructive UI).
    var isBusy: Bool {
        switch phase {
        case .discovering, .scanning, .cleaning: return true
        default: return false
        }
    }

    @Published var phase: Phase = .idle
    /// All-time bytes reclaimed across every successful clean path, persisted in
    /// UserDefaults so it survives launches (a small trust/payoff stat).
    @Published private(set) var totalReclaimed: Int64 = 0
    private let totalReclaimedKey = "totalReclaimedBytes"
    /// Which cache tab a transient phase (scanning/cleaning/finished/error)
    /// belongs to. `nil` = a global phase (discovery) shown on every tab. This
    /// keeps the AI and System tabs from leaking each other's progress/results.
    @Published var phaseCategory: CleanCategory?
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
        totalReclaimed = UserDefaults.standard.object(forKey: totalReclaimedKey) as? Int64
            ?? Int64(UserDefaults.standard.integer(forKey: totalReclaimedKey))
        loadSchedules()
        foldReclaimedLedger()
        startScheduler()
    }

    /// Increment the all-time reclaimed total and persist it. No-op for ≤0.
    private func addReclaimed(_ bytes: Int64) {
        guard bytes > 0 else { return }
        totalReclaimed += bytes
        UserDefaults.standard.set(totalReclaimed, forKey: totalReclaimedKey)
    }

    /// Fold in bytes freed by launchd-triggered cleans (which ran with no app)
    /// from the ledger file, then reset it — so the all-time stat stays accurate
    /// even when scheduled cleaning happened while MacBroom was quit.
    private func foldReclaimedLedger() {
        let url = LaunchAgentManager.ledgerURL
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let bytes = Int64(text.trimmingCharacters(in: .whitespacesAndNewlines)), bytes > 0
        else { return }
        addReclaimed(bytes)
        try? "0".write(to: url, atomically: true, encoding: .utf8)
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
        phaseCategory = nil          // discovery is global (both tabs)
        phase = .discovering
        do {
            let found = try await engine.discover()
            targets = found
            selectedTargets = Set(found.filter { $0.installed && $0.category == "ai" }.map(\.id))
            candidates = []
            selected = []
            scannedCategories = []
            scannedTargets = []
            phase = .selecting
            await refreshStatus()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func toggleTarget(_ id: String) {
        if selectedTargets.contains(id) { selectedTargets.remove(id) } else { selectedTargets.insert(id) }
    }

    /// Tri-state selection across a category's installed targets (drives the
    /// analyze screen's select-all/deselect-all toggle).
    func targetsSelectionState(in category: CleanCategory) -> Bool? {
        let items = installedTargets(in: category)
        guard !items.isEmpty else { return false }
        let sel = items.filter { selectedTargets.contains($0.id) }.count
        if sel == 0 { return false }
        if sel == items.count { return true }
        return nil
    }

    func toggleAllTargets(in category: CleanCategory) {
        let items = installedTargets(in: category)
        let allSelected = targetsSelectionState(in: category) == true
        for t in items {
            if allSelected { selectedTargets.remove(t.id) } else { selectedTargets.insert(t.id) }
        }
    }

    var installedTargets: [AnalysisTarget] { targets.filter { $0.installed } }

    /// Installed targets for one category (drives the per-tab selection screen).
    func installedTargets(in category: CleanCategory) -> [AnalysisTarget] {
        installedTargets.filter { $0.category == category.rawValue }
    }

    /// Selected target count within a category (for the per-tab button label).
    func selectedTargetCount(in category: CleanCategory) -> Int {
        installedTargets(in: category).filter { selectedTargets.contains($0.id) }.count
    }

    /// Categories the user has already analyzed (drives selection-vs-results).
    @Published var scannedCategories: Set<String> = []

    func isScanned(_ category: CleanCategory) -> Bool { scannedCategories.contains(category.rawValue) }

    /// Scan only the selected targets in ONE category, keeping other categories'
    /// results intact — so AI and System tabs analyze independently.
    func scanSelected(category: CleanCategory) async {
        let ids = installedTargets(in: category)
            .map(\.id).filter { selectedTargets.contains($0) }
        guard !ids.isEmpty else { return }
        scannedTargets = Array(Set(scannedTargets).union(ids))
        phaseCategory = category
        phase = .scanning
        do {
            let result = try await engine.scan(targetIds: ids)
            // Replace this category's candidates, keep the others.
            candidates.removeAll { $0.category == category.rawValue }
            candidates.append(contentsOf: result.candidates)
            candidates.sort { $0.sizeBytes > $1.sizeBytes }
            // Pre-select AI caches; system caches stay opt-in.
            if category == .ai {
                selected.formUnion(result.candidates.map(\.path))
            }
            scannedCategories.insert(category.rawValue)
            phase = .selecting
            await refreshStatus()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    /// Return one category to its selection screen.
    func backToSelection(category: CleanCategory) {
        let paths = Set(candidates.filter { $0.category == category.rawValue }.map(\.path))
        candidates.removeAll { $0.category == category.rawValue }
        selected.subtract(paths)
        scannedCategories.remove(category.rawValue)
        phase = .selecting
    }

    /// Any selected candidate in this category? (drives the Clean button.)
    func hasSelection(in category: CleanCategory) -> Bool {
        candidates(in: category).contains { selected.contains($0.path) }
    }

    /// Leave a finished/error screen and return the tab to its resting view.
    func dismissCacheResult() {
        phaseCategory = nil
        phase = .selecting
    }

    /// Clean ONLY the selected items in `category` — scoped so cleaning the AI
    /// tab never touches System selections (and vice versa).
    func clean(category: CleanCategory) async {
        let categoryPaths = Set(candidates(in: category).map(\.path))
        let approvedSet = selected.intersection(categoryPaths)
        guard !approvedSet.isEmpty else { return }
        let approved = Array(approvedSet)
        let ids = scannedTargets.filter { $0.hasPrefix(category.rawValue + ":") }
        let total = approved.count
        phaseCategory = category
        phase = .cleaning(done: 0, total: total, freedBytes: 0)
        var freed: Int64 = 0
        var done = 0, failed = 0
        var permissionBlocked = false
        var removed = Set<String>()
        do {
            for try await event in engine.clean(approvedPaths: approved, targetIds: ids, deleteMode: deleteMode) {
                switch event {
                case let .progress(path, bytes):
                    freed += bytes
                    done += 1
                    removed.insert(path)
                    phase = .cleaning(done: done, total: total, freedBytes: freed)
                case let .skipped(_, reason):
                    done += 1
                    failed += 1
                    if reason == "permission" { permissionBlocked = true }
                    phase = .cleaning(done: done, total: total, freedBytes: freed)
                case let .done(freedBytes, _, failedCount):
                    freed = max(freed, freedBytes)
                    failed = max(failed, failedCount)
                }
            }
            // Drop only the items actually removed; keep failed ones (and the
            // other tab's selection) intact so the user can retry.
            candidates.removeAll { removed.contains($0.path) }
            selected.subtract(removed)
            addReclaimed(freed)
            phase = .finished(freedBytes: freed, failed: failed, permissionBlocked: permissionBlocked)
            await refreshStatus()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func toggle(_ path: String) {
        if selected.contains(path) { selected.remove(path) } else { selected.insert(path) }
    }

    // MARK: - Disk analysis (read-only large-file finder)
    //
    // Independent of the cache `phase` (like the app uninstaller flow), so opening
    // the Disk Analysis window never disturbs the menu-bar cache tabs.

    enum AnalyzeFlow: Equatable {
        case scanning
        case ready
        case deleting(done: Int, total: Int, freedBytes: Int64)
        case finished(freedBytes: Int64, failed: Int, permissionBlocked: Bool)
        case error(String)
    }

    @Published var largeFiles: [LargeFile] = []
    @Published var largeSelected: Set<String> = []
    @Published var analyzeFlow: AnalyzeFlow = .scanning

    var largeSelectedBytes: Int64 {
        largeFiles.filter { largeSelected.contains($0.path) }.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Tri-state selection across the listed large files (drives select-all).
    var largeSelectionState: Bool? {
        if largeSelected.isEmpty { return false }
        if largeSelected.count == largeFiles.count { return true }
        return nil
    }

    func toggleLargeFile(_ path: String) {
        if largeSelected.contains(path) { largeSelected.remove(path) } else { largeSelected.insert(path) }
    }

    func toggleAllLargeFiles() {
        if largeSelectionState == true { largeSelected.removeAll() }
        else { largeSelected = Set(largeFiles.map(\.path)) }
    }

    /// Read-only scan for the largest user files. Never deletes.
    func analyzeDisk() async {
        analyzeFlow = .scanning
        largeSelected = []
        do {
            largeFiles = try await engine.analyze()
            analyzeFlow = .ready
        } catch {
            analyzeFlow = .error(error.localizedDescription)
        }
    }

    /// Delete the given large files. SAFETY: these are user data, not caches, so
    /// deletion ALWAYS goes to Trash (regardless of the user's deletion setting)
    /// through the same protection-gated `appClean` sink the uninstaller uses.
    func deleteLargeFiles(_ paths: [String]) async {
        guard !paths.isEmpty else { return }
        let total = paths.count
        analyzeFlow = .deleting(done: 0, total: total, freedBytes: 0)
        var freed: Int64 = 0, done = 0, failed = 0, permissionBlocked = false
        var removed = Set<String>()
        do {
            for try await event in engine.appClean(approvedPaths: paths, deleteMode: .trash) {
                switch event {
                case let .progress(path, bytes):
                    freed += bytes; done += 1; removed.insert(path)
                    analyzeFlow = .deleting(done: done, total: total, freedBytes: freed)
                case let .skipped(_, reason):
                    failed += 1; done += 1
                    if reason == "permission" { permissionBlocked = true }
                    analyzeFlow = .deleting(done: done, total: total, freedBytes: freed)
                case let .done(freedBytes, _, failedCount):
                    freed = max(freed, freedBytes)
                    failed = max(failed, failedCount)
                }
            }
            // Drop only the files actually removed; keep failed ones so the user
            // can see what remained.
            largeFiles.removeAll { removed.contains($0.path) }
            largeSelected.subtract(removed)
            addReclaimed(freed)
            analyzeFlow = .finished(freedBytes: freed, failed: failed, permissionBlocked: permissionBlocked)
            await refreshStatus()
        } catch {
            analyzeFlow = .error(error.localizedDescription)
        }
    }

    // MARK: - App uninstaller flow

    enum UninstallFlow: Equatable {
        case browsing
        case loading
        case reviewing(AppInfo)
        case uninstalling(done: Int, total: Int, freedBytes: Int64)
        /// `failed` > 0 means some paths couldn't be removed; `permissionBlocked`
        /// flags that Full Disk Access / admin rights would likely unblock them.
        case uninstalled(freedBytes: Int64, failed: Int, permissionBlocked: Bool)
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
            apps = try await engine.apps()
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

    /// Tri-state selection across the reviewed app's items (select-all toggle).
    var appSelectionState: Bool? {
        guard !appCandidates.isEmpty else { return false }
        let sel = appCandidates.filter { appSelected.contains($0.path) }.count
        if sel == 0 { return false }
        if sel == appCandidates.count { return true }
        return nil
    }

    func toggleAllAppItems() {
        if appSelectionState == true { appSelected.removeAll() }
        else { appSelected = Set(appCandidates.map(\.path)) }
    }

    func uninstall() async {
        let approved = Array(appSelected)
        guard !approved.isEmpty else { return }
        let total = approved.count
        appFlow = .uninstalling(done: 0, total: total, freedBytes: 0)
        var freed: Int64 = 0, done = 0, failed = 0, permissionBlocked = false
        do {
            for try await event in engine.appClean(approvedPaths: approved, deleteMode: deleteMode) {
                switch event {
                case let .progress(_, bytes): freed += bytes; done += 1
                    appFlow = .uninstalling(done: done, total: total, freedBytes: freed)
                case let .skipped(_, reason): failed += 1; done += 1
                    if reason == "permission" { permissionBlocked = true }
                    appFlow = .uninstalling(done: done, total: total, freedBytes: freed)
                case let .done(freedBytes, _, failedCount):
                    freed = max(freed, freedBytes)
                    failed = max(failed, failedCount)
                }
            }
            appCandidates = []
            appSelected = []
            // Drop the uninstalled app from the list (path no longer exists).
            apps.removeAll { !FileManager.default.fileExists(atPath: $0.path) }
            addReclaimed(freed)
            appFlow = .uninstalled(freedBytes: freed, failed: failed, permissionBlocked: permissionBlocked)
        } catch {
            appFlow = .error(error.localizedDescription)
        }
    }

    func backToAppList() {
        appCandidates = []
        appSelected = []
        appFlow = .browsing
    }

    // MARK: - Scheduled automatic AI cleaning

    /// Per-target schedule rules (only enabled entries are stored). Published so
    /// the automation UI reflects committed changes.
    @Published private(set) var rules: [String: AutoCleanRule] = [:]
    private var lastRun: [String: Date] = [:]
    private var schedulerStarted = false
    private let rulesKey = "autoCleanRules"
    private let lastRunKey = "autoCleanLastRun"

    func rule(for targetId: String) -> AutoCleanRule { rules[targetId] ?? .off }
    func lastRun(for targetId: String) -> Date? { lastRun[targetId] }

    /// Commit a full set of rules (the automation panel's "Save"). Newly-enabled
    /// rules start their clock now, so the first auto-clean is a full interval
    /// away (saving never wipes immediately).
    func applyRules(_ newRules: [String: AutoCleanRule]) {
        let now = Date()
        var next: [String: AutoCleanRule] = [:]
        for (id, rule) in newRules where rule.isEnabled {
            next[id] = rule
            if lastRun[id] == nil { lastRun[id] = now }
        }
        // Drop last-run stamps for targets no longer scheduled.
        for id in lastRun.keys where next[id] == nil { lastRun[id] = nil }
        rules = next
        persistRules()
        persistLastRun()
        syncLaunchAgents()
    }

    /// Install/refresh launchd agents so schedules also fire when the app is quit.
    /// Runs off the main actor — launchctl is a blocking subprocess and there may
    /// be one call per rule.
    private func syncLaunchAgents() {
        let snapshot = rules
        let enginePath = engine.enginePath, moleDir = engine.moleDir, mode = deleteMode.rawValue
        Task.detached {
            LaunchAgentManager.sync(rules: snapshot, enginePath: enginePath, moleDir: moleDir, deleteMode: mode)
        }
    }

    private func loadSchedules() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([String: AutoCleanRule].self, from: data) {
            rules = decoded.filter { $0.value.isEnabled }
        }
        if let raw = UserDefaults.standard.dictionary(forKey: lastRunKey) as? [String: Double] {
            lastRun = raw.mapValues { Date(timeIntervalSince1970: $0) }
        }
    }

    private func persistRules() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: rulesKey)
        }
    }
    private func persistLastRun() {
        UserDefaults.standard.set(lastRun.mapValues { $0.timeIntervalSince1970 }, forKey: lastRunKey)
    }

    /// App-lifetime loop: catch up on launch, then re-check every 5 minutes.
    /// Owned by AppState (not a view), so it survives the panel opening/closing.
    private func startScheduler() {
        guard !schedulerStarted else { return }
        schedulerStarted = true
        Task { [weak self] in
            // Refresh launchd agents to the current rules + engine path (the app
            // may have moved since last launch), then run the in-app catch-up.
            self?.syncLaunchAgents()
            await self?.runDueSchedules()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300 * 1_000_000_000)   // 5 min
                guard let self else { break }
                await self.runDueSchedules()
            }
        }
    }

    private func runDueSchedules() async {
        foldReclaimedLedger()           // pick up any launchd-run cleans
        guard !isBusy else { return }   // never fight a manual operation
        let now = Date()
        for (id, rule) in rules where rule.isDue(lastRun: lastRun[id], now: now) {
            await autoCleanTarget(id)
            lastRun[id] = Date()
            persistLastRun()
        }
        await refreshStatus()
    }

    /// Quietly scan one target and clean everything it surfaces. Runs entirely
    /// off the interactive `phase`, so a background auto-clean never disturbs
    /// whatever the user is looking at. Candidates are mole-protection-filtered,
    /// so cleaning all of them is the same safety contract as a manual clean.
    private func autoCleanTarget(_ targetId: String) async {
        // One engine call scans + cleans + posts a notification on success — the
        // same path the launchd agent uses, so behavior is identical whether the
        // app or launchd triggers it.
        if let result = try? await engine.autoClean(targetId: targetId, deleteMode: deleteMode) {
            addReclaimed(result.freed)
        }
    }
}
