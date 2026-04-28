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

    // MARK: - Home Screen

    @MainActor
    func testHomeScreenShowsMainElements() throws {
        XCTAssertTrue(app.otherElements["caloriesTile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["proteinTile"].exists)
        XCTAssertTrue(app.otherElements["stepsTile"].exists)
        XCTAssertTrue(app.staticTexts["Diary"].exists)
        XCTAssertTrue(app.otherElements["foodDockButton"].exists)
        XCTAssertTrue(app.otherElements["addEntryButton"].exists)
        XCTAssertTrue(app.otherElements["profileDockButton"].exists)
    }

    @MainActor
    func testModeButtonsExist() throws {
        XCTAssertTrue(app.staticTexts["Cardio"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Gym"].exists)
    }

    @MainActor
    func testToggleCardioMode() throws {
        let cardioButton = app.buttons.containing(.staticText, identifier: "Cardio").firstMatch
        XCTAssertTrue(cardioButton.waitForExistence(timeout: 5))
        cardioButton.tap()
    }

    @MainActor
    func testToggleGymMode() throws {
        let gymButton = app.buttons.containing(.staticText, identifier: "Gym").firstMatch
        XCTAssertTrue(gymButton.waitForExistence(timeout: 5))
        gymButton.tap()
    }

    // MARK: - Add Entry Dialog

    @MainActor
    func testAddEntryDialogShowsOptions() throws {
        let addButton = app.otherElements["addEntryButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        XCTAssertTrue(app.buttons["Camera 📷"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Library 🖼️"].exists)
        XCTAssertTrue(app.buttons["Type Text ✍️"].exists)
        XCTAssertTrue(app.buttons["Training 🏋️‍♂️"].exists)
        XCTAssertTrue(app.buttons["From Fridge ❄️"].exists)
        XCTAssertTrue(app.buttons["From Meals 🍲"].exists)
    }

    @MainActor
    func testAddEntryDialogCanBeDismissed() throws {
        let addButton = app.otherElements["addEntryButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        XCTAssertTrue(app.buttons["Camera 📷"].waitForExistence(timeout: 3))

        let cancelButton = app.buttons["Close"]
        if cancelButton.exists {
            cancelButton.tap()
        } else {
            app.swipeDown()
        }

        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
    }

    // MARK: - Profile Sheet

    @MainActor
    func testOpenAndCloseProfile() throws {
        let profileButton = app.otherElements["profileDockButton"]
        XCTAssertTrue(profileButton.waitForExistence(timeout: 5))
        profileButton.tap()

        let navTitle = app.staticTexts["Profile & Goals"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3))

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists)
        doneButton.tap()

        XCTAssertTrue(app.otherElements["caloriesTile"].waitForExistence(timeout: 3))
    }

    // MARK: - Food Sheet

    @MainActor
    func testOpenAndCloseFood() throws {
        let foodButton = app.otherElements["foodDockButton"]
        XCTAssertTrue(foodButton.waitForExistence(timeout: 5))
        foodButton.tap()

        let fridgeTab = app.staticTexts["Fridge"]
        let mealsTab = app.staticTexts["Meals"]
        XCTAssertTrue(fridgeTab.waitForExistence(timeout: 3) || mealsTab.waitForExistence(timeout: 3))

        app.swipeDown()

        XCTAssertTrue(app.otherElements["caloriesTile"].waitForExistence(timeout: 3))
    }

    // MARK: - Stats / Progress Arena

    @MainActor
    func testOpenAndCloseStats() throws {
        let statsButton = app.otherElements["statsButton"]
        XCTAssertTrue(statsButton.waitForExistence(timeout: 5))
        statsButton.tap()

        let title = app.staticTexts["Progress Arena"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))

        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.exists)
        closeButton.tap()

        XCTAssertTrue(app.otherElements["caloriesTile"].waitForExistence(timeout: 3))
    }

    // MARK: - Goal Breakdown

    @MainActor
    func testTapCaloriesTileOpensBreakdown() throws {
        let caloriesTile = app.otherElements["caloriesTile"]
        XCTAssertTrue(caloriesTile.waitForExistence(timeout: 5))
        caloriesTile.tap()

        let caloriesTitle = app.staticTexts["Calories"]
        XCTAssertTrue(caloriesTitle.waitForExistence(timeout: 3))
    }

    // MARK: - Date Navigation

    @MainActor
    func testDateNavigationBackward() throws {
        XCTAssertTrue(app.otherElements["caloriesTile"].waitForExistence(timeout: 5))

        let leftArrow = app.buttons.matching(identifier: "chevron.left").firstMatch
        if leftArrow.exists {
            leftArrow.tap()
        } else {
            let arrows = app.images["chevron.left"]
            if arrows.exists {
                arrows.tap()
            }
        }
    }

    // MARK: - Sign In Flow

    @MainActor
    func testSignInScreenShowsOnFirstLaunch() throws {
        let freshApp = XCUIApplication()
        freshApp.launchArguments += ["-hasSeenSignIn", "NO", "-hasCompletedOnboarding", "NO"]
        freshApp.launch()

        let signInButton = freshApp.buttons["Sign in with Apple"]
        let continueButton = freshApp.buttons["Continue without account"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5) || continueButton.waitForExistence(timeout: 5))
    }

    @MainActor
    func testContinueWithoutAccount() throws {
        let freshApp = XCUIApplication()
        freshApp.launchArguments += ["-hasSeenSignIn", "NO", "-hasCompletedOnboarding", "YES"]
        freshApp.launch()

        let continueButton = freshApp.buttons["Continue without account"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        XCTAssertTrue(freshApp.otherElements["caloriesTile"].waitForExistence(timeout: 5))
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
