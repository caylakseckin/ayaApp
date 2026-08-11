struct CycleInfoProvider {
    static func content(for phase: CyclePhase) -> ContextualInfoContent {
        let prefix = "info.cycle.\(phase.rawValue)"
        return ContextualInfoContent(
            id: "cycle.\(phase.rawValue)",
            titleKey: "\(prefix).title",
            introductionKey: "\(prefix).description",
            sections: [
                ContextualInfoSection(
                    titleKey: "info.common.in_this_period",
                    itemKeys: (1...3).map { "\(prefix).highlight.\($0)" }
                )
            ],
            hesiaExplanationKey: "\(prefix).hesia",
            accessibilityLabelKey: "\(prefix).accessibility"
        )
    }
}
