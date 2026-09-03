import XCTest
@testable import BreatheKit

final class ProgressionTests: XCTestCase {
    private let day: TimeInterval = 86_400

    func testReassessmentIsDueEveryTwoWeeks() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(Progression.isReassessmentDue(lastAssessment: nil, now: now))
        XCTAssertFalse(Progression.isReassessmentDue(lastAssessment: now.addingTimeInterval(-13 * day), now: now))
        XCTAssertTrue(Progression.isReassessmentDue(lastAssessment: now.addingTimeInterval(-14 * day), now: now))
        XCTAssertEqual(Progression.nextReassessment(after: now), now.addingTimeInterval(14 * day))
        XCTAssertEqual(Progression.daysUntilReassessment(lastAssessment: now.addingTimeInterval(-10 * day), now: now), 4)
        XCTAssertEqual(Progression.daysUntilReassessment(lastAssessment: now.addingTimeInterval(-20 * day), now: now), 0)
        XCTAssertEqual(Progression.daysUntilReassessment(lastAssessment: nil, now: now), 0)
    }

    func testMissingAssessmentsComeFirst() {
        XCTAssertEqual(Progression.recommendedKind(baselines: .empty, completedSessions: 3), .boltAssessment)
        let partial = Baselines(boltSeconds: 25)
        XCTAssertEqual(Progression.recommendedKind(baselines: partial, completedSessions: 3), .maxHoldAssessment)
    }

    func testRotationCyclesThroughAllPillars() {
        let full = Baselines(boltSeconds: 25, maxHoldSeconds: 90, breathCountSeconds: 30)
        let week = (0..<7).map { Progression.recommendedKind(baselines: full, completedSessions: $0) }
        XCTAssertEqual(week, Progression.rotation)
        XCTAssertEqual(Set(week), Set(SessionKind.trainingProtocols))
        XCTAssertEqual(Progression.recommendedKind(baselines: full, completedSessions: 7), .cadence)
        XCTAssertEqual(Progression.recommendedKind(baselines: full, completedSessions: -1), .imt)
    }

    func testEstimatedDurations() {
        let full = Baselines(boltSeconds: 25, maxHoldSeconds: 90, breathCountSeconds: 30)
        XCTAssertEqual(Progression.estimatedDuration(for: .co2Table, baselines: full), 775)
        XCTAssertEqual(Progression.estimatedDuration(for: .boltAssessment, baselines: full), 16 + 60)
    }
}
