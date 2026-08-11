import Foundation

enum HESIAOnboardingPersistenceKeys {
    static let completed = "onboarding.completed"
    static let welcomeCompleted = "onboarding.welcomeCompleted"
    static let tutorialCompleted = "onboarding.tutorialCompleted"
}

enum HESIAOnboardingRoute: Equatable {
    case welcome
    case tutorial
    case biometric
    case app
}

struct HESIAOnboardingRouteResolver {
    func route(
        hasCompletedOnboarding: Bool,
        hasCompletedWelcome: Bool,
        hasCompletedTutorial: Bool
    ) -> HESIAOnboardingRoute {
        // Backward compatibility: users who completed the previous onboarding
        // must never be sent back into a newly introduced first-run step.
        if hasCompletedOnboarding {
            return .app
        }
        if !hasCompletedWelcome {
            return .welcome
        }
        if !hasCompletedTutorial {
            return .tutorial
        }
        return .biometric
    }
}

enum HESIATutorialPresentationContext: Equatable {
    case firstLaunch
    case replayFromSettings

    var completesFirstLaunch: Bool {
        self == .firstLaunch
    }
}
