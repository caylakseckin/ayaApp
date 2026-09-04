import XCTest
@testable import HESIA

final class PostpartumTrackerTests: XCTestCase {
    func testBirthDateBecomesDayOneAndCalendarDifferenceAdvancesDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let birthDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 27, hour: 18))
        )
        let profile = try XCTUnwrap(
            PostpartumProfile(birthDate: birthDate, calendar: calendar, now: birthDate)
        )
        let tracker = PostpartumTracker(calendar: calendar)
        let dayTwelve = try XCTUnwrap(calendar.date(byAdding: .day, value: 11, to: birthDate))

        XCTAssertEqual(tracker.calculate(profile: profile, on: birthDate).currentDay, 1)
        XCTAssertEqual(tracker.calculate(profile: profile, on: dayTwelve).currentDay, 12)
    }

    func testStageBoundaries() {
        XCTAssertEqual(PostpartumStage(day: 1), .firstDays)
        XCTAssertEqual(PostpartumStage(day: 7), .firstDays)
        XCTAssertEqual(PostpartumStage(day: 8), .earlyPostpartum)
        XCTAssertEqual(PostpartumStage(day: 42), .earlyPostpartum)
        XCTAssertEqual(PostpartumStage(day: 43), .transition)
        XCTAssertEqual(PostpartumStage(day: 84), .transition)
        XCTAssertEqual(PostpartumStage(day: 85), .newRhythm)
    }

    func testRecoveryStageGroupsExistingContentStagesIntoThreeHomeStages() {
        XCTAssertEqual(PostpartumRecoveryStage(stage: .firstDays), .firstDays)
        XCTAssertEqual(PostpartumRecoveryStage(stage: .earlyPostpartum), .firstWeeks)
        XCTAssertEqual(PostpartumRecoveryStage(stage: .transition), .newRhythm)
        XCTAssertEqual(PostpartumRecoveryStage(stage: .newRhythm), .newRhythm)
    }

    func testProgressUsesNinetyDayJourneyAndCapsAtOne() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let dayFortyFiveBirthDate = now.addingTimeInterval(-44 * 86_400)
        let dayFortyFiveProfile = try XCTUnwrap(
            PostpartumProfile(birthDate: dayFortyFiveBirthDate, now: now)
        )
        let pastJourneyBirthDate = now.addingTimeInterval(-100 * 86_400)
        let pastJourneyProfile = try XCTUnwrap(
            PostpartumProfile(birthDate: pastJourneyBirthDate, now: now)
        )

        XCTAssertEqual(
            PostpartumTracker().calculate(profile: dayFortyFiveProfile, on: now).progress,
            0.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            PostpartumTracker().calculate(profile: pastJourneyProfile, on: now).progress,
            1
        )
    }

    func testMotherhoodTransitionIsOfferedAfterDayNinety() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let birthDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))
        )
        let profile = try XCTUnwrap(
            PostpartumProfile(birthDate: birthDate, calendar: calendar, now: birthDate)
        )
        let dayNinety = try XCTUnwrap(calendar.date(byAdding: .day, value: 89, to: birthDate))
        let dayNinetyOne = try XCTUnwrap(calendar.date(byAdding: .day, value: 90, to: birthDate))
        let tracker = PostpartumTracker(calendar: calendar)

        XCTAssertFalse(
            tracker.calculate(profile: profile, on: dayNinety)
                .shouldOfferMotherhoodTransition
        )
        XCTAssertTrue(
            tracker.calculate(profile: profile, on: dayNinetyOne)
                .shouldOfferMotherhoodTransition
        )
    }

    func testTimelineStaysAtDayOneAndCentersLaterDays() {
        let tracker = PostpartumTracker()
        XCTAssertEqual(tracker.timelineDays(around: 1), Array(1...7))
        XCTAssertEqual(tracker.timelineDays(around: 12), Array(9...15))
        XCTAssertEqual(tracker.timelineDays(around: 90), Array(84...90))
        XCTAssertEqual(tracker.timelineDays(around: 100), Array(84...90))
    }

    func testJourneyPhaseBoundaries() {
        XCTAssertEqual(PostpartumJourneyPhase.phase(containing: 1), .restAndArrival)
        XCTAssertEqual(PostpartumJourneyPhase.phase(containing: 7), .restAndArrival)
        XCTAssertEqual(PostpartumJourneyPhase.phase(containing: 8), .earlyPostpartum)
        XCTAssertEqual(PostpartumJourneyPhase.phase(containing: 14), .earlyPostpartum)
        XCTAssertEqual(PostpartumJourneyPhase.phase(containing: 15), .settlingIn)
        XCTAssertEqual(PostpartumJourneyPhase.phase(containing: 28), .settlingIn)
        XCTAssertEqual(PostpartumJourneyPhase.phase(containing: 29), .rebuildingRhythm)
        XCTAssertEqual(PostpartumJourneyPhase.phase(containing: 56), .rebuildingRhythm)
        XCTAssertEqual(PostpartumJourneyPhase.phase(containing: 57), .growingTogether)
        XCTAssertEqual(PostpartumJourneyPhase.phase(containing: 90), .growingTogether)
    }

    func testJourneyPhaseStatesForDayTen() {
        XCTAssertEqual(PostpartumJourneyPhase.restAndArrival.state(on: 10), .completed)
        XCTAssertEqual(PostpartumJourneyPhase.earlyPostpartum.state(on: 10), .current)
        XCTAssertEqual(PostpartumJourneyPhase.settlingIn.state(on: 10), .upcoming)
        XCTAssertEqual(PostpartumJourneyPhase.rebuildingRhythm.state(on: 10), .upcoming)
        XCTAssertEqual(PostpartumJourneyPhase.growingTogether.state(on: 10), .upcoming)
    }

    func testFutureBirthDateIsRejected() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        XCTAssertNil(PostpartumProfile(birthDate: now.addingTimeInterval(86_400), now: now))
    }

    func testStorePersistsNormalizedBirthDateAndCompletion() throws {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 20))
        )
        let birthDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 27, hour: 15))
        )
        let store = PostpartumStore(defaults: defaults, calendar: calendar, now: { now })

        let profile = try XCTUnwrap(store.save(birthDate: birthDate))

        XCTAssertEqual(profile.birthDate, calendar.startOfDay(for: birthDate))
        XCTAssertEqual(store.profile, profile)
        XCTAssertTrue(defaults.bool(forKey: PostpartumPersistenceKeys.onboardingCompleted))
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "PostpartumTrackerTests.\(UUID().uuidString)")!
    }

    private func clear(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: PostpartumPersistenceKeys.birthDate)
        defaults.removeObject(forKey: PostpartumPersistenceKeys.onboardingCompleted)
    }
}
