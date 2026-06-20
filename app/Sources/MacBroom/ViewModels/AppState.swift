import Foundation
import SwiftUI
import MacBroomCore

/// Top-level observable state driving the menu bar UI.
@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning
        case ready
        case cleaning(done: Int, total: Int)
        case finished(freedBytes: Int64)
        case error(String)
    }

    @Published var phase: Phase = .idle
    @Published var candidates: [CleanCandidate] = []
    @Published var selected: Set<String> = []          // selected candidate paths
    @Published var disk: DiskStatus?

    private let engine: EngineBridge

    init(engine: EngineBridge = EngineBridge()) {
        self.engine = engine
    }

    var selectedBytes: Int64 {
        candidates.filter { selected.contains($0.path) }.reduce(0) { $0 + $1.sizeBytes }
    }

    var totalBytes: Int64 { candidates.reduce(0) { $0 + $1.sizeBytes } }

    /// AI-category candidates grouped into tool sections for display.
    var aiGroups: [AIToolGroup] {
        AIToolGroup.group(candidates.filter { $0.category == "ai" })
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

    func refreshDisk() async {
        disk = try? await engine.status()
    }

    func scan(categories: [CleanCategory] = CleanCategory.allCases) async {
        phase = .scanning
        do {
            let result = try await engine.scan(categories: categories)
            candidates = result.candidates.sorted { $0.sizeBytes > $1.sizeBytes }
            // Pre-select everything the scan surfaced — these are already filtered
            // to safe, regenerable paths by mole's protection layer.
            selected = Set(candidates.map(\.path))
            phase = .ready
            await refreshDisk()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func clean(categories: [CleanCategory] = CleanCategory.allCases) async {
        let approved = Array(selected)
        guard !approved.isEmpty else { return }
        let total = approved.count
        phase = .cleaning(done: 0, total: total)
        var freed: Int64 = 0
        var done = 0
        do {
            for try await event in engine.clean(approvedPaths: approved, categories: categories) {
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
            await refreshDisk()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func toggle(_ path: String) {
        if selected.contains(path) { selected.remove(path) } else { selected.insert(path) }
    }
}
