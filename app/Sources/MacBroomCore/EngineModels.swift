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

/// Disk snapshot from `status`.
public struct DiskStatus: Codable {
    public var total: Int64
    public var used: Int64
    public var free: Int64
    public var usedPercent: Int

    enum DiskKeys: String, CodingKey {
        case totalBytes = "total_bytes"
        case usedBytes = "used_bytes"
        case freeBytes = "free_bytes"
        case usedPercent = "used_percent"
    }
    enum RootKeys: String, CodingKey { case disk }

    public init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        let d = try root.nestedContainer(keyedBy: DiskKeys.self, forKey: .disk)
        total = try d.decode(Int64.self, forKey: .totalBytes)
        used = try d.decode(Int64.self, forKey: .usedBytes)
        free = try d.decode(Int64.self, forKey: .freeBytes)
        usedPercent = try d.decode(Int.self, forKey: .usedPercent)
    }
}

/// Streaming events emitted by `clean` (NDJSON, one per line).
public enum EngineEvent: Equatable {
    case progress(path: String, freedBytes: Int64)
    case done(freedBytes: Int64, count: Int)

    /// Raw decode shape; `event` discriminates the case.
    private struct Wire: Codable {
        var event: String
        var path: String?
        var freedBytes: Int64?
        var count: Int?
        enum CodingKeys: String, CodingKey {
            case event, path, count
            case freedBytes = "freed_bytes"
        }
    }

    public init?(jsonLine line: String) {
        guard let data = line.data(using: .utf8),
              let w = try? JSONDecoder().decode(Wire.self, from: data) else { return nil }
        switch w.event {
        case "progress": self = .progress(path: w.path ?? "", freedBytes: w.freedBytes ?? 0)
        case "done":     self = .done(freedBytes: w.freedBytes ?? 0, count: w.count ?? 0)
        default:         return nil
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
        case .ai: return "AI Araçları"
        case .system: return "Sistem"
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
    public static func diskStatus(_ data: Data) throws -> DiskStatus {
        try JSONDecoder().decode(DiskStatus.self, from: data)
    }
}
