import Foundation

enum PregnancyPersistenceKeys {
    static let referenceWeek = "pregnancy.referenceWeek"
    static let referenceDate = "pregnancy.referenceDate"
    static let onboardingCompleted = "pregnancy.onboardingCompleted"
}

enum PregnancyTrimester: Int, CaseIterable, Sendable {
    case first = 1
    case second
    case third

    init(week: Int) {
        switch week {
        case ...13: self = .first
        case 14...27: self = .second
        default: self = .third
        }
    }

    var nameLocalizationKey: String {
        "pregnancy.trimester.\(rawValue)"
    }

    var insightTitleLocalizationKey: String {
        "pregnancy.trimester.\(rawValue).insight.title"
    }

    var insightDescriptionLocalizationKey: String {
        "pregnancy.trimester.\(rawValue).insight.description"
    }

    var weekRange: ClosedRange<Int> {
        switch self {
        case .first: 1...13
        case .second: 14...27
        case .third: 28...42
        }
    }

    var calendarTitleLocalizationKey: String {
        "pregnancy.calendar.trimester.\(rawValue).title"
    }

    var calendarSubtitleLocalizationKey: String {
        "pregnancy.calendar.trimester.\(rawValue).subtitle"
    }
}

enum PregnancyJourneyWeekState: String, Sendable {
    case past
    case current
    case future

    init(week: Int, currentWeek: Int) {
        if week < currentWeek {
            self = .past
        } else if week == currentWeek {
            self = .current
        } else {
            self = .future
        }
    }

    var localizationKey: String {
        "pregnancy.calendar.week.state.\(rawValue)"
    }
}

struct PregnancyProfile: Equatable, Sendable {
    let referenceWeek: Int
    let referenceDate: Date

    init?(referenceWeek: Int, referenceDate: Date, calendar: Calendar = .current) {
        guard PregnancyTracker.supportedWeekRange.contains(referenceWeek) else { return nil }
        self.referenceWeek = referenceWeek
        self.referenceDate = calendar.startOfDay(for: referenceDate)
    }
}

struct PregnancyCalculation: Equatable, Sendable {
    let currentWeek: Int
    let trimester: PregnancyTrimester
    let progress: Double

    /// Week 40 is the first point at which the user can optionally hand off to
    /// Postpartum. The UI copy does not assume that birth has already happened.
    var shouldOfferPostpartumTransition: Bool {
        currentWeek >= 40
    }
}

struct PregnancyTracker {
    static let supportedWeekRange = 1...42

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func calculate(profile: PregnancyProfile, on date: Date = Date()) -> PregnancyCalculation {
        let referenceDate = calendar.startOfDay(for: profile.referenceDate)
        let targetDate = calendar.startOfDay(for: date)
        let elapsedDays = max(
            calendar.dateComponents([.day], from: referenceDate, to: targetDate).day ?? 0,
            0
        )
        let currentWeek = min(
            max(profile.referenceWeek + (elapsedDays / 7), Self.supportedWeekRange.lowerBound),
            Self.supportedWeekRange.upperBound
        )

        return PregnancyCalculation(
            currentWeek: currentWeek,
            trimester: PregnancyTrimester(week: currentWeek),
            progress: min(Double(currentWeek) / 40.0, 1)
        )
    }

    func overviewWeeks(around currentWeek: Int) -> [Int] {
        let clampedWeek = min(
            max(currentWeek, Self.supportedWeekRange.lowerBound),
            Self.supportedWeekRange.upperBound
        )
        let start = min(
            max(clampedWeek - 3, Self.supportedWeekRange.lowerBound),
            Self.supportedWeekRange.upperBound - 7
        )
        return Array(start...(start + 7))
    }
}

struct PregnancyStore {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
    }

    var profile: PregnancyProfile? {
        guard
            defaults.object(forKey: PregnancyPersistenceKeys.referenceWeek) != nil,
            defaults.object(forKey: PregnancyPersistenceKeys.referenceDate) != nil
        else { return nil }

        return PregnancyProfile(
            referenceWeek: defaults.integer(forKey: PregnancyPersistenceKeys.referenceWeek),
            referenceDate: Date(
                timeIntervalSince1970: defaults.double(forKey: PregnancyPersistenceKeys.referenceDate)
            ),
            calendar: calendar
        )
    }

    @discardableResult
    func save(referenceWeek: Int) -> PregnancyProfile? {
        guard let profile = PregnancyProfile(
            referenceWeek: referenceWeek,
            referenceDate: now(),
            calendar: calendar
        ) else { return nil }

        defaults.set(profile.referenceWeek, forKey: PregnancyPersistenceKeys.referenceWeek)
        defaults.set(
            profile.referenceDate.timeIntervalSince1970,
            forKey: PregnancyPersistenceKeys.referenceDate
        )
        defaults.set(true, forKey: PregnancyPersistenceKeys.onboardingCompleted)
        return profile
    }
}
