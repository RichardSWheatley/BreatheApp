import XCTest
@testable import BreatheKit

final class PacerTests: XCTestCase {
    func testInhaleFillsAndExhaleEmpties() {
        XCTAssertEqual(Pacer.fullness(phase: .inhale, progress: 0, elapsed: 0), 0)
        XCTAssertEqual(Pacer.fullness(phase: .inhale, progress: 0.5, elapsed: 2), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Pacer.fullness(phase: .inhale, progress: 1, elapsed: 4), 1)
        XCTAssertEqual(Pacer.fullness(phase: .exhale, progress: 0, elapsed: 0), 1)
        XCTAssertEqual(Pacer.fullness(phase: .exhale, progress: 1, elapsed: 4), 0)
        XCTAssertEqual(Pacer.fullness(phase: .resistedInhale, progress: 1, elapsed: 2), 1)
    }

    func testHoldsAreFlat() {
        for p in [0.0, 0.3, 1.0] {
            XCTAssertEqual(Pacer.fullness(phase: .holdFull, progress: p, elapsed: 1), 1)
            XCTAssertEqual(Pacer.fullness(phase: .holdEmpty, progress: p, elapsed: 1), 0)
            XCTAssertEqual(Pacer.fullness(phase: .walkHold, progress: p, elapsed: 1), 0)
        }
    }

    func testCountAloudEmptiesOverTime() {
        XCTAssertEqual(Pacer.fullness(phase: .countAloud, progress: nil, elapsed: 0), 1)
        XCTAssertEqual(Pacer.fullness(phase: .countAloud, progress: nil, elapsed: 30), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Pacer.fullness(phase: .countAloud, progress: nil, elapsed: 90), 0)
    }

    func testFreeBreathingOscillatesWithinBand() {
        XCTAssertEqual(Pacer.freeBreathing(elapsed: 0), 0.25, accuracy: 1e-9)
        XCTAssertEqual(Pacer.freeBreathing(elapsed: 4), 0.75, accuracy: 1e-9)
        XCTAssertEqual(Pacer.freeBreathing(elapsed: 8), 0.25, accuracy: 1e-9)
        for t in stride(from: 0.0, through: 30, by: 0.1) {
            let value = Pacer.freeBreathing(elapsed: t)
            XCTAssertGreaterThanOrEqual(value, 0.25 - 1e-9)
            XCTAssertLessThanOrEqual(value, 0.75 + 1e-9)
            XCTAssertEqual(Pacer.fullness(phase: .recover, progress: 0.5, elapsed: t), value)
        }
        XCTAssertEqual(Pacer.freeBreathing(elapsed: 3, period: 0), 0.5)
    }

    func testEasingIsMonotonicWithFixedEndpoints() {
        XCTAssertEqual(Pacer.eased(0), 0)
        XCTAssertEqual(Pacer.eased(0.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Pacer.eased(1), 1)
        XCTAssertEqual(Pacer.eased(-1), 0)
        XCTAssertEqual(Pacer.eased(2), 1)
        var previous = 0.0
        for t in stride(from: 0.0, through: 1, by: 0.01) {
            let value = Pacer.eased(t)
            XCTAssertGreaterThanOrEqual(value, previous - 1e-12)
            previous = value
        }
    }

    func testScaleNeverCollapses() {
        XCTAssertEqual(Pacer.scale(fullness: 0), 0.45)
        XCTAssertEqual(Pacer.scale(fullness: 1), 1)
        XCTAssertEqual(Pacer.scale(fullness: 0.5), 0.725, accuracy: 1e-9)
        XCTAssertEqual(Pacer.scale(fullness: -5), 0.45)
        XCTAssertEqual(Pacer.scale(fullness: 9), 1)
    }
}
