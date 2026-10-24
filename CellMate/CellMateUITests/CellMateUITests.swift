import XCTest

final class CellMateUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWelcomeThenFourTabs() throws {
        let app = XCUIApplication()
        app.launch()

        // On a fresh install the Welcome and Permissions screens come first.
        // If an earlier run already finished them, the tabs are shown straight away.
        let getStarted = app.buttons["Get started"]
        if getStarted.waitForExistence(timeout: 5) {
            getStarted.tap()

            // "Not now" skips the Permissions screen without a system prompt.
            XCTAssertTrue(app.buttons["Not now"].waitForExistence(timeout: 10))
            app.buttons["Not now"].tap()
        }

        // Tab buttons can sit inside or outside the tab bar depending on the iOS version.
        for name in ["Home", "Garage", "History", "Ask"] {
            XCTAssertTrue(
                app.buttons[name].firstMatch.waitForExistence(timeout: 10),
                "\(name) tab not found"
            )
        }
    }
}
