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

        XCTAssertTrue(app.buttons["Get started"].waitForExistence(timeout: 10))
        app.buttons["Get started"].tap()

        // The Permissions screen comes next. "Not now" skips it without a system prompt.
        XCTAssertTrue(app.buttons["Not now"].waitForExistence(timeout: 10))
        app.buttons["Not now"].tap()

        // Tab buttons can sit inside or outside the tab bar depending on the iOS version.
        for name in ["Home", "Garage", "History", "Ask"] {
            XCTAssertTrue(
                app.buttons[name].firstMatch.waitForExistence(timeout: 10),
                "\(name) tab not found"
            )
        }
    }
}
