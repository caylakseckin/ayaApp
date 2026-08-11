import Foundation

enum CycleOnboardingStep: Int, CaseIterable, Identifiable, Sendable {
    case lastPeriodStart
    case cycleLength
    case periodDuration

    var id: Int { rawValue }

    var next: CycleOnboardingStep? {
        CycleOnboardingStep(rawValue: rawValue + 1)
    }

    var previous: CycleOnboardingStep? {
        CycleOnboardingStep(rawValue: rawValue - 1)
    }
}

enum CycleOnboardingMode: Sendable {
    case initial
    case edit
}

enum CyclePersistenceKeys {
    static let lastPeriodStartDate = "cycle.lastPeriodStartDate"
    static let averageLength = "cycle.averageLength"
    static let averagePeriodDuration = "cycle.averagePeriodDuration"
    static let onboardingCompleted = "cycle.onboardingCompleted"
}
