import Foundation

/// Pure statistics over session history for the Progress screen.
public enum TrainingStats {
    /// Consecutive calendar days with at least one session, counting back
    /// from today (or from yesterday if nothing has been done yet today).
    public static func currentStreak(sessionDates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(sessionDates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor), days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Sessions in the last seven days including today.
    public static func sessionsThisWeek(sessionDates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return 0 }
        return sessionDates.filter { $0 >= start && $0 <= now }.count
    }

    /// Sum of all recorded hold durations.
    public static func totalHoldTime(_ holdGroups: [[TimeInterval]]) -> TimeInterval {
        holdGroups.reduce(0) { $0 + $1.reduce(0, +) }
    }
}
