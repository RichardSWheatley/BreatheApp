import XCTest
@testable import BreatheKit

final class TrainingStatsTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let now = Date(timeIntervalSince1970: 1_800_000_000 + 12 * 3600) // midday UTC
    private func daysAgo(_ n: Int) -> Date { now.addingTimeInterval(-Double(n) * 86_400) }

    func testStreakCountsConsecutiveDays() {
        XCTAssertEqual(TrainingStats.currentStreak(sessionDates: [], now: now, calendar: calendar), 0)
        XCTAssertEqual(TrainingStats.currentStreak(sessionDates: [now], now: now, calendar: calendar), 1)
        XCTAssertEqual(TrainingStats.currentStreak(sessionDates: [now, daysAgo(1), daysAgo(2)], now: now, calendar: calendar), 3)
        XCTAssertEqual(TrainingStats.currentStreak(sessionDates: [now, daysAgo(2)], now: now, calendar: calendar), 1)
        XCTAssertEqual(TrainingStats.currentStreak(sessionDates: [now, now.addingTimeInterval(-60), daysAgo(1)], now: now, calendar: calendar), 2)
    }

    func testStreakSurvivesUntilEndOfToday() {
        XCTAssertEqual(TrainingStats.currentStreak(sessionDates: [daysAgo(1), daysAgo(2)], now: now, calendar: calendar), 2)
        XCTAssertEqual(TrainingStats.currentStreak(sessionDates: [daysAgo(2), daysAgo(3)], now: now, calendar: calendar), 0)
    }

    func testSessionsThisWeek() {
        let dates = [now, daysAgo(1), daysAgo(6), daysAgo(7), daysAgo(20)]
        XCTAssertEqual(TrainingStats.sessionsThisWeek(sessionDates: dates, now: now, calendar: calendar), 3)
        XCTAssertEqual(TrainingStats.sessionsThisWeek(sessionDates: [], now: now, calendar: calendar), 0)
    }

    func testTotalHoldTime() {
        XCTAssertEqual(TrainingStats.totalHoldTime([[10, 20], [], [5]]), 35)
        XCTAssertEqual(TrainingStats.totalHoldTime([]), 0)
    }

    func testStandardPlanWithRoundsOverride() {
        let baselines = Baselines(boltSeconds: 25, maxHoldSeconds: 90, breathCountSeconds: 30)
        XCTAssertEqual(SessionPlan.standard(for: .co2Table, baselines: baselines, rounds: 4).roundCount, 4)
        XCTAssertEqual(SessionPlan.standard(for: .imt, baselines: baselines, rounds: 2).roundCount, 2)
        XCTAssertEqual(SessionPlan.standard(for: .hypoxicSprints, baselines: baselines, rounds: 8).roundCount, 8)
        XCTAssertEqual(SessionPlan.standard(for: .cadence, baselines: baselines, rounds: 5).roundCount, 5)
        XCTAssertEqual(SessionPlan.standard(for: .boltAssessment, baselines: baselines, rounds: 9), SessionPlan.boltAssessment())
        XCTAssertEqual(SessionPlan.standard(for: .o2Table, baselines: baselines, rounds: nil), SessionPlan.o2Table(maxHold: 90))
        XCTAssertEqual(SessionPlan.roundRange(for: .co2Table), 1...12)
        XCTAssertNil(SessionPlan.roundRange(for: .boltAssessment))
        XCTAssertEqual(SessionPlan.defaultRounds(for: .imt), 3)
        XCTAssertNil(SessionPlan.defaultRounds(for: .maxHoldAssessment))
    }
}
