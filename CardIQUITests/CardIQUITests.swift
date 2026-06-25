import XCTest

final class CardIQUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp(resetOnboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        if resetOnboarding {
            app.launchArguments.append("-hasCompletedOnboarding")
            app.launchArguments.append("0")
        }
        app.launch()
        return app
    }

    @MainActor
    func testOnboardingFlow() throws {
        let app = launchApp(resetOnboarding: true)

        if app.staticTexts["Welcome to CardIQ"].waitForExistence(timeout: 3) {
            app.buttons["Continue"].tap()

            if app.staticTexts["Scan & Identify"].waitForExistence(timeout: 2) {
                app.buttons["Continue"].tap()
            }

            if app.staticTexts["Estimate Condition"].waitForExistence(timeout: 2) {
                app.buttons["Continue"].tap()
            }

            if app.staticTexts["Know Before You Grade"].waitForExistence(timeout: 2) {
                app.buttons["Continue"].tap()
            }

            if app.staticTexts["Track Your Collection"].waitForExistence(timeout: 2) {
                app.buttons["Continue"].tap()
            }

            if app.staticTexts["What kind of collector are you?"].waitForExistence(timeout: 2) {
                app.buttons["Casual Collector. I collect cards I love and want to protect my favorites."].firstMatch.tap()
                app.buttons["Continue"].tap()
            }

            if app.staticTexts["Create Your Account"].waitForExistence(timeout: 2) {
                app.buttons["Get Started"].tap()
            }

            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
        }
    }

    @MainActor
    func testTabNavigation() throws {
        let app = launchApp()

        if app.tabBars.firstMatch.waitForExistence(timeout: 5) {
            app.tabBars.buttons["Collection"].tap()
            XCTAssertTrue(app.navigationBars["Collection"].waitForExistence(timeout: 2))

            app.tabBars.buttons["Market"].tap()
            XCTAssertTrue(app.navigationBars["Market"].waitForExistence(timeout: 2))

            app.tabBars.buttons["Profile"].tap()
            XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 2))

            app.tabBars.buttons["Home"].tap()
            XCTAssertTrue(app.navigationBars["CardIQ"].waitForExistence(timeout: 2))
        }
    }

    @MainActor
    func testScannerLaunch() throws {
        let app = launchApp()

        if app.tabBars.firstMatch.waitForExistence(timeout: 5) {
            if app.buttons["Scan a Card"].exists {
                app.buttons["Scan a Card"].tap()
            } else {
                app.tabBars.buttons["Scan"].tap()
                if app.buttons["Start Scan"].waitForExistence(timeout: 2) {
                    app.buttons["Start Scan"].tap()
                }
            }

            XCTAssertTrue(
                app.staticTexts["Scan Your Card"].waitForExistence(timeout: 3) ||
                app.staticTexts["Get Ready"].waitForExistence(timeout: 3)
            )
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
