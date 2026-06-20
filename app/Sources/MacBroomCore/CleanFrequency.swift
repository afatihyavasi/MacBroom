import Foundation

/// How often an AI tool's caches are cleaned automatically.
public enum CleanFrequency: String, CaseIterable, Identifiable, Sendable {
    case off, hourly, daily, weekly, monthly

    public var id: String { rawValue }

    /// Seconds between automatic cleans (`0` when disabled).
    public var interval: TimeInterval {
        switch self {
        case .off:     return 0
        case .hourly:  return 3_600
        case .daily:   return 86_400
        case .weekly:  return 604_800
        case .monthly: return 2_592_000   // 30 days
        }
    }

    public var titleKey: L10n {
        switch self {
        case .off:     return .freqOff
        case .hourly:  return .freqHourly
        case .daily:   return .freqDaily
        case .weekly:  return .freqWeekly
        case .monthly: return .freqMonthly
        }
    }

    /// Is `now` far enough past `last` that another clean is due?
    public func isDue(since last: Date?, now: Date) -> Bool {
        guard self != .off else { return false }
        return now.timeIntervalSince(last ?? .distantPast) >= interval
    }
}
