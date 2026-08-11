import Foundation

enum PostpartumPersistenceKeys {
    static let birthDate = "postpartum.birthDate"
    static let onboardingCompleted = "postpartum.onboardingCompleted"
}

enum PostpartumStage: String, CaseIterable, Sendable {
    case firstDays
    case earlyPostpartum
    case transition
    case newRhythm

    init(day: Int) {
        switch day {
        case ...7: self = .firstDays
        case 8...42: self = .earlyPostpartum
        case 43...84: self = .transition
        default: self = .newRhythm
        }
    }

    var titleLocalizationKey: String {
        switch self {
        case .firstDays: "postpartum.stage.first_days"
        case .earlyPostpartum: "postpartum.stage.early"
        case .transition: "postpartum.stage.transition"
        case .newRhythm: "postpartum.stage.new_rhythm"
        }
    }

    var headlineLocalizationKey: String {
        "postpartum.stage.\(rawValue).headline"
    }

    var bodyLocalizationKey: String {
        "postpartum.stage.\(rawValue).body"
    }

    var meditationTitleLocalizationKey: String {
        "postpartum.meditation.\(rawValue).title"
    }

    var meditationDescriptionLocalizationKey: String {
        "postpartum.meditation.\(rawValue).description"
    }
}

/// Meditation and content-organization phases for HESIA's first 42-day
/// postpartum journey. These are not medical recovery stages.
enum PostpartumJourneyPhase: String, CaseIterable, Sendable {
    case restAndArrival
    case earlyPostpartum
    case settlingIn
    case rebuildingRhythm

    var dayRange: ClosedRange<Int> {
        switch self {
        case .restAndArrival: 1...7
        case .earlyPostpartum: 8...14
        case .settlingIn: 15...28
        case .rebuildingRhythm: 29...42
        }
    }

    var rangeLocalizationKey: String {
        "postpartum.timeline.phase.\(rawValue).range"
    }

    var titleLocalizationKey: String {
        "postpartum.timeline.phase.\(rawValue).title"
    }

    var descriptionLocalizationKey: String {
        "postpartum.timeline.phase.\(rawValue).description"
    }

    func state(on currentDay: Int) -> PostpartumJourneyPhaseState {
        if currentDay > dayRange.upperBound {
            return .completed
        }
        if dayRange.contains(currentDay) {
            return .current
        }
        return .upcoming
    }

    static func phase(containing day: Int) -> PostpartumJourneyPhase {
        let journeyDay = min(max(day, 1), 42)
        return allCases.first { $0.dayRange.contains(journeyDay) } ?? .rebuildingRhythm
    }
}

enum PostpartumJourneyPhaseState: String, Sendable {
    case completed
    case current
    case upcoming

    var localizationKey: String {
        "postpartum.timeline.state.\(rawValue)"
    }
}

struct PostpartumProfile: Equatable, Sendable {
    let birthDate: Date

    init?(birthDate: Date, calendar: Calendar = .current, now: Date = Date()) {
        let normalizedBirthDate = calendar.startOfDay(for: birthDate)
        guard normalizedBirthDate <= calendar.startOfDay(for: now) else { return nil }
        self.birthDate = normalizedBirthDate
    }
}

struct PostpartumCalculation: Equatable, Sendable {
    let currentDay: Int
    let stage: PostpartumStage
    let progress: Double

    /// The dedicated first-42-days experience remains available; from day 43
    /// onward the user can optionally continue into the Motherhood module.
    var shouldOfferMotherhoodTransition: Bool {
        currentDay > 42
    }
}

struct PostpartumTracker {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func calculate(profile: PostpartumProfile, on date: Date = Date()) -> PostpartumCalculation {
        let start = calendar.startOfDay(for: profile.birthDate)
        let today = calendar.startOfDay(for: date)
        let elapsedDays = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        let day = max(elapsedDays + 1, 1)

        return PostpartumCalculation(
            currentDay: day,
            stage: PostpartumStage(day: day),
            progress: min(max(Double(day) / 42.0, 0), 1)
        )
    }

    func timelineDays(around currentDay: Int) -> [Int] {
        let start = max(currentDay - 3, 1)
        return Array(start...(start + 6))
    }
}

struct PostpartumStore {
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

    var profile: PostpartumProfile? {
        guard defaults.object(forKey: PostpartumPersistenceKeys.birthDate) != nil else { return nil }
        return PostpartumProfile(
            birthDate: Date(timeIntervalSince1970: defaults.double(forKey: PostpartumPersistenceKeys.birthDate)),
            calendar: calendar,
            now: now()
        )
    }

    @discardableResult
    func save(birthDate: Date) -> PostpartumProfile? {
        guard let profile = PostpartumProfile(
            birthDate: birthDate,
            calendar: calendar,
            now: now()
        ) else { return nil }

        defaults.set(profile.birthDate.timeIntervalSince1970, forKey: PostpartumPersistenceKeys.birthDate)
        defaults.set(true, forKey: PostpartumPersistenceKeys.onboardingCompleted)
        return profile
    }
}
