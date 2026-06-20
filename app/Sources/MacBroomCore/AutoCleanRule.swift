import Foundation

/// A per-tool automatic-clean schedule with timing parameters.
///
/// - `hourly`   fires every `hourInterval` hours (aligned to the start of day).
/// - `daily`    fires at `hour:minute` each day.
/// - `weekly`   fires at `hour:minute` on `weekday` (1=Sun … 7=Sat, Calendar convention).
/// - `monthly`  fires at `hour:minute` on `dayOfMonth` (1…28).
public struct AutoCleanRule: Codable, Equatable, Sendable {
    public var frequency: CleanFrequency
    public var hourInterval: Int   // hourly: every N hours (1…12)
    public var hour: Int           // time-of-day 0…23 (daily/weekly/monthly)
    public var minute: Int         // 0…59
    public var weekday: Int        // 1…7 (weekly)
    public var dayOfMonth: Int     // 1…28 (monthly)

    public init(frequency: CleanFrequency = .off, hourInterval: Int = 1,
                hour: Int = 3, minute: Int = 0, weekday: Int = 2, dayOfMonth: Int = 1) {
        self.frequency = frequency
        self.hourInterval = max(1, min(12, hourInterval))
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
        self.weekday = max(1, min(7, weekday))
        self.dayOfMonth = max(1, min(28, dayOfMonth))
    }

    public static let off = AutoCleanRule(frequency: .off)
    public var isEnabled: Bool { frequency != .off }

    /// Is a clean due now — i.e. a scheduled fire time elapsed since `lastRun`?
    public func isDue(lastRun: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard let fire = lastFireDate(onOrBefore: now, calendar: calendar) else { return false }
        return (lastRun ?? .distantPast) < fire
    }

    /// The most recent scheduled fire time at or before `now` (nil when off).
    public func lastFireDate(onOrBefore now: Date, calendar: Calendar = .current) -> Date? {
        switch frequency {
        case .off:
            return nil
        case .hourly:
            // Align to hourInterval-hour steps anchored at the start of the day.
            let n = max(1, hourInterval)
            let startOfDay = calendar.startOfDay(for: now)
            let hoursSince = Int(now.timeIntervalSince(startOfDay) / 3600)
            let step = (hoursSince / n) * n
            return calendar.date(byAdding: .hour, value: step, to: startOfDay)
        case .daily:
            return latestTimeOfDay(onOrBefore: now, calendar: calendar)
        case .weekly:
            guard var t = latestTimeOfDay(onOrBefore: now, calendar: calendar) else { return nil }
            for _ in 0..<7 {
                if calendar.component(.weekday, from: t) == weekday { return t }
                guard let prev = calendar.date(byAdding: .day, value: -1, to: t) else { break }
                t = prev
            }
            return t
        case .monthly:
            var comps = calendar.dateComponents([.year, .month], from: now)
            comps.day = min(dayOfMonth, 28); comps.hour = hour; comps.minute = minute; comps.second = 0
            guard var fire = calendar.date(from: comps) else { return nil }
            if fire > now, let prevMonth = calendar.date(byAdding: .month, value: -1, to: now) {
                var pc = calendar.dateComponents([.year, .month], from: prevMonth)
                pc.day = min(dayOfMonth, 28); pc.hour = hour; pc.minute = minute; pc.second = 0
                fire = calendar.date(from: pc) ?? fire
            }
            return fire
        }
    }

    /// Today at `hour:minute` if that's already passed, else yesterday at `hour:minute`.
    private func latestTimeOfDay(onOrBefore now: Date, calendar: Calendar) -> Date? {
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour; comps.minute = minute; comps.second = 0
        guard let today = calendar.date(from: comps) else { return nil }
        if today <= now { return today }
        return calendar.date(byAdding: .day, value: -1, to: today)
    }
}
