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
    @State private var revealedCardCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let surfaces: [Color] = [
        AYAColors.cycleHeroSurface,
        AYAColors.pregnancyHeroSurface,
        AYAColors.birthMomentHeroSurface,
        AYAColors.postpartumHeroSurface
    ]

    var body: some View {
        TutorialPreviewContainer {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: AYASpacing.md
            ) {
                ForEach(surfaces.indices, id: \.self) { index in
                    TutorialThemeTile(
                        surface: surfaces[index],
                        motifIndex: index
                    )
                    .opacity(reduceMotion || index < revealedCardCount ? 1 : 0)
                    .offset(y: reduceMotion || index < revealedCardCount ? 0 : AYASpacing.sm)
                }
            }
            .padding(AYASpacing.sm)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onAppear {
            if reduceMotion {
                revealedCardCount = surfaces.count
            } else {
                Task {
                    for count in 1...surfaces.count {
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeInOut(duration: 0.30)) {
                            revealedCardCount = count
                        }
                        try? await Task.sleep(for: .milliseconds(180))
                    }
                }
            }
        }
    }
}

private struct TutorialThemeTile: View {
    let surface: Color
    let motifIndex: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .fill(surface)

            Circle()
                .fill(AYAColors.surface.opacity(0.72))
                .frame(width: 76, height: 76)
                .overlay {
                    motif
                }
                .offset(x: 56, y: -32)

            VStack(alignment: .leading, spacing: AYASpacing.sm) {
                TutorialIllustrationLine(width: 72, height: 9, color: AYAColors.accent.opacity(0.22))
                TutorialIllustrationLine(width: 48, height: 6)
            }
            .padding(AYASpacing.lg)
        }
        .frame(height: 132)
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(AYAColors.separator, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))
    }

    @ViewBuilder
    private var motif: some View {
        switch motifIndex {
        case 0:
            Circle()
                .trim(from: 0.12, to: 0.86)
                .stroke(AYAColors.accent.opacity(0.46), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(-28))
        case 1:
            Capsule()
                .fill(AYAColors.warning.opacity(0.32))
                .frame(width: 16, height: 38)
                .rotationEffect(.degrees(28))
        case 2:
            ZStack {
                Circle().fill(AYAColors.softPink.opacity(0.46)).frame(width: 30, height: 30)
                Circle().fill(AYAColors.surface).frame(width: 13, height: 13)
            }
        default:
            RoundedRectangle(cornerRadius: AYARadius.chip, style: .continuous)
                .fill(AYAColors.accent.opacity(0.28))
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(12))
        }
    }
}

private struct TutorialDailyExperiencePreview: View {
    @State private var revealedSectionCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TutorialPreviewContainer {
            ZStack {
                Circle()
                    .fill(AYAColors.accentSoft.opacity(0.54))
                    .frame(width: 190, height: 190)
                    .blur(radius: 2)
                    .offset(x: 116, y: 116)

                VStack(alignment: .leading, spacing: AYASpacing.lg) {
                    TutorialIllustrationHeading()

                    TutorialInsightIllustration()
                        .opacity(reduceMotion || revealedSectionCount > 0 ? 1 : 0)
                        .offset(y: reduceMotion || revealedSectionCount > 0 ? 0 : AYASpacing.sm)

                    TutorialMeditationIllustration()
                        .opacity(reduceMotion || revealedSectionCount > 1 ? 1 : 0)
                        .offset(y: reduceMotion || revealedSectionCount > 1 ? 0 : AYASpacing.sm)
                }
                .padding(AYASpacing.md)
            }
            .frame(height: 390, alignment: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .task {
            if reduceMotion {
                revealedSectionCount = 2
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
        }
    }
}

private struct TutorialIllustrationHeading: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.sm) {
            TutorialIllustrationLine(width: 136, height: 13, color: AYAColors.textPrimary.opacity(0.14))
            TutorialIllustrationLine(width: 88, height: 7)
        }
    }
}

private struct TutorialInsightIllustration: View {
    var body: some View {
        HStack(spacing: AYASpacing.lg) {
            ZStack {
                Circle()
                    .fill(AYAColors.tertiary.opacity(0.50))
                    .frame(width: 72, height: 72)
                Circle()
                    .stroke(AYAColors.accent.opacity(0.30), lineWidth: 2)
                    .frame(width: 40, height: 40)
                Circle()
                    .fill(AYAColors.accent.opacity(0.42))
                    .frame(width: AYASpacing.sm, height: AYASpacing.sm)
            }

            VStack(alignment: .leading, spacing: AYASpacing.sm) {
                TutorialIllustrationLine(width: 112, height: 9, color: AYAColors.accent.opacity(0.22))
                TutorialIllustrationLine(width: 148, height: 7)
                TutorialIllustrationLine(width: 104, height: 7)
            }
        }
        .padding(AYASpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AYAColors.pregnancyHeroSurface,
            in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
        )
    }
}

private struct TutorialMeditationIllustration: View {
    var body: some View {
        HStack(spacing: AYASpacing.lg) {
            VStack(alignment: .leading, spacing: AYASpacing.sm) {
                TutorialIllustrationLine(width: 94, height: 10, color: AYAColors.textPrimary.opacity(0.14))
                TutorialIllustrationLine(width: 156, height: 7)
                TutorialIllustrationLine(width: 126, height: 7)

                HStack(spacing: AYASpacing.sm) {
                    Capsule().fill(AYAColors.separator).frame(width: 42, height: 6)
                    Circle().fill(AYAColors.accent.opacity(0.22)).frame(width: 6, height: 6)
                    Capsule().fill(AYAColors.separator).frame(width: 54, height: 6)
                }
                .padding(.top, AYASpacing.sm)
            }

            Spacer(minLength: AYASpacing.sm)

            ZStack {
                Circle()
                    .fill(AYAColors.emphasis)
                    .frame(width: 72, height: 72)
                HStack(alignment: .center, spacing: 4) {
                    Capsule().fill(AYAColors.onAccent).frame(width: 3, height: 15)
                    Capsule().fill(AYAColors.onAccent).frame(width: 3, height: 25)
                    Capsule().fill(AYAColors.onAccent).frame(width: 3, height: 18)
                }
            }
        }
        .padding(AYASpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 148)
        .background(
            AYAColors.surfaceElevated,
            in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(AYAColors.separator, lineWidth: 1)
        }
    }
}

private struct TutorialCalendarPreview: View {
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TutorialPreviewContainer {
            VStack(alignment: .leading, spacing: AYASpacing.xl) {
                TutorialIllustrationHeading()

                ZStack {
                    Capsule()
                        .fill(AYAColors.separator)
                        .frame(height: 3)

                    HStack {
                        ForEach(0..<7, id: \.self) { index in
                            Circle()
                                .fill(index == 3 ? AYAColors.emphasis : AYAColors.surface)
                                .frame(
                                    width: index == 3 ? AYASpacing.xxl : AYASpacing.lg,
                                    height: index == 3 ? AYASpacing.xxl : AYASpacing.lg
                                )
                                .overlay {
                                    Circle()
                                        .stroke(
                                            index == 3 ? AYAColors.emphasis : AYAColors.border,
                                            lineWidth: 1
                                        )
                                }

                            if index < 6 {
                                Spacer()
                            }
                        }
                    }
                }

                HStack(spacing: AYASpacing.md) {
                    ForEach(0..<3, id: \.self) { index in
                        VStack(alignment: .leading, spacing: AYASpacing.sm) {
                            Circle()
                                .fill(index == 1 ? AYAColors.accent.opacity(0.26) : AYAColors.separator)
                                .frame(width: AYASpacing.md, height: AYASpacing.md)
                            TutorialIllustrationLine(width: 58, height: 7)
                            TutorialIllustrationLine(width: 42, height: 6)
                        }
                        .padding(AYASpacing.md)
                        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
                        .background(
                            index == 1 ? AYAColors.accentSoft : AYAColors.surface,
                            in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                        )
                    }
                }

                HStack(spacing: AYASpacing.md) {
                    Circle()
                        .fill(AYAColors.tertiary.opacity(0.56))
                        .frame(width: AYASpacing.xxl, height: AYASpacing.xxl)
                    VStack(alignment: .leading, spacing: AYASpacing.sm) {
                        TutorialIllustrationLine(width: 118, height: 8, color: AYAColors.accent.opacity(0.20))
                        TutorialIllustrationLine(width: 176, height: 6)
                    }
                }
                .padding(AYASpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    AYAColors.surface.opacity(0.72),
                    in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                )
            }
            .padding(AYASpacing.md)
            .frame(height: 350)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.985))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TutorialPreviewContainer {
            GeometryReader { geometry in
                ZStack(alignment: .trailing) {
                    VStack(alignment: .leading, spacing: AYASpacing.xl) {
                        HStack {
                            TutorialIllustrationHeading()
                            Spacer()
                            ZStack {
                                Circle().fill(AYAColors.accentSoft).frame(width: 42, height: 42)
                                Circle().fill(AYAColors.accent.opacity(0.28)).frame(width: 15, height: 15)
                            }
                        }

                        RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                            .fill(AYAColors.cycleHeroSurface)
                            .frame(height: 148)

                        HStack(spacing: AYASpacing.md) {
                            ForEach(0..<2, id: \.self) { index in
                                RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                                    .fill(index == 0 ? AYAColors.surface : AYAColors.pregnancyHeroSurface)
                                    .frame(height: 92)
                            }
                        }
                    }
                    .padding(AYASpacing.lg)

                    if showsPanel {
                        TutorialAbstractSettingsPanel()
                        .frame(width: min(284, geometry.size.width * 0.80))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            .frame(height: 390)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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

private struct TutorialAbstractSettingsPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.xl) {
            HStack {
                TutorialIllustrationLine(width: 84, height: 11, color: AYAColors.textPrimary.opacity(0.14))
                Spacer()
                Circle()
                    .fill(AYAColors.separator)
                    .frame(width: AYASpacing.md, height: AYASpacing.md)
            }

            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    HStack(spacing: AYASpacing.md) {
                        Circle()
                            .fill(index == 1 ? AYAColors.accent.opacity(0.28) : AYAColors.separator)
                            .frame(width: AYASpacing.lg, height: AYASpacing.lg)

                        VStack(alignment: .leading, spacing: AYASpacing.xs) {
                            TutorialIllustrationLine(
                                width: index.isMultiple(of: 2) ? 88 : 112,
                                height: 7,
                                color: AYAColors.textPrimary.opacity(0.12)
                            )
                            TutorialIllustrationLine(width: 58, height: 5)
                        }

                        Spacer()

                        Circle()
                            .fill(AYAColors.accent.opacity(index == 1 ? 0.24 : 0.10))
                            .frame(width: AYASpacing.sm, height: AYASpacing.sm)
                    }
                    .padding(.vertical, AYASpacing.md)

                    if index < 4 {
                        Rectangle()
                            .fill(AYAColors.separator)
                            .frame(height: 1)
                    }
                }
            }
        }
        .padding(AYASpacing.xl)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AYAColors.surfaceElevated)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AYAColors.border)
                .frame(width: 1)
        }
        .ayaElevation(.raised)
    }
}

private struct TutorialIllustrationLine: View {
    let width: CGFloat
    let height: CGFloat
    var color: Color = AYAColors.separator

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: height)
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
