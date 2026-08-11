import XCTest
@testable import HESIA

final class HESIAOnboardingStateTests: XCTestCase {
    private let resolver = HESIAOnboardingRouteResolver()

    func testFreshInstallStartsWithWelcome() {
        XCTAssertEqual(
            resolver.route(
                hasCompletedOnboarding: false,
                hasCompletedWelcome: false,
                hasCompletedTutorial: false
            ),
            .welcome
        )
    }

    func testWelcomeCompletionAdvancesToTutorial() {
        XCTAssertEqual(
            resolver.route(
                hasCompletedOnboarding: false,
                hasCompletedWelcome: true,
                hasCompletedTutorial: false
            ),
            .tutorial
        )
    }

    func testTutorialCompletionAdvancesToBiometricSetup() {
        XCTAssertEqual(
            resolver.route(
                hasCompletedOnboarding: false,
                hasCompletedWelcome: true,
                hasCompletedTutorial: true
            ),
            .biometric
        )
    }

    func testExistingUserAlwaysEntersAppWithoutTutorialMigration() {
        XCTAssertEqual(
            resolver.route(
                hasCompletedOnboarding: true,
                hasCompletedWelcome: false,
                hasCompletedTutorial: false
            ),
            .app
        )
    }

    func testReplayDoesNotCompleteFirstLaunch() {
        XCTAssertFalse(HESIATutorialPresentationContext.replayFromSettings.completesFirstLaunch)
        XCTAssertTrue(HESIATutorialPresentationContext.firstLaunch.completesFirstLaunch)
    }
}
