import XCTest
@testable import BreatheKit

final class ApneaTableTests: XCTestCase {
    // PRD §5 worked example: max hold 90 s, 6 cycles.
    func testCO2RowsMatchPRDExample() {
        let rows = ApneaTables.co2Rows(maxHold: 90)
        XCTAssertEqual(rows.map(\.cycle), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(rows.map(\.holdTime), Array(repeating: 45, count: 6))
        XCTAssertEqual(rows.map(\.breatheTime), [120, 105, 90, 75, 60, 45])
    }

    func testCO2RestNeverDropsBelowFloor() {
        let rows = ApneaTables.co2Rows(maxHold: 90, parameters: CO2TableParameters(rounds: 12))
        XCTAssertEqual(rows.map(\.breatheTime), [120, 105, 90, 75, 60, 45, 30, 15, 15, 15, 15, 15])
        XCTAssertTrue(rows.allSatisfy { $0.breatheTime >= 15 })
    }

    func testCO2HoldIsRoundedToWholeSeconds() {
        let rows = ApneaTables.co2Rows(maxHold: 73)
        XCTAssertEqual(rows.first?.holdTime, 37) // 36.5 rounds to 37 (schoolbook)
        XCTAssertEqual(rows.first?.holdTime.truncatingRemainder(dividingBy: 1), 0)
    }

    func testMaxHoldIsClampedToSafeRange() {
        XCTAssertEqual(ApneaTables.co2Rows(maxHold: 2).first?.holdTime, 5)      // floor 10 s → 5 s hold
        XCTAssertEqual(ApneaTables.co2Rows(maxHold: 5000).first?.holdTime, 300) // ceiling 600 s → 300 s hold
    }

    func testRoundsAreClamped() {
        XCTAssertEqual(ApneaTables.co2Rows(maxHold: 90, parameters: CO2TableParameters(rounds: 0)).count, 1)
        XCTAssertEqual(ApneaTables.co2Rows(maxHold: 90, parameters: CO2TableParameters(rounds: 99)).count, 12)
        XCTAssertEqual(ApneaTables.o2Rows(maxHold: 90, parameters: O2TableParameters(rounds: -3)).count, 1)
    }

    func testO2RowsKeepRestConstantAndGrowHoldLinearly() {
        let rows = ApneaTables.o2Rows(maxHold: 90)
        XCTAssertEqual(rows.map(\.breatheTime), Array(repeating: 120, count: 6))
        XCTAssertEqual(rows.first?.holdTime, 36) // 40%
        XCTAssertEqual(rows.last?.holdTime, 72)  // 80%
        XCTAssertEqual(rows.map(\.holdTime), [36, 43, 50, 58, 65, 72])
        let holds = rows.map(\.holdTime)
        XCTAssertEqual(holds, holds.sorted())
        XCTAssertTrue(zip(holds, holds.dropFirst()).allSatisfy { $1 > $0 })
    }

    func testO2SingleRoundUsesTopOfRange() {
        let rows = ApneaTables.o2Rows(maxHold: 100, parameters: O2TableParameters(rounds: 1))
        XCTAssertEqual(rows.map(\.holdTime), [80])
    }

    func testRowsForKind() {
        XCTAssertEqual(ApneaTables.rows(for: .co2Table, maxHold: 90)?.count, 6)
        XCTAssertEqual(ApneaTables.rows(for: .o2Table, maxHold: 90)?.count, 6)
        XCTAssertNil(ApneaTables.rows(for: .cadence, maxHold: 90))
        XCTAssertNil(ApneaTables.rows(for: .boltAssessment, maxHold: 90))
    }

    func testCO2PlanStructure() {
        let plan = SessionPlan.co2Table(maxHold: 90)
        XCTAssertEqual(plan.kind, .co2Table)
        XCTAssertEqual(plan.roundCount, 6)
        XCTAssertEqual(plan.steps.count, 1 + 6 * 2)
        XCTAssertEqual(plan.steps.first?.phase, .prepare)
        XCTAssertEqual(plan.steps.first?.duration, 10)
        XCTAssertEqual(plan.steps.map(\.id), Array(0..<13))

        let working = Array(plan.steps.dropFirst())
        for (offset, step) in working.enumerated() {
            let expectedRound = offset / 2 + 1
            XCTAssertEqual(step.round, expectedRound)
            XCTAssertEqual(step.roundCount, 6)
            XCTAssertEqual(step.phase, offset % 2 == 0 ? .recover : .holdFull)
        }
        XCTAssertEqual(plan.holdSteps.map(\.duration), Array(repeating: 45, count: 6))
        let expectedRest: TimeInterval = 120 + 105 + 90 + 75 + 60 + 45
        let expectedHolds: TimeInterval = 6 * 45
        XCTAssertEqual(plan.plannedDuration, 10 + expectedHolds + expectedRest)
        XCTAssertFalse(plan.isOpenEnded)
        XCTAssertNil(plan.measuredStep)
    }

    func testO2PlanStructure() {
        let plan = SessionPlan.o2Table(maxHold: 90)
        XCTAssertEqual(plan.kind, .o2Table)
        XCTAssertEqual(plan.steps.count, 13)
        XCTAssertEqual(plan.holdSteps.compactMap(\.duration), [36, 43, 50, 58, 65, 72])
        let expectedHolds: TimeInterval = 36 + 43 + 50 + 58 + 65 + 72
        let expectedRest: TimeInterval = 6 * 120
        XCTAssertEqual(plan.plannedDuration, 10 + expectedRest + expectedHolds)
    }

    func testPlansRoundTripThroughCodable() throws {
        let plan = SessionPlan.co2Table(maxHold: 90)
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(SessionPlan.self, from: data)
        XCTAssertEqual(decoded, plan)
    }
}
