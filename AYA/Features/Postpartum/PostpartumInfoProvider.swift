struct PostpartumInfoProvider {
    static func content(for stage: PostpartumStage) -> ContextualInfoContent {
        ContextualInfoContent(
            id: "postpartum.\(stage.rawValue)",
            titleKey: "info.postpartum.title",
            introductionKey: "info.postpartum.description",
            sections: [
                ContextualInfoSection(
                    titleKey: "info.common.in_this_period",
                    itemKeys: (1...4).map { "info.postpartum.highlight.\($0)" }
                )
            ],
            hesiaExplanationKey: "info.postpartum.hesia",
            disclaimerKey: "info.postpartum.disclaimer",
            accessibilityLabelKey: "info.postpartum.accessibility"
        )
    }
}
