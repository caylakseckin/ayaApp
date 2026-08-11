import XCTest

final class HESIAUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launchArguments += ["-premium.isUnlockedForTesting", "YES"]
        app.launch()
        completeOnboardingIfNeeded(in: app)
        XCTAssertTrue(app.buttons["life_stage.card.cycle"].waitForExistence(timeout: 3))
    }

    func testSettingsPanelAndLanguageAccordionOpen() {
        let app = XCUIApplication()
        app.launchArguments += ["-premium.isUnlockedForTesting", "YES"]
        app.launch()
        completeOnboardingIfNeeded(in: app)

        let pregnancyCard = app.buttons["life_stage.card.pregnancy"]
        XCTAssertTrue(pregnancyCard.waitForExistence(timeout: 3))
        pregnancyCard.tap()

        let settingsButton = app.buttons["settings.button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()

        let languageButton = app.buttons["settings.language.button"]
        XCTAssertTrue(languageButton.waitForExistence(timeout: 2))
        let closeButton = app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "Close", "Kapat")
        ).firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2))
        XCTAssertTrue(closeButton.isHittable, "Close frame: \(closeButton.frame), exists: \(closeButton.exists)")
        languageButton.tap()
        XCTAssertTrue(app.buttons["settings.language.en"].waitForExistence(timeout: 2))
    }

    func testProfileInitialHidesWhileSettingsAreOpenAndNameCanChange() {
        let app = XCUIApplication()
        app.launchArguments += ["-premium.isUnlockedForTesting", "YES"]
        app.launch()
        completeOnboardingIfNeeded(in: app)

        let pregnancyCard = app.buttons["life_stage.card.pregnancy"]
        XCTAssertTrue(pregnancyCard.waitForExistence(timeout: 3))
        pregnancyCard.tap()

        let settingsButton = app.buttons["settings.button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        addScreenshot(named: "Profile initial button")
        settingsButton.tap()
        XCTAssertFalse(settingsButton.exists)
        addScreenshot(named: "Settings panel without profile button")

        let nameField = app.textFields["settings.name.field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        replaceText(in: nameField, with: "Beril")
        nameField.typeKey(XCUIKeyboardKey.return, modifierFlags: [])

        app.buttons["settings.close.button"].tap()
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 2))

        settingsButton.tap()
        XCTAssertEqual(nameField.value as? String, "Beril")
    }

    func testCycleOnboardingCompletesAndSettingsOpenEditMode() {
        let app = XCUIApplication()
        app.launchArguments += ["-premium.isUnlockedForTesting", "YES"]
        app.launch()
        completeOnboardingIfNeeded(in: app)

        let cycleCard = app.buttons["life_stage.card.cycle"]
        XCTAssertTrue(cycleCard.waitForExistence(timeout: 3))
        cycleCard.tap()

        let dateInput = app.buttons["cycle.onboarding.date.input"]
        if dateInput.waitForExistence(timeout: 2) {
            dateInput.tap()
            let confirmDate = app.buttons["cycle.onboarding.date_picker.confirm"]
            XCTAssertTrue(confirmDate.waitForExistence(timeout: 3))
            confirmDate.tap()

            let primaryAction = app.buttons["cycle.onboarding.primary_action"]
            primaryAction.tap()

            let cycleLength = app.textFields["cycle.onboarding.cycle_length.input"]
            XCTAssertTrue(cycleLength.waitForExistence(timeout: 2))
            cycleLength.tap()
            cycleLength.typeText("28")
            primaryAction.tap()

            let periodDuration = app.textFields["cycle.onboarding.period_duration.input"]
            XCTAssertTrue(periodDuration.waitForExistence(timeout: 2))
            periodDuration.tap()
            periodDuration.typeText("5")
            primaryAction.tap()
        }

        let settingsButton = app.buttons["settings.button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()

        let cycleSettings = app.buttons["settings.cycle.button"]
        XCTAssertTrue(cycleSettings.waitForExistence(timeout: 2))
        cycleSettings.tap()

        XCTAssertTrue(dateInput.waitForExistence(timeout: 3))
    }

    private func completeOnboardingIfNeeded(in app: XCUIApplication) {
        let nameField = app.textFields["welcome.name.field"]
        if nameField.waitForExistence(timeout: 1) {
            nameField.tap()
            nameField.typeText("Ada")
            app.buttons["welcome.continue.button"].tap()
        }

        let tutorialAction = app.buttons["onboarding.tutorial.primary.button"]
        if tutorialAction.waitForExistence(timeout: 1) {
            for _ in 0..<6 {
                guard tutorialAction.waitForExistence(timeout: 1) else { break }
                tutorialAction.tap()
            }
        }

        let skipFaceID = app.buttons["biometric.onboarding.skip.button"]
        if skipFaceID.waitForExistence(timeout: 1) {
            skipFaceID.tap()
        }

        guard !app.buttons["life_stage.card.cycle"].waitForExistence(timeout: 1) else {
            return
        }

        let settingsButton = app.buttons["settings.button"]
        guard settingsButton.waitForExistence(timeout: 2) else { return }
        settingsButton.tap()

        let themesButton = app.buttons["settings.themes.button"]
        guard themesButton.waitForExistence(timeout: 2) else { return }
        themesButton.tap()
        _ = app.buttons["life_stage.card.cycle"].waitForExistence(timeout: 2)
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        if let currentValue = field.value as? String, !currentValue.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }
        field.typeText(text)
    }

    private func addScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
