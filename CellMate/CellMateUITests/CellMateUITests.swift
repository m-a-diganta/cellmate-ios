import XCTest

final class CellMateUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWelcomeThenFourTabs() throws {
        let app = XCUIApplication()
        // Forces the Welcome screen even if an earlier run finished onboarding.
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        app.launch()

        app.buttons["Get started"].tap()
        // The Permissions screen comes next. "Not now" skips it without a system prompt.
        app.buttons["Not now"].tap()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Garage"].exists)
        XCTAssertTrue(app.tabBars.buttons["History"].exists)
        XCTAssertTrue(app.tabBars.buttons["Ask"].exists)
    }
}
