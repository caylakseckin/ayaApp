import SwiftUI

enum LifeStagePersistenceKeys {
    static let activeStage = "life_stage.active"
}

enum LifeStage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case cycle
    case pregnancy
    case postpartum
    case motherhood03

    var id: String { rawValue }

    var isPremium: Bool { self != .cycle }

    var titleKey: LocalizedStringKey {
        switch self {
        case .cycle: "life_stage.cycle.title"
        case .pregnancy: "life_stage.pregnancy.title"
        case .postpartum: "life_stage.postpartum.title"
        case .motherhood03: "life_stage.motherhood03.title"
        }
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .cycle: "life_stage.cycle.description"
        case .pregnancy: "life_stage.pregnancy.description"
        case .postpartum: "life_stage.postpartum.description"
        case .motherhood03: "life_stage.motherhood03.description"
        }
    }

    var badgeKey: LocalizedStringKey {
        switch self {
        case .cycle: "life_stage.cycle.badge"
        case .pregnancy: "life_stage.pregnancy.badge"
        case .postpartum: "life_stage.postpartum.badge"
        case .motherhood03: "life_stage.motherhood03.badge"
        }
    }

    var actionKey: LocalizedStringKey {
        switch self {
        case .cycle: "life_stage.cycle.action"
        case .pregnancy: "life_stage.pregnancy.action"
        case .postpartum: "life_stage.postpartum.action"
        case .motherhood03: "life_stage.motherhood03.action"
        }
    }

    var localizationKeys: [String] {
        let prefix = "life_stage.\(rawValue)"
        return ["\(prefix).title", "\(prefix).description", "\(prefix).badge", "\(prefix).action"]
    }
}
