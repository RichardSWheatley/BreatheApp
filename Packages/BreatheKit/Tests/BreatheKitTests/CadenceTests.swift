import XCTest
@testable import BreatheKit

final class CadenceTests: XCTestCase {
    func testHoldScalesWithBOLT() {
        let cases: [(TimeInterval?, TimeInterval)] = [
            (nil, 6), (10, 6), (25, 6), (27, 6), (28, 7), (31, 8), (34, 9), (40, 11), (52, 15), (100, 15),
        ]
        for (bolt, expected) in cases {
            XCTAssertEqual(Progression.cadenceHold(bolt: bolt), expected, "BOLT \(String(describing: bolt))")
        }
    }

    func testPlanFollowsFourSixFourSixRatio() {
        let plan = SessionPlan.cadence(bolt: 25)
        XCTAssertEqual(plan.kind, .cadence)
        XCTAssertEqual(plan.roundCount, 10)
        XCTAssertEqual(plan.steps.count, 1 + 10 * 4)
        XCTAssertEqual(plan.steps[0].phase, .prepare)

        let round = Array(plan.steps[1...4])
        XCTAssertEqual(round.map(\.phase), [.inhale, .holdFull, .exhale, .holdEmpty])
        XCTAssertEqual(round.map(\.duration), [4, 6, 4, 6])
        XCTAssertEqual(round.map(\.round), [1, 1, 1, 1])
        XCTAssertEqual(plan.steps.last?.round, 10)
        XCTAssertEqual(plan.plannedDuration, 10 + 10 * 20)
    }

    func testHoldsGrowForEliteBOLT() {
        let plan = SessionPlan.cadence(bolt: 40)
        XCTAssertEqual(plan.steps[2].duration, 11)
        XCTAssertEqual(plan.steps[4].duration, 11)
        XCTAssertEqual(plan.steps[1].duration, 4)
    }

    func testHoldOverrideWins() {
        let plan = SessionPlan.cadence(bolt: 40, parameters: CadenceParameters(holdOverride: 8))
        XCTAssertEqual(plan.steps[2].duration, 8)
    }

    func testRoundsAreClamped() {
        XCTAssertEqual(SessionPlan.cadence(bolt: nil, parameters: CadenceParameters(rounds: 0)).roundCount, 1)
        XCTAssertEqual(SessionPlan.cadence(bolt: nil, parameters: CadenceParameters(rounds: 500)).roundCount, 40)
    }
}
