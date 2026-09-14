import XCTest
@testable import HESIA

final class PregnancyTrackerTests: XCTestCase {
    func testTemporaryPregnancyMeditationsMatchEverySupportedWeek() {
        XCTAssertEqual(MeditationJourney.pregnancy.range, 4...42)
        for week in MeditationJourney.pregnancy.range {
            let meditation = MeditationJourney.pregnancy.meditation(at: week)
            XCTAssertEqual(meditation.id, "pregnancy-week-\(week)")
            XCTAssertEqual(meditation.contextValue, week)
            XCTAssertEqual(meditation.remoteAudioSource?.pregnancyWeek, week)
            XCTAssertEqual(meditation.contextNameLocalizationKey, PregnancyTrimester(week: week).nameLocalizationKey)
        }
    }

    func testTemporaryPostpartumMeditationsMatchEverySupportedDay() {
        XCTAssertEqual(MeditationJourney.postpartum.range, 1...90)
        for day in MeditationJourney.postpartum.range {
            let meditation = MeditationJourney.postpartum.meditation(at: day)
            XCTAssertEqual(meditation.id, "postpartum-day-\(day)")
            XCTAssertEqual(meditation.contextValue, day)
            XCTAssertEqual(meditation.remoteAudioSource?.postpartumDay, day)
            XCTAssertEqual(meditation.titleLocalizationKey, PostpartumStage(day: day).meditationTitleLocalizationKey)
        }
    }

    func testCurrentWeekAdvancesFromReferenceDateByCalendarWeeks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 21))
        )
        let profile = try XCTUnwrap(
            PregnancyProfile(referenceWeek: 18, referenceDate: referenceDate, calendar: calendar)
        )
        let tracker = PregnancyTracker(calendar: calendar)

        let sixDaysLater = try XCTUnwrap(calendar.date(byAdding: .day, value: 6, to: referenceDate))
        let sevenDaysLater = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: referenceDate))
        let fourteenDaysLater = try XCTUnwrap(calendar.date(byAdding: .day, value: 14, to: referenceDate))

        XCTAssertEqual(tracker.calculate(profile: profile, on: sixDaysLater).currentWeek, 18)
        XCTAssertEqual(tracker.calculate(profile: profile, on: sevenDaysLater).currentWeek, 19)
        XCTAssertEqual(tracker.calculate(profile: profile, on: fourteenDaysLater).currentWeek, 20)
    }

    func testTrimesterBoundaries() {
        XCTAssertEqual(PregnancyTrimester(week: 13), .first)
        XCTAssertEqual(PregnancyTrimester(week: 14), .second)
        XCTAssertEqual(PregnancyTrimester(week: 27), .second)
        XCTAssertEqual(PregnancyTrimester(week: 28), .third)
        XCTAssertEqual(PregnancyTrimester(week: 42), .third)
    }

    func testTrimesterRangesCoverSupportedPregnancyJourney() {
        XCTAssertEqual(PregnancyTrimester.first.weekRange, 4...13)
        XCTAssertEqual(PregnancyTrimester.second.weekRange, 14...27)
        XCTAssertEqual(PregnancyTrimester.third.weekRange, 28...42)
        XCTAssertEqual(
            PregnancyTrimester.allCases.flatMap { Array($0.weekRange) },
            Array(PregnancyTracker.supportedWeekRange)
        )
    }

    func testJourneyWeekStateIsRelativeToCurrentWeek() {
        XCTAssertEqual(PregnancyJourneyWeekState(week: 17, currentWeek: 18), .past)
        XCTAssertEqual(PregnancyJourneyWeekState(week: 18, currentWeek: 18), .current)
        XCTAssertEqual(PregnancyJourneyWeekState(week: 19, currentWeek: 18), .future)
    }

    func testOverviewWeeksStayInsideSupportedRange() {
        let tracker = PregnancyTracker()

        XCTAssertEqual(tracker.overviewWeeks(around: 1), Array(4...11))
        XCTAssertEqual(tracker.overviewWeeks(around: 4), Array(4...11))
        XCTAssertEqual(tracker.overviewWeeks(around: 18), Array(15...22))
        XCTAssertEqual(tracker.overviewWeeks(around: 42), Array(35...42))
    }

    func testBirthMomentTransitionIsOfferedFromWeekForty() throws {
        let referenceDate = Date(timeIntervalSince1970: 2_000_000_000)
        let tracker = PregnancyTracker()
        let weekThirtyNine = try XCTUnwrap(
            PregnancyProfile(referenceWeek: 39, referenceDate: referenceDate)
        )
        let weekForty = try XCTUnwrap(
            PregnancyProfile(referenceWeek: 40, referenceDate: referenceDate)
        )

        XCTAssertFalse(
            tracker.calculate(profile: weekThirtyNine, on: referenceDate)
                .shouldOfferBirthMomentTransition
        )
        XCTAssertTrue(
            tracker.calculate(profile: weekForty, on: referenceDate)
                .shouldOfferBirthMomentTransition
        )
    }

    func testSelectedWeekStartDayUsesItsMostRecentOccurrence() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let friday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 11, hour: 18))
        )
        let tracker = PregnancyTracker(calendar: calendar)

        XCTAssertEqual(
            tracker.referenceDate(for: .monday, on: friday),
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))
        )
        XCTAssertEqual(
            tracker.referenceDate(for: .friday, on: friday),
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 11))
        )
        XCTAssertEqual(
            tracker.referenceDate(for: .sunday, on: friday),
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 6))
        )
    }

    func testStorePersistsWeekAndSelectedStartDate() throws {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 18, minute: 30))
        )
        let store = PregnancyStore(defaults: defaults, calendar: calendar, now: { now })

        let profile = try XCTUnwrap(
            store.save(referenceWeek: 18, weekStartDay: .monday)
        )
        let expectedMonday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))
        )

        XCTAssertEqual(profile.referenceWeek, 18)
        XCTAssertEqual(profile.referenceDate, expectedMonday)
        XCTAssertEqual(defaults.integer(forKey: PregnancyPersistenceKeys.referenceWeek), 18)
        XCTAssertTrue(defaults.bool(forKey: PregnancyPersistenceKeys.onboardingCompleted))
        XCTAssertEqual(store.profile, profile)
    }

    func testLegacyEarlyWeekProfileNeverDisplaysBeforeWeekFour() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = Date(timeIntervalSince1970: 2_000_000_000)
        let profile = try XCTUnwrap(
            PregnancyProfile(referenceWeek: 1, referenceDate: referenceDate, calendar: calendar)
        )
        let tracker = PregnancyTracker(calendar: calendar)
        let fourWeeksLater = try XCTUnwrap(
            calendar.date(byAdding: .day, value: 28, to: referenceDate)
        )

        XCTAssertEqual(tracker.calculate(profile: profile, on: referenceDate).currentWeek, 4)
        XCTAssertEqual(tracker.calculate(profile: profile, on: fourWeeksLater).currentWeek, 5)
    }

    func testUpdatingWeekResetsReferenceDateAndKeepsCompletedState() throws {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 1)))
        let updateDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 20)))

        _ = PregnancyStore(defaults: defaults, calendar: calendar, now: { firstDate })
            .save(referenceWeek: 18, weekStartDay: .saturday)
        let updatedStore = PregnancyStore(defaults: defaults, calendar: calendar, now: { updateDate })
        let updatedProfile = try XCTUnwrap(
            updatedStore.save(referenceWeek: 24, weekStartDay: .monday)
        )
        let expectedMonday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))
        )

        XCTAssertEqual(updatedProfile.referenceWeek, 24)
        XCTAssertEqual(updatedProfile.referenceDate, expectedMonday)
        XCTAssertTrue(defaults.bool(forKey: PregnancyPersistenceKeys.onboardingCompleted))
    }

    @MainActor
    func testSetupStartsWithoutSelectionAndSavesOnlyValidWeek() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let viewModel = PregnancySetupViewModel(
            store: PregnancyStore(defaults: defaults)
        )

        XCTAssertNil(viewModel.selectedWeek)
        XCTAssertFalse(viewModel.canContinue)
        XCTAssertFalse(viewModel.save())

        viewModel.selectedWeek = 3
        XCTAssertFalse(viewModel.canContinue)
        XCTAssertFalse(viewModel.save())

        viewModel.selectedWeek = 4
        XCTAssertFalse(viewModel.canContinue)

        viewModel.selectedWeekStartDay = .monday
        XCTAssertTrue(viewModel.canContinue)

        viewModel.selectedWeek = 18
        XCTAssertTrue(viewModel.canContinue)
        XCTAssertTrue(viewModel.save())
        XCTAssertEqual(defaults.integer(forKey: PregnancyPersistenceKeys.referenceWeek), 18)
        XCTAssertEqual(
            PregnancyStore(defaults: defaults).profile.map {
                PregnancyTracker().weekStartDay(for: $0.referenceDate)
            },
            .monday
        )
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "PregnancyTrackerTests.\(UUID().uuidString)")!
    }

    private func clear(_ defaults: UserDefaults) {
        [
            PregnancyPersistenceKeys.referenceWeek,
            PregnancyPersistenceKeys.referenceDate,
            PregnancyPersistenceKeys.onboardingCompleted
        ].forEach(defaults.removeObject(forKey:))
    }
}
