import XCTest
@testable import HESIA

final class HESIAOnboardingStateTests: XCTestCase {
    private let resolver = HESIAOnboardingRouteResolver()

    func testFreshInstallStartsWithWelcome() {
        XCTAssertEqual(
            resolver.route(
                hasCompletedOnboarding: false,
                hasCompletedWelcome: false,
                hasCompletedTutorial: false,
                hasCompletedOfflineSetup: false
            ),
            .welcome
        )
    }

    func testWelcomeCompletionAdvancesToTutorial() {
        XCTAssertEqual(
            resolver.route(
                hasCompletedOnboarding: false,
                hasCompletedWelcome: true,
                hasCompletedTutorial: false,
                hasCompletedOfflineSetup: false
            ),
            .tutorial
        )
    }

    func testTutorialCompletionAdvancesToOfflineSetup() {
        XCTAssertEqual(
            resolver.route(
                hasCompletedOnboarding: false,
                hasCompletedWelcome: true,
                hasCompletedTutorial: true,
                hasCompletedOfflineSetup: false
            ),
            .offline
        )
    }

    func testOfflineSetupCompletionAdvancesToBiometricSetup() {
        XCTAssertEqual(
            resolver.route(
                hasCompletedOnboarding: false,
                hasCompletedWelcome: true,
                hasCompletedTutorial: true,
                hasCompletedOfflineSetup: true
            ),
            .biometric
        )
    }

    func testExistingUserAlwaysEntersAppWithoutTutorialMigration() {
        XCTAssertEqual(
            resolver.route(
                hasCompletedOnboarding: true,
                hasCompletedWelcome: false,
                hasCompletedTutorial: false,
                hasCompletedOfflineSetup: false
            ),
            .app
        )
    }

    func testOfflinePackageContainsTodayAndNextTwoDays() {
        XCTAssertEqual(
            OfflineMeditationPackagePlanner.cycleDays(currentDay: 8, cycleLength: 28),
            [8, 9, 10]
        )
    }

    func testOfflinePackageWrapsAtCycleBoundary() {
        XCTAssertEqual(
            OfflineMeditationPackagePlanner.cycleDays(currentDay: 28, cycleLength: 28),
            [28, 1, 2]
        )
    }

    func testPregnancyOfflinePackageContainsOnlyCurrentWeek() {
        XCTAssertTrue(OfflineMeditationPackagePlanner.pregnancyWeeks(currentWeek: 3).isEmpty)
        XCTAssertEqual(
            OfflineMeditationPackagePlanner.pregnancyWeeks(currentWeek: 4),
            [4]
        )
        XCTAssertEqual(
            OfflineMeditationPackagePlanner.pregnancyWeeks(currentWeek: 18),
            [18]
        )
        XCTAssertTrue(OfflineMeditationPackagePlanner.pregnancyWeeks(currentWeek: 43).isEmpty)
    }

    func testPostpartumOfflinePackageContainsTodayAndNextAvailableDays() {
        XCTAssertEqual(
            OfflineMeditationPackagePlanner.postpartumDays(currentDay: 18),
            [18, 19, 20]
        )
        XCTAssertEqual(
            OfflineMeditationPackagePlanner.postpartumDays(currentDay: 89),
            [89, 90]
        )
        XCTAssertTrue(OfflineMeditationPackagePlanner.postpartumDays(currentDay: 91).isEmpty)
    }

    func testBiometricAutomaticUnlockRunsOnlyOncePerLock() {
        XCTAssertTrue(
            BiometricAutomaticUnlockPolicy.shouldAttempt(
                isLocked: true,
                isAuthenticating: false,
                hasAttempted: false
            )
        )
        XCTAssertFalse(
            BiometricAutomaticUnlockPolicy.shouldAttempt(
                isLocked: true,
                isAuthenticating: false,
                hasAttempted: true
            )
        )
        XCTAssertFalse(
            BiometricAutomaticUnlockPolicy.shouldAttempt(
                isLocked: true,
                isAuthenticating: true,
                hasAttempted: false
            )
        )
    }

    func testReplayDoesNotCompleteFirstLaunch() {
        XCTAssertFalse(HESIATutorialPresentationContext.replayFromSettings.completesFirstLaunch)
        XCTAssertTrue(HESIATutorialPresentationContext.firstLaunch.completesFirstLaunch)
    }

    func testDeviceDataResetClearsTheApplicationDefaultsDomain() throws {
        let suiteName = "DeviceDataResetServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("Beril", forKey: "user.name")
        defaults.set(true, forKey: HESIAOnboardingPersistenceKeys.completed)
        defaults.set(30, forKey: PregnancyPersistenceKeys.referenceWeek)

        DeviceDataResetService.reset(
            defaults: defaults,
            bundleIdentifier: suiteName
        )

        XCTAssertNil(defaults.object(forKey: "user.name"))
        XCTAssertNil(defaults.object(forKey: HESIAOnboardingPersistenceKeys.completed))
        XCTAssertNil(defaults.object(forKey: PregnancyPersistenceKeys.referenceWeek))
    }

    @MainActor
    func testInstallAttributionRegistersOnlyOnceAfterSuccess() async throws {
        let suiteName = "InstallAttributionRegistrarTests.success.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let registrar = InstallAttributionRegistrar()
        var callCount = 0

        await registrar.registerIfNeeded(defaults: defaults) {
            callCount += 1
        }
        await registrar.registerIfNeeded(defaults: defaults) {
            callCount += 1
        }

        XCTAssertEqual(callCount, 1)
        XCTAssertTrue(
            defaults.bool(forKey: InstallAttributionPersistenceKeys.registrationCompleted)
        )
    }

    @MainActor
    func testInstallAttributionRetriesAfterFailure() async throws {
        enum TestError: Error { case failed }

        let suiteName = "InstallAttributionRegistrarTests.retry.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let registrar = InstallAttributionRegistrar()
        var callCount = 0

        await registrar.registerIfNeeded(defaults: defaults) {
            callCount += 1
            throw TestError.failed
        }
        await registrar.registerIfNeeded(defaults: defaults) {
            callCount += 1
        }

        XCTAssertEqual(callCount, 2)
        XCTAssertTrue(
            defaults.bool(forKey: InstallAttributionPersistenceKeys.registrationCompleted)
        )
    }
}
