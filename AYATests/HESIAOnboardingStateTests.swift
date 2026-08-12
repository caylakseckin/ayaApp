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

    func testReplayDoesNotCompleteFirstLaunch() {
        XCTAssertFalse(HESIATutorialPresentationContext.replayFromSettings.completesFirstLaunch)
        XCTAssertTrue(HESIATutorialPresentationContext.firstLaunch.completesFirstLaunch)
    }
}
