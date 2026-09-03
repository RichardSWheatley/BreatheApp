import XCTest
@testable import BreatheKit

final class AssessmentTests: XCTestCase {
    func testBOLTPlanEndsInMeasuredOpenEndedEmptyHold() {
        let plan = SessionPlan.boltAssessment()
        XCTAssertEqual(plan.kind, .boltAssessment)
        XCTAssertEqual(plan.steps.map(\.phase), [.prepare, .inhale, .exhale, .holdEmpty])
        XCTAssertEqual(plan.steps.map(\.duration), [10, 3, 3, nil])
        XCTAssertTrue(plan.isOpenEnded)
        XCTAssertEqual(plan.measuredStep?.phase, .holdEmpty)
        XCTAssertEqual(plan.plannedDuration, 16)
    }

    func testMaxHoldPlanTakesThreeDeepBreathsThenHolds() {
        let plan = SessionPlan.maxHoldAssessment()
        XCTAssertEqual(plan.steps.map(\.phase), [.prepare, .inhale, .exhale, .inhale, .exhale, .inhale, .holdFull])
        XCTAssertEqual(plan.steps.filter { $0.phase == .inhale }.count, 3)
        XCTAssertEqual(plan.steps.last?.isMeasured, true)
        XCTAssertNil(plan.steps.last?.duration)
        XCTAssertTrue(plan.steps[5].instruction.contains("100%"))
    }

    func testBreathCountPlan() {
        let plan = SessionPlan.breathCountAssessment()
        XCTAssertEqual(plan.steps.map(\.phase), [.prepare, .inhale, .countAloud])
        XCTAssertEqual(plan.measuredStep?.phase, .countAloud)
    }

    func testStandardPlanForEveryKind() {
        for kind in SessionKind.allCases {
            let plan = SessionPlan.standard(for: kind, baselines: .empty)
            XCTAssertEqual(plan.kind, kind)
            XCTAssertFalse(plan.steps.isEmpty)
            XCTAssertEqual(plan.isOpenEnded, kind.isAssessment)
        }
    }

    func testStandardPlanUsesDefaultMaxHoldBeforeAssessment() {
        let plan = SessionPlan.standard(for: .co2Table, baselines: .empty)
        XCTAssertEqual(plan.holdSteps.first?.duration, Progression.defaultMaxHold * 0.5)
        let assessed = SessionPlan.standard(for: .co2Table, baselines: Baselines(maxHoldSeconds: 120))
        XCTAssertEqual(assessed.holdSteps.first?.duration, 60)
    }

    func testScoringBands() {
        XCTAssertEqual(AssessmentScoring.boltBand(seconds: 10), .developing)
        XCTAssertEqual(AssessmentScoring.boltBand(seconds: 25), .normal)
        XCTAssertEqual(AssessmentScoring.boltBand(seconds: 35), .strong)
        XCTAssertEqual(AssessmentScoring.boltBand(seconds: 40), .elite)
        XCTAssertEqual(AssessmentScoring.maxHoldBand(seconds: 30), .developing)
        XCTAssertEqual(AssessmentScoring.maxHoldBand(seconds: 90), .strong)
        XCTAssertEqual(AssessmentScoring.maxHoldBand(seconds: 180), .elite)
        XCTAssertEqual(AssessmentScoring.breathCountBand(seconds: 20), .normal)
        XCTAssertEqual(AssessmentScoring.band(for: .breathCountAssessment, seconds: 50), .elite)
        XCTAssertNil(AssessmentScoring.band(for: .cadence, seconds: 50))
    }

    func testBaselinesRecording() {
        var baselines = Baselines.empty
        XCTAssertFalse(baselines.isComplete)
        XCTAssertEqual(baselines.missingAssessments, [.boltAssessment, .maxHoldAssessment, .breathCountAssessment])

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        baselines.record(.boltAssessment, seconds: 28, at: date)
        XCTAssertEqual(baselines.boltSeconds, 28)
        XCTAssertEqual(baselines.assessedAt, date)
        XCTAssertEqual(baselines.missingAssessments, [.maxHoldAssessment, .breathCountAssessment])

        baselines.record(.maxHoldAssessment, seconds: 95, at: date)
        baselines.record(.breathCountAssessment, seconds: 33, count: 41, at: date)
        XCTAssertTrue(baselines.isComplete)
        XCTAssertEqual(baselines.breathCount, 41)

        // Training kinds are ignored.
        baselines.record(.cadence, seconds: 1, at: date.addingTimeInterval(99))
        XCTAssertEqual(baselines.assessedAt, date)
    }
}
