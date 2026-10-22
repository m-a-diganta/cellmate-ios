import XCTest

final class AskCellMateUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testQuickCheckEmergencyDoesNotNeedAI() {
        let app = openAsk()
        app.buttons["ask.quickCheck"].tap()
        XCTAssertTrue(app.switches["check.smokeOrFlames"].waitForExistence(timeout: 5))
        enableSmokeSwitch(app)
        app.buttons["check.finish"].tap()
        XCTAssertTrue(app.staticTexts["Emergency"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Call Triple Zero (000) from a safe place."].exists)
        attach(app, name: "Ask emergency")
    }

    @MainActor
    func testDarkModeSymptomAndUnsavedRecord() {
        let app = openAsk(dark: true)
        attach(app, name: "Ask dark")
        app.buttons["Swollen or bulging"].tap()
        app.buttons["ask.submit"].tap()
        XCTAssertTrue(app.staticTexts["Stop using"].waitForExistence(timeout: 5))
        app.swipeUp()
        app.buttons["ask.log"].tap()
        XCTAssertTrue(app.alerts["Ask CellMate"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "has not been saved")).firstMatch.exists)
        attach(app, name: "No false save confirmation")
    }

    @MainActor
    func testQuickCheckAtAccessibilityTextSize() {
        let app = openAsk(largeText: true)
        for _ in 0..<6 where !app.buttons["ask.quickCheck"].isHittable { app.swipeUp() }
        app.buttons["ask.quickCheck"].tap()
        XCTAssertTrue(app.navigationBars["Quick check"].waitForExistence(timeout: 5))
        for _ in 0..<6 where !app.switches["check.smokeOrFlames"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.switches["check.smokeOrFlames"].exists)
        enableSmokeSwitch(app)
        app.buttons["check.finish"].tap()
        XCTAssertTrue(app.staticTexts["Emergency"].waitForExistence(timeout: 5))
        attach(app, name: "Ask accessibility text")
    }

    @MainActor
    private func openAsk(dark: Bool = false, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES",
            "-UIPreferredContentSizeCategoryName", largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        if dark { app.launchArguments.append("--ask-ui-dark") }
        app.launch()
        app.tabBars.buttons["Ask"].tap()
        XCTAssertTrue(app.navigationBars["Ask CellMate"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func enableSmokeSwitch(_ app: XCUIApplication) {
        let control = app.switches["check.smokeOrFlames"]
        // SwiftUI exposes the whole labelled row as a Switch; tap its trailing control.
        control.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let enabled = NSPredicate(format: "value == %@", "1")
        expectation(for: enabled, evaluatedWith: control)
        waitForExpectations(timeout: 5)
    }
}
