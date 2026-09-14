import XCTest

final class HESIAUITests: XCTestCase {
    func testThemeCarouselSwipesToNextFullScreenThemeAndSelectsIt() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboarding.completed", "YES",
            "-life_stage.active", "invalid",
            "-life_stage.selection.hasShownSwipeNudge", "YES",
            "-premium.isUnlockedForTesting", "YES",
            "-app.language", "tr",
            "-pregnancy.onboardingCompleted", "NO"
        ]
        app.launch()

        let cycleCard = app.buttons["life_stage.card.cycle"]
        XCTAssertTrue(cycleCard.waitForExistence(timeout: 5))
        let swipeStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.58))
        let swipeEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.58))
        swipeStart.press(forDuration: 0.05, thenDragTo: swipeEnd)

        let pregnancyCard = app.buttons["life_stage.card.pregnancy"]
        XCTAssertTrue(pregnancyCard.waitForExistence(timeout: 3))
        XCTAssertTrue(pregnancyCard.isSelected)
        let pageIndicator = app.descendants(matching: .any)["life_stage.page_indicator"]
        XCTAssertTrue(pageIndicator.waitForExistence(timeout: 2))
        XCTAssertEqual(pageIndicator.value as? String, "2 / 4")
    }

    func testPregnancyMeditationBrowsingIsTemporary() {
        verifyTemporaryMeditationBrowsing(
            stage: "pregnancy",
            profileArguments: [
                "-pregnancy.referenceWeek", "18",
                "-pregnancy.referenceDate", String(Date().timeIntervalSince1970),
                "-pregnancy.onboardingCompleted", "YES"
            ],
            currentLabel: "18. hafta",
            alternateLabel: "20. hafta"
        )
    }

    func testPostpartumMeditationBrowsingIsTemporary() {
        verifyTemporaryMeditationBrowsing(
            stage: "postpartum",
            profileArguments: [
                "-postpartum.birthDate", String(Date().timeIntervalSince1970),
                "-postpartum.onboardingCompleted", "YES"
            ],
            currentLabel: "1. gün",
            alternateLabel: "7. gün"
        )
    }

    private func verifyTemporaryMeditationBrowsing(
        stage: String,
        profileArguments: [String],
        currentLabel: String,
        alternateLabel: String
    ) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-onboarding.completed", "YES",
            "-life_stage.active", stage,
            "-premium.isUnlockedForTesting", "YES",
            "-app.language", "tr"
        ] + profileArguments
        app.launch()
        let browse = app.buttons["meditation.browse.open"]
        XCTAssertTrue(browse.waitForExistence(timeout: 5))
        if !browse.isHittable { app.swipeUp() }
        browse.tap()
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 3))
        XCTAssertEqual(wheel.value as? String, currentLabel)
        wheel.adjust(toPickerWheelValue: alternateLabel)
        XCTAssertEqual(wheel.value as? String, alternateLabel)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(stage)-temporary-meditation"
        attachment.lifetime = .keepAlways
        add(attachment)

        let meditation = app.buttons["cycle.home.meditation.start"]
        XCTAssertTrue(meditation.waitForExistence(timeout: 3))
        if !meditation.isHittable { app.swipeUp() }
        meditation.tap()
        let closePlayer = app.buttons["meditation.player.close"]
        XCTAssertTrue(closePlayer.waitForExistence(timeout: 5))
        closePlayer.tap()
        let returnButton = app.buttons["meditation.browse.return"]
        XCTAssertTrue(returnButton.waitForExistence(timeout: 3))
        returnButton.tap()
        XCTAssertTrue(browse.waitForExistence(timeout: 3))
        if !browse.isHittable { app.swipeUp() }
        browse.tap()
        XCTAssertTrue(wheel.waitForExistence(timeout: 3))
        XCTAssertEqual(wheel.value as? String, currentLabel)
    }

    func testThemeRootLeadingEdgeSwipeReturnsWithoutStartingMeditation() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-onboarding.completed", "YES",
            "-life_stage.active", "birthMoment",
            "-premium.isUnlockedForTesting", "YES",
            "-app.language", "en"
        ]
        app.launch()

        let meditationCard = app.buttons[
            "birth_moment.meditation.birth-moment-flower_breath"
        ]
        XCTAssertTrue(meditationCard.waitForExistence(timeout: 3))

        let leadingEdge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.52))
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.52))
        leadingEdge.press(forDuration: 0.05, thenDragTo: destination)

        XCTAssertTrue(app.buttons["life_stage.card.birthMoment"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["meditation.player.close"].exists)
    }

    func testBirthMomentHomeRemainsVerticallyScrollable() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-onboarding.completed", "YES",
            "-life_stage.active", "birthMoment",
            "-premium.isUnlockedForTesting", "YES",
            "-app.language", "en"
        ]
        app.launch()

        let firstMeditation = app.buttons[
            "birth_moment.meditation.birth-moment-flower_breath"
        ]
        XCTAssertTrue(firstMeditation.waitForExistence(timeout: 3))
        let initialMinY = firstMeditation.frame.minY

        app.swipeUp()

        XCTAssertLessThan(firstMeditation.frame.minY, initialMinY - 40)
        XCTAssertFalse(app.buttons["meditation.player.close"].exists)
    }

    func testAppLaunches() {
        let app = XCUIApplication()
        app.launchArguments += ["-premium.isUnlockedForTesting", "YES"]
        app.launch()
        completeOnboardingIfNeeded(in: app)
        XCTAssertTrue(app.buttons["life_stage.card.cycle"].waitForExistence(timeout: 3))
    }

    func testSettingsPanelHidesLanguageWhileTurkishOnly() {
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
        XCTAssertFalse(languageButton.exists)
        let closeButton = app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "Close", "Kapat")
        ).firstMatch
        XCTAssertTrue(closeButton.waitForExistence(timeout: 2))
        XCTAssertTrue(closeButton.isHittable, "Close frame: \(closeButton.frame), exists: \(closeButton.exists)")
        XCTAssertFalse(app.buttons["settings.language.en"].exists)
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
        let skipOffline = app.buttons["offline.onboarding.skip.button"]
        if skipOffline.waitForExistence(timeout: 1) {
            skipOffline.tap()
        }

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
