import Foundation

/// One entry in the cleaning history: when, how much, how many, and which flow.
public struct CleanRecord: Codable, Sendable {
    public var date: Date
    public var freedBytes: Int64
    public var count: Int
    public var kind: String   // "cache" | "apps" | "disk" | "auto"

    public init(date: Date, freedBytes: Int64, count: Int, kind: String) {
        self.date = date
        self.freedBytes = freedBytes
        self.count = count
        self.kind = kind
    }

    /// Localized label for the flow that produced this entry.
    public var kindKey: L10n {
        switch kind {
        case "apps": return .historyApps
        case "disk": return .historyDisk
        case "auto": return .historyAuto
        default:     return .historyCache
        }
    }

    public var iconName: String {
        switch kind {
        case "apps": return "macwindow"
        case "disk": return "chart.bar.doc.horizontal"
        case "auto": return "clock.arrow.circlepath"
        default:     return "sparkles"
        }
    }
}
