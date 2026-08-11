import SwiftUI

enum CyclePhase: String, CaseIterable, Identifiable, Sendable {
    case menstrual
    case follicular
    case ovulatory
    case luteal

    var id: String { rawValue }

    var nameLocalizationKey: String {
        switch self {
        case .menstrual: "cycle.phase.menstrual"
        case .follicular: "cycle.phase.follicular"
        case .ovulatory: "cycle.phase.ovulatory"
        case .luteal: "cycle.phase.luteal"
        }
    }

    var nameKey: LocalizedStringKey {
        LocalizedStringKey(nameLocalizationKey)
    }

    var meditationContextNameLocalizationKey: String {
        switch self {
        case .menstrual: "cycle.phase.menstrual.meditation_context"
        case .follicular: "cycle.phase.follicular.meditation_context"
        case .ovulatory: "cycle.phase.ovulatory.meditation_context"
        case .luteal: "cycle.phase.luteal.meditation_context"
        }
    }

    var insightTitleLocalizationKey: String {
        switch self {
        case .menstrual: "cycle.phase.menstrual.insight.title"
        case .follicular: "cycle.phase.follicular.insight.title"
        case .ovulatory: "cycle.phase.ovulatory.insight.title"
        case .luteal: "cycle.phase.luteal.insight.title"
        }
    }

    var insightDescriptionLocalizationKey: String {
        switch self {
        case .menstrual: "cycle.phase.menstrual.insight.description"
        case .follicular: "cycle.phase.follicular.insight.description"
        case .ovulatory: "cycle.phase.ovulatory.insight.description"
        case .luteal: "cycle.phase.luteal.insight.description"
        }
    }

    var calendarHelperLocalizationKey: String {
        "cycle.calendar.phase_helper.\(rawValue)"
    }

    var insightTitleKey: LocalizedStringKey {
        LocalizedStringKey(insightTitleLocalizationKey)
    }

    var insightDescriptionKey: LocalizedStringKey {
        LocalizedStringKey(insightDescriptionLocalizationKey)
    }
}
