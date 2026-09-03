import XCTest

// XCUIApplication and friends are main-actor-isolated in the iOS 18 SDK;
// the whole test class runs on the main actor so every query and tap is legal
// under strict concurrency.
@MainActor
final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Full first-run flow: welcome → three science pages → safety → the
    /// three baseline assessments (each run in the real session player at
    /// 20x speed) → finish → main tabs.
    func testOnboardingRunsAllThreeAssessments() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-timeScale", "20"]
        app.launch()

        app.buttons["onboarding.getStarted"].tap()
        for _ in 0..<3 {
            let next = app.buttons["onboarding.next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }

        let acknowledge = app.switches["onboarding.safety.acknowledge"]
        XCTAssertTrue(acknowledge.waitForExistence(timeout: 5))
        acknowledge.tap()
        let safetyContinue = app.buttons["onboarding.safety.continue"]
        XCTAssertTrue(safetyContinue.isEnabled)
        safetyContinue.tap()

        for index in 0..<3 {
            let start = app.buttons["onboarding.assessment.start"]
            XCTAssertTrue(start.waitForExistence(timeout: 5), "assessment \(index) start")
            start.tap()

            let mark = app.buttons["session.mark"]
            XCTAssertTrue(mark.waitForExistence(timeout: 10))
            let holdBegan = NSPredicate(format: "label CONTAINS[c] 'Stop'")
            expectation(for: holdBegan, evaluatedWith: mark)
            waitForExpectations(timeout: 20)
            Thread.sleep(forTimeInterval: 1)
            mark.tap()

            let done = app.buttons["session.summary.done"]
            XCTAssertTrue(done.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["session.result.value"].exists)
            if index == 2 {
                let field = app.textFields["onboarding.result.breathCount"]
                XCTAssertTrue(field.exists)
                field.tap()
                field.typeText("35")
            }
            done.tap()

            let resultContinue = app.buttons["onboarding.result.continue"]
            XCTAssertTrue(resultContinue.waitForExistence(timeout: 5), "assessment \(index) result")
            resultContinue.tap()
        }

        let finish = app.buttons["onboarding.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.startRecommended"].exists)
    }
}
