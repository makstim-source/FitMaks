import XCTest

final class FitMaksUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-hasSeenSignIn", "YES", "-hasCompletedOnboarding", "YES"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helpers

    private func waitForHomeScreen() -> Bool {
        app.staticTexts["Diary"].waitForExistence(timeout: 8)
    }

    // MARK: - Home Screen

    @MainActor
    func testHomeScreenShowsMainElements() throws {
        XCTAssertTrue(waitForHomeScreen())
        XCTAssertTrue(app.staticTexts["CALORIES"].exists)
        XCTAssertTrue(app.staticTexts["PROTEIN"].exists)
        XCTAssertTrue(app.staticTexts["STEPS"].exists)
    }

    @MainActor
    func testDockButtonsExist() throws {
        XCTAssertTrue(waitForHomeScreen())
        XCTAssertTrue(app.buttons["dock_Food"].exists)
        XCTAssertTrue(app.buttons["dock_Profile"].exists)
        XCTAssertTrue(app.buttons["addEntryButton"].exists)
    }

    @MainActor
    func testModeButtonsExist() throws {
        XCTAssertTrue(waitForHomeScreen())
        XCTAssertTrue(app.staticTexts["Cardio"].exists || app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cardio'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Gym"].exists || app.buttons.matching(NSPredicate(format: "label CONTAINS 'Gym'")).firstMatch.exists)
    }

    // MARK: - Add Entry Dialog

    @MainActor
    func testAddEntryDialogShowsOptions() throws {
        XCTAssertTrue(waitForHomeScreen())
        app.buttons["addEntryButton"].tap()

        let cameraButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Camera'")).firstMatch
        XCTAssertTrue(cameraButton.waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Library'")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Type Text'")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Training'")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Fridge'")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Meals'")).firstMatch.exists)
    }

    // MARK: - Profile Sheet

    @MainActor
    func testOpenAndCloseProfile() throws {
        XCTAssertTrue(waitForHomeScreen())
        app.buttons["dock_Profile"].tap()

        XCTAssertTrue(app.navigationBars["Profile & Goals"].waitForExistence(timeout: 5))

        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["Diary"].waitForExistence(timeout: 5))
    }

    // MARK: - Food Sheet

    @MainActor
    func testOpenFood() throws {
        XCTAssertTrue(waitForHomeScreen())
        app.buttons["dock_Food"].tap()

        let appeared = app.staticTexts["Fridge"].waitForExistence(timeout: 5)
            || app.staticTexts["Meals"].waitForExistence(timeout: 5)
        XCTAssertTrue(appeared)
    }

    // MARK: - Stats / Progress Arena

    @MainActor
    func testOpenAndCloseStats() throws {
        XCTAssertTrue(waitForHomeScreen())
        app.buttons["statsButton"].tap()

        XCTAssertTrue(app.staticTexts["Progress Arena"].waitForExistence(timeout: 5))

        app.buttons["Close"].tap()

        XCTAssertTrue(app.staticTexts["Diary"].waitForExistence(timeout: 5))
    }

    // MARK: - Sign In Flow

    @MainActor
    func testSignInScreenShowsOnFirstLaunch() throws {
        let freshApp = XCUIApplication()
        freshApp.launchArguments += ["-hasSeenSignIn", "NO", "-hasCompletedOnboarding", "NO"]
        freshApp.launch()

        let found = freshApp.buttons["Sign in with Apple"].waitForExistence(timeout: 8)
            || freshApp.buttons["Continue without account"].waitForExistence(timeout: 8)
        XCTAssertTrue(found)
    }

    @MainActor
    func testSignInScreenHasContinueButton() throws {
        let freshApp = XCUIApplication()
        freshApp.launchArguments += ["-hasSeenSignIn", "NO", "-hasCompletedOnboarding", "NO"]
        freshApp.launch()

        let continueButton = freshApp.buttons["Continue without account"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertTrue(continueButton.isHittable)
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                let perf = XCUIApplication()
                perf.launchArguments += ["-hasSeenSignIn", "YES", "-hasCompletedOnboarding", "YES"]
                perf.launch()
            }
        }
    }
}
