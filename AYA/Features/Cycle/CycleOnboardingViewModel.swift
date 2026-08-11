import Combine
import Foundation

enum CycleOnboardingValidationIssue: Equatable {
    case cycleLengthOutsideAcceptedRange
    case periodDurationOutsideAcceptedRange

    var localizationKey: String {
        switch self {
        case .cycleLengthOutsideAcceptedRange:
            "cycle.onboarding.validation.cycle_length.accepted_range"
        case .periodDurationOutsideAcceptedRange:
            "cycle.onboarding.validation.period_duration.accepted_range"
        }
    }
}

@MainActor
final class CycleOnboardingViewModel: ObservableObject {
    let mode: CycleOnboardingMode

    @Published private(set) var currentStep: CycleOnboardingStep = .lastPeriodStart
    @Published private(set) var lastPeriodStartDate: Date?
    @Published private(set) var averageLengthText = ""
    @Published private(set) var averagePeriodDurationText = ""

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    init(
        mode: CycleOnboardingMode = .initial,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.mode = mode
        self.defaults = defaults
        self.calendar = calendar
        self.now = now

        guard mode == .edit else { return }

        if defaults.object(forKey: CyclePersistenceKeys.lastPeriodStartDate) != nil {
            lastPeriodStartDate = Date(
                timeIntervalSince1970: defaults.double(forKey: CyclePersistenceKeys.lastPeriodStartDate)
            )
        }

        if defaults.object(forKey: CyclePersistenceKeys.averageLength) != nil {
            averageLengthText = String(defaults.integer(forKey: CyclePersistenceKeys.averageLength))
        }

        if defaults.object(forKey: CyclePersistenceKeys.averagePeriodDuration) != nil {
            averagePeriodDurationText = String(
                defaults.integer(forKey: CyclePersistenceKeys.averagePeriodDuration)
            )
        }
    }

    var latestAllowedDate: Date {
        calendar.startOfDay(for: now())
    }

    var averageLength: Int? {
        Int(averageLengthText)
    }

    var averagePeriodDuration: Int? {
        Int(averagePeriodDurationText)
    }

    var isLastPeriodStartOlderThan28Days: Bool {
        guard
            let lastPeriodStartDate,
            let thresholdDate = calendar.date(byAdding: .day, value: -28, to: latestAllowedDate)
        else { return false }

        return calendar.startOfDay(for: lastPeriodStartDate) < thresholdDate
    }

    var isAverageLengthOutsideTypicalRange: Bool {
        guard let averageLength else { return false }
        return !(21...35).contains(averageLength)
    }

    var isAveragePeriodDurationOutsideTypicalRange: Bool {
        guard let averagePeriodDuration else { return false }
        return !(2...7).contains(averagePeriodDuration)
    }

    var validationIssue: CycleOnboardingValidationIssue? {
        switch currentStep {
        case .lastPeriodStart:
            return nil
        case .cycleLength:
            guard !averageLengthText.isEmpty, let averageLength else { return nil }
            return (15...60).contains(averageLength)
                ? nil
                : .cycleLengthOutsideAcceptedRange
        case .periodDuration:
            guard
                !averagePeriodDurationText.isEmpty,
                let averagePeriodDuration
            else { return nil }

            guard (1...15).contains(averagePeriodDuration) else {
                return .periodDurationOutsideAcceptedRange
            }
            return nil
        }
    }

    var isCurrentStepValid: Bool {
        switch currentStep {
        case .lastPeriodStart:
            guard let lastPeriodStartDate else { return false }
            return calendar.startOfDay(for: lastPeriodStartDate) <= latestAllowedDate
        case .cycleLength:
            guard let averageLength else { return false }
            return (15...60).contains(averageLength)
        case .periodDuration:
            guard
                let averagePeriodDuration,
                let averageLength
            else { return false }
            return (1...15).contains(averagePeriodDuration)
                && averagePeriodDuration <= averageLength
        }
    }

    func selectLastPeriodStartDate(_ date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)
        guard normalizedDate <= latestAllowedDate else { return }

        lastPeriodStartDate = normalizedDate
    }

    func updateAverageLength(_ rawValue: String) {
        averageLengthText = sanitizedNumericText(rawValue)
    }

    func updateAveragePeriodDuration(_ rawValue: String) {
        averagePeriodDurationText = sanitizedNumericText(rawValue)

    }

    @discardableResult
    func moveToPreviousStep() -> Bool {
        guard let previous = currentStep.previous else { return false }
        currentStep = previous
        return true
    }

    @discardableResult
    func advance() -> Bool {
        guard isCurrentStepValid else { return false }

        if let next = currentStep.next {
            currentStep = next
            return false
        }

        guard
            let lastPeriodStartDate,
            let averageLength,
            let averagePeriodDuration
        else { return false }

        defaults.set(
            lastPeriodStartDate.timeIntervalSince1970,
            forKey: CyclePersistenceKeys.lastPeriodStartDate
        )
        defaults.set(averageLength, forKey: CyclePersistenceKeys.averageLength)
        defaults.set(averagePeriodDuration, forKey: CyclePersistenceKeys.averagePeriodDuration)
        defaults.set(true, forKey: CyclePersistenceKeys.onboardingCompleted)
        return true
    }

    private func sanitizedNumericText(_ rawValue: String) -> String {
        String(rawValue.filter(\.isNumber).prefix(2))
    }

}
