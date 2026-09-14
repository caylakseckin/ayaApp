import SwiftUI

fileprivate enum HESIATutorialStep: Int, CaseIterable, Identifiable {
    case introduction
    case themes
    case dailyExperience
    case timeline
    case settings
    case ready

    var id: Int { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .introduction: "onboarding.tutorial.introduction.title"
        case .themes: "onboarding.tutorial.themes.title"
        case .dailyExperience: "onboarding.tutorial.daily.title"
        case .timeline: "onboarding.tutorial.timeline.title"
        case .settings: "onboarding.tutorial.settings.title"
        case .ready: "onboarding.tutorial.ready.title"
        }
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .introduction: "onboarding.tutorial.introduction.description"
        case .themes: "onboarding.tutorial.themes.description"
        case .dailyExperience: "onboarding.tutorial.daily.description"
        case .timeline: "onboarding.tutorial.timeline.description"
        case .settings: "onboarding.tutorial.settings.description"
        case .ready: "onboarding.tutorial.ready.description"
        }
    }
}

struct HESIATutorialView: View {
    let context: HESIATutorialPresentationContext
    let completion: () -> Void

    @State private var step: HESIATutorialStep = .introduction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(context: HESIATutorialPresentationContext, completion: @escaping () -> Void) {
        self.init(context: context, initialStep: .introduction, completion: completion)
    }

    fileprivate init(
        context: HESIATutorialPresentationContext,
        initialStep: HESIATutorialStep,
        completion: @escaping () -> Void
    ) {
        self.context = context
        self.completion = completion
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: AYASpacing.xl) {
                        if step != .ready {
                            heading
                        }
                        stepContent
                            .id(step)
                            .hesiaScreenTransition(reduceMotion: reduceMotion)
                    }
                    .hesiaScreenPadding()
                    .padding(.top, AYASpacing.xl)
                    .padding(.bottom, AYASpacing.xxxl)
                    .frame(maxWidth: 600)
                    // Center short pages in the space between navigation and
                    // CTA; taller text keeps its natural height and scrolls.
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
                .id(step)
            }

        }
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            primaryAction
                .hesiaBottomBar()
        }
        .hesiaScreenAnimation(reduceMotion: reduceMotion, value: step)
    }

    private var topBar: some View {
        HStack(spacing: AYASpacing.md) {
            if step == .introduction {
                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            } else {
                Button(action: previousStep) {
                    HesiaIcon.caretLeft.view(size: 17)
                        .foregroundStyle(AYAColors.emphasis)
                        .frame(width: 44, height: 44)
                        .background(AYAColors.surface, in: Circle())
                        .overlay { Circle().stroke(AYAColors.border, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("onboarding.tutorial.back")
                .accessibilityIdentifier("onboarding.tutorial.back.button")
            }

            VStack(spacing: AYASpacing.sm) {
                Text("onboarding.tutorial.eyebrow")
                    .ayaTypography(.metadata)
                    .foregroundStyle(AYAColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                TutorialProgress(currentStep: step.rawValue, totalSteps: HESIATutorialStep.allCases.count)
            }
            .frame(maxWidth: .infinity)

            if step == .ready {
                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            } else {
                Button(action: skipTutorial) {
                    Text("onboarding.tutorial.skip")
                        .ayaTypography(.metadata)
                        .foregroundStyle(AYAColors.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.tutorial.skip.button")
            }
        }
        .hesiaScreenPadding()
        .padding(.top, AYASpacing.sm)
    }

    private var heading: some View {
        VStack(spacing: AYASpacing.sm) {
            Text(step.titleKey)
                .ayaTypography(.screenTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(step.descriptionKey)
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .introduction:
            TutorialPrivacyCard()
        case .themes:
            TutorialThemePreview()
        case .dailyExperience:
            TutorialDailyExperiencePreview()
        case .timeline:
            TutorialCalendarPreview()
        case .settings:
            TutorialSettingsPreview()
        case .ready:
            TutorialReadyPreview()
        }
    }

    private var primaryAction: some View {
        Button(action: nextStep) {
            Text(primaryActionKey)
        }
        .buttonStyle(.appPrimary)
        .accessibilityIdentifier("onboarding.tutorial.primary.button")
    }

    private var primaryActionKey: LocalizedStringKey {
        guard step == .ready else { return "onboarding.tutorial.next" }
        return context.completesFirstLaunch
            ? "onboarding.tutorial.start"
            : "onboarding.tutorial.done"
    }

    private func previousStep() {
        guard let previous = HESIATutorialStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    private func nextStep() {
        if let next = HESIATutorialStep(rawValue: step.rawValue + 1) {
            step = next
        } else {
            completion()
        }
    }

    private func skipTutorial() {
        completion()
    }
}

private struct TutorialProgress: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: AYASpacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? AYAColors.accent : AYAColors.separator)
                    .frame(width: index == currentStep ? 18 : 6, height: 6)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("onboarding.tutorial.progress")
        .accessibilityValue("\(currentStep + 1) / \(totalSteps)")
    }
}

/// Demonstration-only product content: never starts playback, fetches data,
/// changes preferences, or appears as interactive controls to VoiceOver.
private struct TutorialFeaturePreview<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(AYASpacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                AYAColors.backgroundSecondary,
                in: RoundedRectangle(cornerRadius: AYARadius.hero, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.hero, style: .continuous)
                    .stroke(AYAColors.border, lineWidth: 1)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct TutorialPrivacyCard: View {
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.lg) {
            VStack(alignment: .leading, spacing: AYASpacing.sm) {
                HStack(spacing: AYASpacing.sm) {
                    HesiaIcon.lock.view(size: 17)
                        .foregroundStyle(AYAColors.accent)
                        .accessibilityHidden(true)

                    Text("onboarding.tutorial.privacy.title")
                        .ayaTypography(.sectionTitle)
                        .foregroundStyle(AYAColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("onboarding.tutorial.privacy.description")
                    .ayaTypography(.body)
                    .foregroundStyle(AYAColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(AYAColors.separator)
                .frame(height: 1)
                .accessibilityHidden(true)

            HStack(alignment: .top, spacing: AYASpacing.sm) {
                HesiaIcon.info.view(size: 15)
                    .foregroundStyle(AYAColors.textTertiary)
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)

                Text("onboarding.tutorial.privacy.network_note")
                    .ayaTypography(.metadata)
                    .foregroundStyle(AYAColors.textTertiary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AYASpacing.xl)
        .background(
            AYAColors.surfaceElevated,
            in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(AYAColors.separator, lineWidth: 1)
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: reduceMotion ? 0 : (isVisible ? 0 : AYASpacing.sm))
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
                isVisible = true
            }
        }
    }
}

private struct TutorialThemePreview: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let stages: [LifeStage] = [.cycle, .pregnancy, .birthMoment, .postpartum]

    var body: some View {
        TutorialFeaturePreview {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible()),
                    count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                ),
                spacing: AYASpacing.md
            ) {
                ForEach(stages) { stage in
                    VStack(spacing: AYASpacing.sm) {
                        Image(asset(for: stage))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: AYARadius.control))
                        Text(stage.titleKey)
                            .ayaTypography(.metadata)
                            .foregroundStyle(AYAColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(AYASpacing.md)
                    .background(AYAColors.surfaceElevated,
                                in: RoundedRectangle(cornerRadius: AYARadius.card))
                }
            }
        }
    }

    private func asset(for stage: LifeStage) -> String {
        switch stage {
        case .cycle: "LifeStageIconCycle"
        case .pregnancy: "LifeStageIconPregnancy"
        case .birthMoment: "LifeStageIconBirthMoment"
        case .postpartum, .motherhood03: "LifeStageIconPostpartum"
        }
    }
}

private struct TutorialDailyExperiencePreview: View {
    var body: some View {
        TutorialFeaturePreview {
            DailyMeditationCard(
                meditation: DailyMeditationProvider().meditation(for: .menstrual, phaseDay: 1)
            ) {}
        }
    }
}

private struct TutorialCalendarPreview: View {
    var body: some View {
        TutorialFeaturePreview {
            VStack(alignment: .leading, spacing: AYASpacing.xl) {
                Text("onboarding.tutorial.preview.week")
                    .ayaTypography(.homeSectionHeading)
                    .foregroundStyle(AYAColors.textPrimary)

                LifeStageHorizontalTimeline(
                    values: Array(18...22),
                    currentValue: 20,
                    accessibilityLabelKey: "onboarding.tutorial.preview.week",
                    activeColor: AYAColors.emphasis,
                    fillsAvailableWidth: true
                )
                // These are decorative fixed-size markers, like the product's
                // timeline; surrounding text continues to scale normally.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

                Label {
                    Text("onboarding.tutorial.preview.current_week")
                        .ayaTypography(.body)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    HesiaIcon.calendar.view(size: HesiaIconSize.md)
                }
                .foregroundStyle(AYAColors.textSecondary)
            }
            .padding(AYASpacing.lg)
            .background(AYAColors.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: AYARadius.card))
        }
    }
}

private struct TutorialSettingsPreview: View {
    var body: some View {
        TutorialFeaturePreview {
            SettingsGroup {
                SettingsNavigationRow(
                    icon: SettingsRowIcon(.globe),
                    titleKey: "settings.language"
                ) {}
                SettingsRowSeparator()
                SettingsNavigationRow(
                    icon: SettingsRowIcon(.notification),
                    titleKey: "reminder.section"
                ) {}
                SettingsRowSeparator()
                SettingsNavigationRow(
                    icon: SettingsRowIcon(.themes),
                    titleKey: "settings.themes"
                ) {}
            }
        }
    }
}

private struct TutorialReadyPreview: View {
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Image("HESIA_enso_background_asset")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320)
                .opacity(0.24)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: AYASpacing.sm) {
                Text("onboarding.tutorial.ready.title")
                    .ayaTypography(.screenTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text("onboarding.tutorial.ready.description")
                    .ayaTypography(.body)
                    .foregroundStyle(AYAColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AYASpacing.xl)
        }
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.985))
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.easeInOut(duration: 0.48)) {
                    isVisible = true
                }
            }
        }
    }
}

// Preview every step without changing first-launch persistence or app settings.
private struct TutorialPreviewGallery: View {
    let language: String
    let size: CGSize
    var dynamicTypeSize: DynamicTypeSize = .large

    private var defaults: UserDefaults {
        let defaults = UserDefaults(suiteName: "HESIA.TutorialPreview.\(language)")!
        defaults.set(language, forKey: "app.language")
        return defaults
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: AYASpacing.xl) {
                ForEach(HESIATutorialStep.allCases) { step in
                    HESIATutorialView(context: .firstLaunch, initialStep: step) {}
                        .environment(\.locale, Locale(identifier: language))
                        .environment(\.dynamicTypeSize, dynamicTypeSize)
                        .defaultAppStorage(defaults)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                }
            }
        }
    }
}

#Preview("TR · All steps · 393") {
    TutorialPreviewGallery(language: "tr", size: CGSize(width: 393, height: 759))
}

#Preview("EN · All steps · 393 · Dark") {
    TutorialPreviewGallery(language: "en", size: CGSize(width: 393, height: 759))
        .preferredColorScheme(.dark)
}

#Preview("TR · All steps · Small iPhone") {
    TutorialPreviewGallery(language: "tr", size: CGSize(width: 375, height: 647))
}

#Preview("EN · All steps · Small iPhone") {
    TutorialPreviewGallery(language: "en", size: CGSize(width: 375, height: 647))
}

#Preview("TR · Accessibility · Small iPhone") {
    TutorialPreviewGallery(language: "tr", size: CGSize(width: 375, height: 647),
                           dynamicTypeSize: .accessibility3)
}

#Preview("EN · Accessibility · Small iPhone · Dark") {
    TutorialPreviewGallery(language: "en", size: CGSize(width: 375, height: 647),
                           dynamicTypeSize: .accessibility3)
        .preferredColorScheme(.dark)
}
