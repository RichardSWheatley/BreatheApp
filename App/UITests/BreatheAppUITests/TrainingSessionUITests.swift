import XCTest

final class TrainingSessionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(timeScale: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-skipOnboarding", "-seedBaselines", "-timeScale", "\(timeScale)"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// A full CO2 table (12:55 of training) runs to completion at 120x and
    /// shows up in Progress afterwards.
    func testCO2TableRunsToCompletion() throws {
        let app = launch(timeScale: 120)
        app.tabBars.buttons["Train"].tap()
        let card = element(app, "library.card.co2Table")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let start = app.buttons["library.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        XCTAssertTrue(app.staticTexts["session.phase"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["session.round"].waitForExistence(timeout: 10))

        let title = app.staticTexts["session.summary.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 90))
        XCTAssertEqual(title.label, "Session complete")
        app.buttons["session.summary.done"].tap()

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["CO2 Table"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Completed"].exists)
    }

    /// Pausing, skipping and ending early all work from the player controls.
    func testPlayerControls() throws {
        let app = launch(timeScale: 1)
        app.buttons["home.startRecommended"].tap()

        let phase = app.staticTexts["session.phase"]
        XCTAssertTrue(phase.waitForExistence(timeout: 5))
        XCTAssertEqual(phase.label, "Get Ready")

        app.buttons["session.mark"].tap() // skip the prepare step
        let skipped = NSPredicate(format: "label != 'Get Ready'")
        expectation(for: skipped, evaluatedWith: phase)
        waitForExpectations(timeout: 5)

        let pause = app.buttons["session.pause"]
        pause.tap()
        XCTAssertTrue(pause.label.contains("Resume"))
        pause.tap()
        XCTAssertTrue(pause.label.contains("Pause"))

        app.buttons["session.end"].tap()
        let confirm = app.buttons["session.confirmEnd"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        let title = app.staticTexts["session.summary.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Session ended")
        app.buttons["session.summary.done"].tap()
        XCTAssertTrue(app.buttons["home.startRecommended"].waitForExistence(timeout: 5))
    }
}
