import Foundation

enum PregnancyPersistenceKeys {
    static let referenceWeek = "pregnancy.referenceWeek"
    static let referenceDate = "pregnancy.referenceDate"
    static let onboardingCompleted = "pregnancy.onboardingCompleted"
}

enum PregnancyWeekStartDay: Int, CaseIterable, Identifiable, Sendable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    var id: Int { rawValue }

    func shortName(locale: Locale) -> String {
        symbols(locale: locale, abbreviated: true)[rawValue - 1]
    }

    func fullName(locale: Locale) -> String {
        symbols(locale: locale, abbreviated: false)[rawValue - 1]
    }

    private func symbols(locale: Locale, abbreviated: Bool) -> [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return abbreviated
            ? calendar.shortStandaloneWeekdaySymbols
            : calendar.standaloneWeekdaySymbols
    }
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
        case .first: PregnancyTracker.supportedWeekRange.lowerBound...13
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
        guard PregnancyTracker.legacyReferenceWeekRange.contains(referenceWeek) else { return nil }
        self.referenceWeek = referenceWeek
        self.referenceDate = calendar.startOfDay(for: referenceDate)
    }
}

struct PregnancyCalculation: Equatable, Sendable {
    let currentWeek: Int
    let trimester: PregnancyTrimester
    let progress: Double

    /// Week 40 is the first point at which the user can optionally hand off to
    /// Birth Moment. The UI copy does not assume that birth has already happened.
    var shouldOfferBirthMomentTransition: Bool {
        currentWeek >= 40
    }
}

struct PregnancyTracker {
    /// Weeks presented throughout the current pregnancy experience.
    static let supportedWeekRange = 4...42
    /// Keeps previously stored week 1–3 profiles calculable while new input starts at week 4.
    static let legacyReferenceWeekRange = 1...42

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

    func referenceDate(
        for weekStartDay: PregnancyWeekStartDay,
        on date: Date = Date()
    ) -> Date {
        let today = calendar.startOfDay(for: date)
        let currentWeekday = calendar.component(.weekday, from: today)
        let elapsedDaysSinceStart = (currentWeekday - weekStartDay.rawValue + 7) % 7
        return calendar.date(byAdding: .day, value: -elapsedDaysSinceStart, to: today) ?? today
    }

    func weekStartDay(for referenceDate: Date) -> PregnancyWeekStartDay {
        PregnancyWeekStartDay(
            rawValue: calendar.component(.weekday, from: referenceDate)
        ) ?? .monday
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
    func save(
        referenceWeek: Int,
        weekStartDay: PregnancyWeekStartDay
    ) -> PregnancyProfile? {
        guard PregnancyTracker.supportedWeekRange.contains(referenceWeek) else { return nil }
        let referenceDate = PregnancyTracker(calendar: calendar).referenceDate(
            for: weekStartDay,
            on: now()
        )
        guard let profile = PregnancyProfile(
            referenceWeek: referenceWeek,
            referenceDate: referenceDate,
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
