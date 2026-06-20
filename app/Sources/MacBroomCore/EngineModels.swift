import Foundation

/// One regenerable path the engine proposes for deletion.
public struct CleanCandidate: Codable, Identifiable, Hashable {
    public var category: String
    public var label: String
    public var path: String
    public var sizeBytes: Int64

    /// Stable identity = absolute path (paths are unique per scan).
    public var id: String { path }

    enum CodingKeys: String, CodingKey {
        case category, label, path
        case sizeBytes = "size_bytes"
    }

    public init(category: String, label: String, path: String, sizeBytes: Int64) {
        self.category = category
        self.label = label
        self.path = path
        self.sizeBytes = sizeBytes
    }
}

/// Result of a `scan` / `ai-scan` invocation.
public struct ScanResult: Codable {
    public var candidates: [CleanCandidate]
    public var count: Int
}

/// An analyzable target from `discover` (fast existence check, no sizing).
public struct AnalysisTarget: Codable, Identifiable, Hashable {
    public var id: String
    public var label: String
    public var category: String
    public var installed: Bool
}

public struct DiscoverResult: Codable {
    public var targets: [AnalysisTarget]
}

/// An installed, user-removable application from `apps`.
public struct AppInfo: Codable, Identifiable, Hashable {
    public var name: String
    public var path: String
    public var bundleId: String
    /// Absent in the fast `apps` listing; computed lazily during app-scan.
    public var sizeBytes: Int64?

    public var id: String { path }

    enum CodingKeys: String, CodingKey {
        case name, path
        case bundleId = "bundle_id"
        case sizeBytes = "size_bytes"
    }
}

public struct AppsResult: Codable {
    public var apps: [AppInfo]
}

/// Disk usage from `status`.
public struct DiskInfo: Codable {
    public var total: Int64
    public var used: Int64
    public var free: Int64
    public var usedPercent: Int

    enum CodingKeys: String, CodingKey {
        case total = "total_bytes"
        case used = "used_bytes"
        case free = "free_bytes"
        case usedPercent = "used_percent"
    }
}

/// Memory usage from `status`.
public struct MemoryInfo: Codable {
    public var total: Int64
    public var used: Int64
    public var usedPercent: Int

    enum CodingKeys: String, CodingKey {
        case total = "total_bytes"
        case used = "used_bytes"
        case usedPercent = "used_percent"
    }
}

/// Full `status` snapshot: disk plus optional memory.
public struct SystemStatus: Codable {
    public var disk: DiskInfo
    public var memory: MemoryInfo?
}

/// Streaming events emitted by `clean` (NDJSON, one per line).
public enum EngineEvent: Equatable {
    case progress(path: String, freedBytes: Int64)
    /// A path that could not be removed. `reason == "permission"` means the
    /// parent directory wasn't writable (Full Disk Access / admin may help).
    case skipped(path: String, reason: String)
    case done(freedBytes: Int64, count: Int, failed: Int)

    /// Raw decode shape; `event` discriminates the case.
    private struct Wire: Codable {
        var event: String
        var path: String?
        var reason: String?
        var freedBytes: Int64?
        var count: Int?
        var failed: Int?
        enum CodingKeys: String, CodingKey {
            case event, path, reason, count, failed
            case freedBytes = "freed_bytes"
        }
    }

    public init?(jsonLine line: String) {
        guard let data = line.data(using: .utf8),
              let w = try? JSONDecoder().decode(Wire.self, from: data) else { return nil }
        switch w.event {
        case "progress": self = .progress(path: w.path ?? "", freedBytes: w.freedBytes ?? 0)
        case "skipped":  self = .skipped(path: w.path ?? "", reason: w.reason ?? "failed")
        case "done":     self = .done(freedBytes: w.freedBytes ?? 0, count: w.count ?? 0, failed: w.failed ?? 0)
        default:         return nil
        }
    }
}

/// How approved paths are removed.
public enum DeleteMode: String, CaseIterable, Identifiable {
    case permanent
    case trash
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .permanent: return Localization.string(.deletePermanentTitle)
        case .trash: return Localization.string(.deleteTrashTitle)
        }
    }
    public var detail: String {
        switch self {
        case .permanent: return Localization.string(.deletePermanentDetail)
        case .trash: return Localization.string(.deleteTrashDetail)
        }
    }
}

/// Categories surfaced in the UI.
public enum CleanCategory: String, CaseIterable, Identifiable {
    case ai
    case system
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ai: return Localization.string(.categoryAI)
        case .system: return Localization.string(.categorySystem)
        }
    }
    public var systemImage: String {
        switch self {
        case .ai: return "sparkles"
        case .system: return "internaldrive"
        }
    }
}

/// Decode helpers exposed so framework-free tests (and callers) can validate the
/// engine protocol without touching internal synthesized initializers.
public enum EngineDecode {
    public static func scanResult(_ data: Data) throws -> ScanResult {
        try JSONDecoder().decode(ScanResult.self, from: data)
    }
    public static func systemStatus(_ data: Data) throws -> SystemStatus {
        try JSONDecoder().decode(SystemStatus.self, from: data)
    }
}
