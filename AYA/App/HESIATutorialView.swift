import SwiftUI

private enum HESIATutorialStep: Int, CaseIterable, Identifiable {
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

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if step == .ready {
                TutorialReadyPreview()
                    .id(step)
                    .frame(maxWidth: 600, maxHeight: .infinity)
                    .padding(.horizontal, AYASpacing.xl)
                    .hesiaScreenTransition(reduceMotion: reduceMotion)
            } else {
                ScrollView {
                    VStack(spacing: AYASpacing.xl) {
                        heading
                        stepContent
                            .id(step)
                            .hesiaScreenTransition(reduceMotion: reduceMotion)
                    }
                    .padding(.horizontal, AYASpacing.xl)
                    .padding(.top, AYASpacing.lg)
                    .padding(.bottom, AYASpacing.xxl)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            primaryAction
                .frame(maxWidth: 512)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AYASpacing.xl)
                .padding(.top, AYASpacing.sm)
                .padding(.bottom, AYASpacing.md)
                .background(AYAColors.backgroundPrimary.opacity(0.96))
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

            TutorialProgress(currentStep: step.rawValue, totalSteps: HESIATutorialStep.allCases.count)

            if step == .ready {
                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            } else {
                Button(action: skipTutorial) {
                    Text("onboarding.tutorial.skip")
                        .ayaTypography(.metadata)
                        .foregroundStyle(AYAColors.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.tutorial.skip.button")
            }
        }
        .padding(.horizontal, AYASpacing.xl)
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
            ? "onboarding.tutorial.continue"
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

private struct TutorialPreviewContainer<Content: View>: View {
    private let content: Content
    private let contentPadding: CGFloat

    init(
        contentPadding: CGFloat = AYASpacing.sm,
        @ViewBuilder content: () -> Content
    ) {
        self.contentPadding = contentPadding
        self.content = content()
    }

    var body: some View {
        content
            .padding(contentPadding)
            .frame(maxWidth: .infinity)
            .background(
                AYAColors.backgroundSecondary,
                in: RoundedRectangle(cornerRadius: AYARadius.hero, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.hero, style: .continuous)
                    .stroke(AYAColors.separator, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: AYARadius.hero, style: .continuous))
    }
}

/// A one-shot, decorative touch cue used only inside tutorial previews.
/// It never receives input or mutates the user's persisted state.
private struct TutorialTouchCue: View {
    let delayMilliseconds: Int

    @State private var phase = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(AYAColors.accentSoft)
                .frame(width: AYASpacing.xxl, height: AYASpacing.xxl)

            Circle()
                .fill(AYAColors.accent)
                .frame(width: AYASpacing.sm, height: AYASpacing.sm)
        }
        .scaleEffect(phase == 1 ? 0.78 : 1)
        .opacity(reduceMotion || phase == 0 || phase == 3 ? 0 : 0.9)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                phase = 1
            }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.28)) {
                phase = 2
            }
            try? await Task.sleep(for: .milliseconds(520))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.24)) {
                phase = 3
            }
        }
    }
}

private struct TutorialPrivacyCard: View {
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: AYASpacing.lg) {
            Image(systemName: "lock.shield")
                .font(.system(size: 25, weight: .regular))
                .foregroundStyle(AYAColors.accent)
                .frame(width: 48, height: 48)
                .background(AYAColors.accentSoft, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AYASpacing.sm) {
                Text("onboarding.tutorial.privacy.title")
                    .ayaTypography(.sectionTitle)
                    .foregroundStyle(AYAColors.textPrimary)

                Text("onboarding.tutorial.privacy.description")
                    .ayaTypography(.body)
                    .foregroundStyle(AYAColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

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
        .ayaElevation(.card)
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
    @State private var highlightIsVisible = false
    @State private var revealedCardCount = 0
    @ObservedObject private var premiumStore = PremiumStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TutorialPreviewContainer {
            VStack(spacing: AYASpacing.sm) {
                ForEach(Array(LifeStage.allCases.enumerated()), id: \.offset) { index, stage in
                    LifeStageCardView(
                        stage: stage,
                        isSelected: stage == .cycle && highlightIsVisible,
                        isPremiumUnlocked: premiumStore.hasPremiumAccess,
                        usesCompactMetrics: true,
                        action: {}
                    )
                    .opacity(reduceMotion || index < revealedCardCount ? 1 : 0)
                    .offset(y: reduceMotion || index < revealedCardCount ? 0 : AYASpacing.sm)
                }
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            TutorialTouchCue(delayMilliseconds: 900)
                .padding(.top, AYASpacing.xxxl)
                .padding(.trailing, AYASpacing.xxxl)
        }
        .onAppear {
            if reduceMotion {
                revealedCardCount = LifeStage.allCases.count
                highlightIsVisible = true
            } else {
                Task {
                    for count in 1...LifeStage.allCases.count {
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeInOut(duration: 0.30)) {
                            revealedCardCount = count
                        }
                        try? await Task.sleep(for: .milliseconds(180))
                    }
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(for: .milliseconds(220))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.36)) {
                        highlightIsVisible = true
                    }
                }
            }
        }
    }
}

private struct TutorialDailyExperiencePreview: View {
    @State private var revealedSectionCount = 0
    @State private var showsPlayer = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let profile: CycleProfile
    private let calculation: CycleCalculation
    private let meditation: DailyMeditation

    init() {
        let calendar = Calendar.autoupdatingCurrent
        let startDate = calendar.date(byAdding: .day, value: -17, to: Date()) ?? Date()
        let profile = CycleProfile(
            lastPeriodStartDate: startDate,
            averageCycleLength: 28,
            averagePeriodDuration: 5,
            calendar: calendar
        )!
        let calculation = CycleCalculator(calendar: calendar).calculate(profile: profile)

        self.profile = profile
        self.calculation = calculation
        meditation = DailyMeditationProvider().meditation(
            for: calculation.currentPhase,
            phaseDay: calculation.phaseDay
        )
    }

    var body: some View {
        TutorialPreviewContainer(
            contentPadding: showsPlayer ? 0 : AYASpacing.sm
        ) {
            ZStack {
                if !showsPlayer {
                    dailyHomePreview
                        .transition(.opacity)
                } else {
                    MeditationPlayerView(
                        meditation: meditation,
                        autoPlay: false,
                        presentation: .tutorialPreview
                    )
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.985))
                        )
                }
            }
            .frame(height: 470, alignment: .top)
            .allowsHitTesting(false)
        }
        .task {
            if reduceMotion {
                revealedSectionCount = 2
                try? await Task.sleep(for: .milliseconds(1_480))
                guard !Task.isCancelled else { return }
                showsPlayer = true
                return
            }
            withAnimation(.easeInOut(duration: 0.40)) {
                revealedSectionCount = 1
            }
            try? await Task.sleep(for: .milliseconds(720))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.42)) {
                revealedSectionCount = 2
            }
            try? await Task.sleep(for: .milliseconds(760))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                showsPlayer = true
            }
        }
    }

    private var dailyHomePreview: some View {
        VStack(alignment: .leading, spacing: AYASpacing.lg) {
            CycleSummaryView(
                profile: profile,
                calculation: calculation,
                showInfo: { _ in }
            )
            .opacity(reduceMotion || revealedSectionCount > 0 ? 1 : 0)
            .offset(y: reduceMotion || revealedSectionCount > 0 ? 0 : AYASpacing.sm)

            VStack(alignment: .leading, spacing: AYASpacing.md) {
                SectionHeader("cycle.home.today_meditation")
                DailyMeditationCard(meditation: meditation) {}
                    .overlay(alignment: .bottomTrailing) {
                        TutorialTouchCue(delayMilliseconds: 1_100)
                            .padding(.trailing, AYASpacing.lg)
                            .padding(.bottom, AYASpacing.lg)
                    }
            }
            .opacity(reduceMotion || revealedSectionCount > 1 ? 1 : 0.58)
            .offset(y: reduceMotion || revealedSectionCount > 1 ? 0 : AYASpacing.sm)
        }
    }
}

private struct TutorialCalendarPreview: View {
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let profile: CycleProfile

    init() {
        let calendar = Calendar.autoupdatingCurrent
        let startDate = calendar.date(byAdding: .day, value: -17, to: Date()) ?? Date()
        profile = CycleProfile(
            lastPeriodStartDate: startDate,
            averageCycleLength: 28,
            averagePeriodDuration: 5,
            calendar: calendar
        )!
    }

    var body: some View {
        TutorialPreviewContainer(contentPadding: 0) {
            NavigationStack {
                CycleCalendarView(profile: profile, presentation: .tutorialPreview)
            }
            .frame(height: 412)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.985))
            .allowsHitTesting(false)
            .accessibilityElement(children: .contain)
        }
        .overlay {
            TutorialTouchCue(delayMilliseconds: 880)
                .offset(y: -AYASpacing.xxl)
        }
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.easeInOut(duration: 0.45)) {
                    isVisible = true
                }
            }
        }
    }
}

private struct TutorialSettingsPreview: View {
    @State private var showsPanel = false
    @State private var languageCode = AppLanguage.defaultExplicitLanguage.rawValue
    @State private var userName = "HESIA"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TutorialPreviewContainer {
            GeometryReader { geometry in
                ZStack(alignment: .trailing) {
                    VStack(alignment: .leading, spacing: AYASpacing.xl) {
                        HStack {
                            VStack(alignment: .leading, spacing: AYASpacing.xs) {
                                RoundedRectangle(cornerRadius: AYARadius.chip)
                                    .fill(AYAColors.textPrimary)
                                    .frame(width: 148, height: 18)
                                RoundedRectangle(cornerRadius: AYARadius.chip)
                                    .fill(AYAColors.separator)
                                    .frame(width: 96, height: 10)
                            }
                            Spacer()
                            AYAProfileButton(initial: "H") {}
                        }

                        RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                            .fill(AYAColors.cycleHeroSurface)
                            .frame(height: 150)
                    }
                    .padding(AYASpacing.lg)

                    if showsPanel {
                        SettingsPanel(
                            languageCode: $languageCode,
                            userName: $userName,
                            activeStage: nil,
                            close: {},
                            showThemes: {},
                            editCycle: nil,
                            pregnancyWeek: nil,
                            editPregnancy: nil,
                            editPostpartum: nil,
                            motherhoodRange: nil,
                            editMotherhood: nil,
                            topSafeAreaInset: 0,
                            bottomSafeAreaInset: 0,
                            presentation: .tutorialPreview
                        )
                        .frame(width: min(318, geometry.size.width * 0.92))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .frame(height: 470)
            .allowsHitTesting(false)
        }
        .onAppear {
            if reduceMotion {
                showsPanel = true
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.22)) {
                        showsPanel = true
                    }
                }
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
            .frame(maxWidth: 224)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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

#Preview("Tutorial — Türkçe") {
    HESIATutorialView(context: .firstLaunch) {}
        .environment(\.locale, Locale(identifier: "tr"))
}

#Preview("Tutorial — English") {
    HESIATutorialView(context: .replayFromSettings) {}
        .environment(\.locale, Locale(identifier: "en"))
}
