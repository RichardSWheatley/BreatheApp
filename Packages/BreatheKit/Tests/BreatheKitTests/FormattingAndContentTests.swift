import XCTest
@testable import BreatheKit

final class FormattingAndContentTests: XCTestCase {
    func testClockFormatting() {
        XCTAssertEqual(TimeFormatting.clock(0), "0:00")
        XCTAssertEqual(TimeFormatting.clock(65), "1:05")
        XCTAssertEqual(TimeFormatting.clock(7.2), "0:08")
        XCTAssertEqual(TimeFormatting.clock(600), "10:00")
        XCTAssertEqual(TimeFormatting.clock(-3), "0:00")
    }

    func testSpokenAndCompactFormatting() {
        XCTAssertEqual(TimeFormatting.spoken(45), "45 s")
        XCTAssertEqual(TimeFormatting.spoken(120), "2 min")
        XCTAssertEqual(TimeFormatting.spoken(135), "2 min 15 s")
        XCTAssertEqual(TimeFormatting.spoken(0), "0 s")
        XCTAssertEqual(TimeFormatting.compact(44.6), "45s")
    }

    func testEducationContentIsComplete() {
        XCTAssertEqual(Education.mechanisms.map(\.id), ["metaboreflex", "co2", "iht"])
        XCTAssertGreaterThanOrEqual(Education.safetyRules.count, 5)
        XCTAssertGreaterThanOrEqual(Education.tips.count, 14)
        for kind in SessionKind.allCases {
            let guide = Education.guide(for: kind)
            XCTAssertFalse(guide.paragraphs.isEmpty, "\(kind)")
            XCTAssertEqual(guide.symbolName, kind.symbolName)
        }
    }

    func testTipOfTheDayIsStable() {
        let calendar = Calendar(identifier: .gregorian)
        let morning = Date(timeIntervalSince1970: 1_800_000_000)
        let evening = morning.addingTimeInterval(8 * 3600)
        XCTAssertEqual(Education.tip(for: morning, calendar: calendar), Education.tip(for: evening, calendar: calendar))
        XCTAssertTrue(Education.tips.contains(Education.tip(for: morning, calendar: calendar)))
        let tomorrow = morning.addingTimeInterval(86_400)
        XCTAssertNotEqual(Education.tip(for: morning, calendar: calendar), Education.tip(for: tomorrow, calendar: calendar))
    }

    func testKindMetadata() {
        XCTAssertEqual(SessionKind.trainingProtocols.count, 5)
        XCTAssertEqual(SessionKind.assessments.count, 3)
        XCTAssertEqual(Set(SessionKind.trainingProtocols + SessionKind.assessments), Set(SessionKind.allCases))
        for kind in SessionKind.allCases {
            XCTAssertFalse(kind.title.isEmpty)
            XCTAssertFalse(kind.goal.isEmpty)
            XCTAssertEqual(kind.id, kind.rawValue)
        }
    }
}
