import XCTest
@testable import HESIA

final class CycleOnboardingTests: XCTestCase {
    func testThreeStepsAreDefinedInOrder() {
        XCTAssertEqual(
            CycleOnboardingStep.allCases,
            [.lastPeriodStart, .cycleLength, .periodDuration]
        )
    }

    @MainActor
    func testOnboardingStartsWithoutAnAutomaticallySelectedDate() {
        let defaults = makeDefaults()
        defer { clear(defaults) }

        let viewModel = CycleOnboardingViewModel(defaults: defaults)

        XCTAssertNil(viewModel.lastPeriodStartDate)
        XCTAssertEqual(viewModel.currentStep, .lastPeriodStart)
        XCTAssertFalse(viewModel.isCurrentStepValid)
    }

    @MainActor
    func testFutureDateIsRejected() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let viewModel = CycleOnboardingViewModel(defaults: defaults, now: { now })

        viewModel.selectLastPeriodStartDate(now.addingTimeInterval(86_400))

        XCTAssertNil(viewModel.lastPeriodStartDate)
        XCTAssertFalse(viewModel.isCurrentStepValid)
    }

    @MainActor
    func testLastPeriodAdvisoryStartsBeforeTwentyEightDayBoundary() throws {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 9, hour: 14))
        )
        let viewModel = CycleOnboardingViewModel(
            defaults: defaults,
            calendar: calendar,
            now: { now }
        )

        viewModel.selectLastPeriodStartDate(
            try XCTUnwrap(calendar.date(byAdding: .day, value: -28, to: now))
        )
        XCTAssertFalse(viewModel.isLastPeriodStartOlderThan28Days)

        viewModel.selectLastPeriodStartDate(
            try XCTUnwrap(calendar.date(byAdding: .day, value: -29, to: now))
        )
        XCTAssertTrue(viewModel.isLastPeriodStartOlderThan28Days)
    }

    @MainActor
    func testTypicalRangeAdvisoriesDoNotChangeAcceptedInputRanges() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let viewModel = CycleOnboardingViewModel(defaults: defaults)

        viewModel.updateAverageLength("20")
        XCTAssertTrue(viewModel.isAverageLengthOutsideTypicalRange)
        viewModel.updateAverageLength("21")
        XCTAssertFalse(viewModel.isAverageLengthOutsideTypicalRange)
        viewModel.updateAverageLength("35")
        XCTAssertFalse(viewModel.isAverageLengthOutsideTypicalRange)
        viewModel.updateAverageLength("36")
        XCTAssertTrue(viewModel.isAverageLengthOutsideTypicalRange)

        viewModel.updateAveragePeriodDuration("1")
        XCTAssertTrue(viewModel.isAveragePeriodDurationOutsideTypicalRange)
        viewModel.updateAveragePeriodDuration("2")
        XCTAssertFalse(viewModel.isAveragePeriodDurationOutsideTypicalRange)
        viewModel.updateAveragePeriodDuration("7")
        XCTAssertFalse(viewModel.isAveragePeriodDurationOutsideTypicalRange)
        viewModel.updateAveragePeriodDuration("8")
        XCTAssertTrue(viewModel.isAveragePeriodDurationOutsideTypicalRange)
    }

    @MainActor
    func testInvalidValuesExposeAnInlineValidationReason() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let viewModel = CycleOnboardingViewModel(defaults: defaults)

        viewModel.selectLastPeriodStartDate(Date())
        XCTAssertFalse(viewModel.advance())

        viewModel.updateAverageLength("14")
        XCTAssertEqual(viewModel.validationIssue, .cycleLengthOutsideAcceptedRange)

        viewModel.updateAverageLength("20")
        XCTAssertNil(viewModel.validationIssue)
        XCTAssertFalse(viewModel.advance())

        viewModel.updateAveragePeriodDuration("16")
        XCTAssertEqual(viewModel.validationIssue, .periodDurationOutsideAcceptedRange)

        viewModel.updateAveragePeriodDuration("21")
        XCTAssertEqual(viewModel.validationIssue, .periodDurationOutsideAcceptedRange)

        viewModel.updateAveragePeriodDuration("15")
        XCTAssertNil(viewModel.validationIssue)
    }

    @MainActor
    func testValidationCompletionAndLocalPersistence() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let startDate = now.addingTimeInterval(-172_800)
        let viewModel = CycleOnboardingViewModel(defaults: defaults, now: { now })

        viewModel.selectLastPeriodStartDate(startDate)
        XCTAssertTrue(viewModel.isCurrentStepValid)
        XCTAssertFalse(viewModel.advance())
        XCTAssertEqual(viewModel.currentStep, .cycleLength)

        viewModel.updateAverageLength("2a8")
        XCTAssertEqual(viewModel.averageLengthText, "28")
        XCTAssertTrue(viewModel.isCurrentStepValid)
        XCTAssertFalse(viewModel.advance())
        XCTAssertEqual(viewModel.currentStep, .periodDuration)

        viewModel.updateAveragePeriodDuration("16")
        XCTAssertFalse(viewModel.isCurrentStepValid)
        viewModel.updateAveragePeriodDuration("5")
        XCTAssertTrue(viewModel.isCurrentStepValid)
        XCTAssertTrue(viewModel.advance())

        XCTAssertEqual(defaults.integer(forKey: CyclePersistenceKeys.averageLength), 28)
        XCTAssertEqual(defaults.integer(forKey: CyclePersistenceKeys.averagePeriodDuration), 5)
        XCTAssertTrue(defaults.bool(forKey: CyclePersistenceKeys.onboardingCompleted))
        XCTAssertNotNil(defaults.object(forKey: CyclePersistenceKeys.lastPeriodStartDate))
    }

    @MainActor
    func testPreviousStepKeepsEnteredValues() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let viewModel = CycleOnboardingViewModel(defaults: defaults)

        viewModel.selectLastPeriodStartDate(Date().addingTimeInterval(-86_400))
        _ = viewModel.advance()
        viewModel.updateAverageLength("30")
        _ = viewModel.advance()
        viewModel.updateAveragePeriodDuration("6")

        XCTAssertTrue(viewModel.moveToPreviousStep())
        XCTAssertEqual(viewModel.averageLengthText, "30")
        XCTAssertEqual(viewModel.averagePeriodDurationText, "6")
        XCTAssertNotNil(viewModel.lastPeriodStartDate)
    }

    @MainActor
    func testInitialModeDoesNotPrefillButEditModeDoes() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let storedDate = Date(timeIntervalSince1970: 1_800_000_000)
        defaults.set(storedDate.timeIntervalSince1970, forKey: CyclePersistenceKeys.lastPeriodStartDate)
        defaults.set(28, forKey: CyclePersistenceKeys.averageLength)
        defaults.set(5, forKey: CyclePersistenceKeys.averagePeriodDuration)

        let initialViewModel = CycleOnboardingViewModel(mode: .initial, defaults: defaults)
        let editViewModel = CycleOnboardingViewModel(mode: .edit, defaults: defaults)

        XCTAssertNil(initialViewModel.lastPeriodStartDate)
        XCTAssertEqual(initialViewModel.averageLengthText, "")
        XCTAssertEqual(initialViewModel.averagePeriodDurationText, "")
        XCTAssertNotNil(editViewModel.lastPeriodStartDate)
        XCTAssertEqual(editViewModel.averageLengthText, "28")
        XCTAssertEqual(editViewModel.averagePeriodDurationText, "5")
    }

    @MainActor
    func testEditModeOverwritesOnlyAfterFinalSave() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let storedDate = Date(timeIntervalSince1970: 1_800_000_000)
        defaults.set(storedDate.timeIntervalSince1970, forKey: CyclePersistenceKeys.lastPeriodStartDate)
        defaults.set(28, forKey: CyclePersistenceKeys.averageLength)
        defaults.set(5, forKey: CyclePersistenceKeys.averagePeriodDuration)
        defaults.set(true, forKey: CyclePersistenceKeys.onboardingCompleted)
        let viewModel = CycleOnboardingViewModel(
            mode: .edit,
            defaults: defaults,
            now: { storedDate.addingTimeInterval(86_400) }
        )

        XCTAssertFalse(viewModel.advance())
        viewModel.updateAverageLength("30")
        XCTAssertEqual(defaults.integer(forKey: CyclePersistenceKeys.averageLength), 28)
        XCTAssertFalse(viewModel.advance())
        viewModel.updateAveragePeriodDuration("6")
        XCTAssertEqual(defaults.integer(forKey: CyclePersistenceKeys.averagePeriodDuration), 5)
        XCTAssertTrue(viewModel.advance())

        XCTAssertEqual(defaults.integer(forKey: CyclePersistenceKeys.averageLength), 30)
        XCTAssertEqual(defaults.integer(forKey: CyclePersistenceKeys.averagePeriodDuration), 6)
        XCTAssertTrue(defaults.bool(forKey: CyclePersistenceKeys.onboardingCompleted))
    }

    func testCalculatorNormalizesDatesWrapsCycleAndResolvesPhase() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 18)))
        let targetDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 2)))
        let profile = try XCTUnwrap(
            CycleProfile(
                lastPeriodStartDate: startDate,
                averageCycleLength: 28,
                averagePeriodDuration: 5,
                calendar: calendar
            )
        )
        let calculator = CycleCalculator(calendar: calendar)

        let calculation = calculator.calculate(profile: profile, on: targetDate)

        XCTAssertEqual(calculation.currentCycleDay, 23)
        XCTAssertEqual(calculation.currentPhase, .luteal)
        XCTAssertEqual(calculation.phaseDay, 8)
        XCTAssertEqual(calculation.cycleProgress, 23.0 / 28.0, accuracy: 0.0001)
    }

    func testCalculatorSupportsAllFourPhases() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 1)))
        let profile = try XCTUnwrap(
            CycleProfile(
                lastPeriodStartDate: startDate,
                averageCycleLength: 28,
                averagePeriodDuration: 5,
                calendar: calendar
            )
        )
        let calculator = CycleCalculator(calendar: calendar)

        func phase(onDay day: Int) throws -> CyclePhase {
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: day - 1, to: startDate))
            return calculator.calculate(profile: profile, on: date).currentPhase
        }

        XCTAssertEqual(try phase(onDay: 1), .menstrual)
        XCTAssertEqual(try phase(onDay: 6), .follicular)
        XCTAssertEqual(try phase(onDay: 14), .ovulatory)
        XCTAssertEqual(try phase(onDay: 23), .luteal)
    }

    func testCalculatorProjectsCalendarDatesBeforeStoredStart() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10)))
        let previousDate = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: startDate))
        let profile = try XCTUnwrap(
            CycleProfile(
                lastPeriodStartDate: startDate,
                averageCycleLength: 28,
                averagePeriodDuration: 5,
                calendar: calendar
            )
        )

        let calculation = CycleCalculator(calendar: calendar).calculate(
            profile: profile,
            on: previousDate
        )

        XCTAssertEqual(calculation.currentCycleDay, 28)
        XCTAssertEqual(calculation.currentPhase, .luteal)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "CycleOnboardingTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private func clear(_ defaults: UserDefaults) {
        for key in [
            CyclePersistenceKeys.lastPeriodStartDate,
            CyclePersistenceKeys.averageLength,
            CyclePersistenceKeys.averagePeriodDuration,
            CyclePersistenceKeys.onboardingCompleted
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
