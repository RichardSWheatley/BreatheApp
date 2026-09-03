import XCTest
@testable import BreatheKit

final class HypoxicSprintTests: XCTestCase {
    func testWalkDurationIsThirtyPercentOfMaxHoldWithinBounds() {
        XCTAssertEqual(HypoxicSprints.walkDuration(maxHold: 90), 27)
        XCTAssertEqual(HypoxicSprints.walkDuration(maxHold: 20), 10)   // 6 s → floor 10
        XCTAssertEqual(HypoxicSprints.walkDuration(maxHold: 300), 45)  // 90 s → ceiling 45
    }

    func testPacesDerivedFromWalkDuration() {
        XCTAssertEqual(HypoxicSprints.paces(maxHold: 90), 45)   // 27 s × 100/60
        XCTAssertEqual(HypoxicSprints.paces(maxHold: 20), 17)   // 10 s × 1.667 = 16.7
        XCTAssertEqual(HypoxicSprints.paces(maxHold: 300), 75)  // 45 s × 1.667
        XCTAssertGreaterThanOrEqual(HypoxicSprints.paces(maxHold: 1), 1)
    }

    func testRepsAreClampedToPRDRange() {
        XCTAssertEqual(SessionPlan.hypoxicSprints(maxHold: 90, parameters: HypoxicSprintParameters(reps: 3)).roundCount, 5)
        XCTAssertEqual(SessionPlan.hypoxicSprints(maxHold: 90, parameters: HypoxicSprintParameters(reps: 20)).roundCount, 10)
        XCTAssertEqual(SessionPlan.hypoxicSprints(maxHold: 90).roundCount, 6)
    }

    func testPlanStructure() {
        let plan = SessionPlan.hypoxicSprints(maxHold: 90)
        XCTAssertEqual(plan.kind, .hypoxicSprints)
        XCTAssertEqual(plan.steps.count, 1 + 6 * 2)
        XCTAssertEqual(plan.steps[0].phase, .prepare)
        XCTAssertEqual(plan.steps[0].duration, 15)

        let walk = plan.steps[1]
        XCTAssertEqual(walk.phase, .walkHold)
        XCTAssertEqual(walk.duration, 27)
        XCTAssertEqual(walk.paces, 45)
        XCTAssertTrue(walk.instruction.contains("45 paces"))
        XCTAssertTrue(walk.instruction.lowercased().contains("pinch your nose"))

        let recover = plan.steps[2]
        XCTAssertEqual(recover.phase, .recover)
        XCTAssertEqual(recover.duration, 60)
        XCTAssertEqual(plan.holdSteps.count, 6)
        XCTAssertEqual(plan.plannedDuration, 15 + 6 * (27 + 60))
    }
}
