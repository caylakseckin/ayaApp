import Foundation

enum MotherhoodPersistenceKeys {
    static let ageRange = "motherhood.ageRange"
    static let onboardingCompleted = "motherhood.onboardingCompleted"
}

enum MotherhoodAgeRange: String, CaseIterable, Identifiable, Sendable {
    case infant
    case toddler
    case preschool
    case schoolAge

    var id: String { rawValue }

    var titleLocalizationKey: String {
        "motherhood.range.\(rawValue)"
    }

    var shortTitleLocalizationKey: String {
        "motherhood.range.\(rawValue).short"
    }

    var detailSubtitleLocalizationKey: String {
        "motherhood.detail.subtitle.\(rawValue)"
    }

    var badgeLocalizationKey: String {
        "motherhood.detail.badge.\(rawValue)"
    }

    var insightTitleLocalizationKey: String {
        "motherhood.detail.insightTitle.\(rawValue)"
    }

    var insightBodyLocalizationKey: String {
        "motherhood.detail.insightBody.\(rawValue)"
    }

    var meditationTitleLocalizationKey: String {
        "motherhood.meditation.title.\(rawValue)"
    }

    var meditationDescriptionLocalizationKey: String {
        "motherhood.meditation.description.\(rawValue)"
    }

    var meditationContextLocalizationKey: String {
        "motherhood.meditation.context.\(rawValue)"
    }

    var journeyTitleLocalizationKey: String {
        "motherhood.journey.stage.\(rawValue).title"
    }

    var journeyDescriptionLocalizationKey: String {
        "motherhood.journey.stage.\(rawValue).description"
    }

    var journeyFocusLocalizationKey: String {
        "motherhood.journey.stage.\(rawValue).focus"
    }

    var journeySummaryDescriptionLocalizationKey: String {
        switch self {
        case .infant:
            "motherhood.journey.summary.infant"
        case .toddler, .preschool, .schoolAge:
            journeyDescriptionLocalizationKey
        }
    }

    var progress: Double {
        guard let index = Self.allCases.firstIndex(of: self) else { return 0 }
        return Double(index + 1) / Double(Self.allCases.count)
    }
}

struct MotherhoodStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedRange: MotherhoodAgeRange? {
        guard let rawValue = defaults.string(forKey: MotherhoodPersistenceKeys.ageRange) else {
            return nil
        }
        return MotherhoodAgeRange(rawValue: rawValue)
    }

    func save(_ range: MotherhoodAgeRange) {
        defaults.set(range.rawValue, forKey: MotherhoodPersistenceKeys.ageRange)
        defaults.set(true, forKey: MotherhoodPersistenceKeys.onboardingCompleted)
    }
}
