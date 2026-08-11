import XCTest
@testable import HESIA

final class PregnancyTrackerTests: XCTestCase {
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
        XCTAssertEqual(PregnancyTrimester.first.weekRange, 1...13)
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

        XCTAssertEqual(tracker.overviewWeeks(around: 1), Array(1...8))
        XCTAssertEqual(tracker.overviewWeeks(around: 18), Array(15...22))
        XCTAssertEqual(tracker.overviewWeeks(around: 42), Array(35...42))
    }

    func testPostpartumTransitionIsOfferedFromWeekForty() throws {
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
                .shouldOfferPostpartumTransition
        )
        XCTAssertTrue(
            tracker.calculate(profile: weekForty, on: referenceDate)
                .shouldOfferPostpartumTransition
        )
    }

    func testStorePersistsWeekAndNormalizedReferenceDate() throws {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 18, minute: 30))
        )
        let store = PregnancyStore(defaults: defaults, calendar: calendar, now: { now })

        let profile = try XCTUnwrap(store.save(referenceWeek: 18))

        XCTAssertEqual(profile.referenceWeek, 18)
        XCTAssertEqual(profile.referenceDate, calendar.startOfDay(for: now))
        XCTAssertEqual(defaults.integer(forKey: PregnancyPersistenceKeys.referenceWeek), 18)
        XCTAssertTrue(defaults.bool(forKey: PregnancyPersistenceKeys.onboardingCompleted))
        XCTAssertEqual(store.profile, profile)
    }

    func testUpdatingWeekResetsReferenceDateAndKeepsCompletedState() throws {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 1)))
        let updateDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 20)))

        _ = PregnancyStore(defaults: defaults, calendar: calendar, now: { firstDate })
            .save(referenceWeek: 18)
        let updatedStore = PregnancyStore(defaults: defaults, calendar: calendar, now: { updateDate })
        let updatedProfile = try XCTUnwrap(updatedStore.save(referenceWeek: 24))

        XCTAssertEqual(updatedProfile.referenceWeek, 24)
        XCTAssertEqual(updatedProfile.referenceDate, calendar.startOfDay(for: updateDate))
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

        viewModel.selectedWeek = 18
        XCTAssertTrue(viewModel.canContinue)
        XCTAssertTrue(viewModel.save())
        XCTAssertEqual(defaults.integer(forKey: PregnancyPersistenceKeys.referenceWeek), 18)
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
