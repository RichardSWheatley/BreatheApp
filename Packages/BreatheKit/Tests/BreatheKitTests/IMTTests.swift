import XCTest
@testable import BreatheKit

final class IMTTests: XCTestCase {
    func testDefaultPlanIsThreeSetsOfFifteen() {
        let plan = SessionPlan.imt()
        XCTAssertEqual(plan.kind, .imt)
        XCTAssertEqual(plan.roundCount, 3)
        // prepare + 3 sets × 15 reps × (inhale + exhale) + 2 rests
        XCTAssertEqual(plan.steps.count, 1 + 3 * 15 * 2 + 2)
        XCTAssertEqual(plan.steps.filter { $0.phase == .resistedInhale }.count, 45)
        XCTAssertEqual(plan.steps.filter { $0.phase == .exhale }.count, 45)
        XCTAssertEqual(plan.steps.filter { $0.phase == .rest }.count, 2)
    }

    func testRepsAlternateInhaleExhaleAndCarryRepNumbers() {
        let plan = SessionPlan.imt()
        let firstSet = plan.steps[1...30]
        for (offset, step) in firstSet.enumerated() {
            XCTAssertEqual(step.phase, offset % 2 == 0 ? .resistedInhale : .exhale)
            XCTAssertEqual(step.rep, offset / 2 + 1)
            XCTAssertEqual(step.repCount, 15)
            XCTAssertEqual(step.round, 1)
            XCTAssertEqual(step.duration, 2)
        }
        XCTAssertEqual(plan.steps[31].phase, .rest)
        XCTAssertEqual(plan.steps[31].duration, 60)
        XCTAssertEqual(plan.steps[32].round, 2)
        XCTAssertEqual(plan.steps.last?.phase, .exhale) // no rest after final set
        XCTAssertEqual(plan.steps.last?.round, 3)
    }

    func testFirstRepOfEachSetAnnouncesTheSet() {
        let plan = SessionPlan.imt()
        let setStarts = plan.steps.filter { $0.phase == .resistedInhale && $0.rep == 1 }
        XCTAssertEqual(setStarts.map(\.voicePrompt), ["Set 1. Inhale", "Set 2. Inhale", "Set 3. Inhale"])
    }

    func testPlannedDuration() {
        let plan = SessionPlan.imt()
        XCTAssertEqual(plan.plannedDuration, 10 + 3 * 15 * 4 + 2 * 60)
    }

    func testClamping() {
        let tiny = SessionPlan.imt(parameters: IMTParameters(sets: 0, reps: 1))
        XCTAssertEqual(tiny.roundCount, 1)
        XCTAssertEqual(tiny.steps.count, 1 + 5 * 2)
        let huge = SessionPlan.imt(parameters: IMTParameters(sets: 99, reps: 999))
        XCTAssertEqual(huge.roundCount, 6)
        XCTAssertEqual(huge.steps.filter { $0.phase == .resistedInhale }.count, 6 * 30)
    }
}
