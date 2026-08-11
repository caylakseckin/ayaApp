enum MotherhoodInfoTopic: String, Sendable {
    case mentalLoad = "mental_load"
    case makingSpace = "making_space"
    case fatigue
    case guilt
}

struct MotherhoodInfoProvider {
    static func topic(for range: MotherhoodAgeRange) -> MotherhoodInfoTopic {
        switch range {
        case .infant: .makingSpace
        case .toddler: .mentalLoad
        case .preschool: .fatigue
        case .schoolAge: .guilt
        }
    }

    static func content(for range: MotherhoodAgeRange) -> ContextualInfoContent {
        content(for: topic(for: range))
    }

    static func content(for topic: MotherhoodInfoTopic) -> ContextualInfoContent {
        let prefix = "info.motherhood.\(topic.rawValue)"
        let highlights = topic == .mentalLoad
            ? [ContextualInfoSection(
                titleKey: "info.motherhood.you_may_feel",
                itemKeys: (1...3).map { "\(prefix).highlight.\($0)" }
            )]
            : []

        return ContextualInfoContent(
            id: "motherhood.\(topic.rawValue)",
            titleKey: "\(prefix).title",
            introductionKey: "\(prefix).description",
            sections: highlights,
            hesiaExplanationKey: "\(prefix).hesia",
            accessibilityLabelKey: "\(prefix).accessibility"
        )
    }
}
