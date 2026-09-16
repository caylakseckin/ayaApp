import SwiftUI
import StoreKit

struct LifeStageSelectionView: View {
    @StateObject private var viewModel: LifeStageSelectionViewModel
    @ObservedObject private var premiumStore = PremiumStore.shared
    @State private var navigationPath: [LifeStage] = []
    @State private var premiumStage: LifeStage?
    @State private var pendingEntitlementStage: LifeStage?
    @State private var focusedStage: LifeStage?
    @State private var selectionFeedbackTrigger = 0
    @State private var carouselNudgeOffset: CGFloat = 0
    @AppStorage("life_stage.selection.hasShownSwipeNudge") private var hasShownSwipeNudge = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let onStageSelected: ((LifeStage) -> Void)?

    init(
        initialSelection: LifeStage = .cycle,
        onStageSelected: ((LifeStage) -> Void)? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: LifeStageSelectionViewModel(selectedStage: initialSelection)
        )
        _focusedStage = State(initialValue: initialSelection)
        self.onStageSelected = onStageSelected
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            selectionContent
                .navigationDestination(for: LifeStage.self) { stage in
                    if stage == .cycle {
                        CycleDestinationView()
                    } else if stage == .pregnancy {
                        PregnancyDestinationView()
                    } else if stage == .birthMoment {
                        BirthMomentDestinationView()
                    } else if stage == .postpartum {
                        PostpartumDestinationView()
                    } else if stage == .motherhood03 {
                        MotherhoodDestinationView()
                    } else {
                        LifeStagePlaceholderView(stage: stage)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .hesiaInteractivePopGesture()
    }

    private var selectionContent: some View {
        GeometryReader { geometry in
            let usesCompactMetrics = geometry.size.height < 730
            VStack(spacing: 0) {
                header(usesCompactMetrics: usesCompactMetrics)
                    .padding(.horizontal, AYALayout.screenHorizontalPadding)
                    .padding(.top, usesCompactMetrics ? AYASpacing.md : AYASpacing.lg)
                    .padding(.bottom, usesCompactMetrics ? AYASpacing.md : AYASpacing.xl)

                GeometryReader { carouselGeometry in
                    let stages = LifeStage.availableCases
                    let cardWidth = min(
                        AYALayout.readableContentMaxWidth - (AYASpacing.xl * 2),
                        carouselGeometry.size.width * 0.78
                    )
                    let cardHeight = min(
                        AYALayout.readableContentMaxWidth * 0.66,
                        carouselGeometry.size.height * 0.78
                    )
                    let leadingInset = (carouselGeometry.size.width - cardWidth) / 2

                    VStack(spacing: AYASpacing.xl) {
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: AYASpacing.md) {
                                ForEach(stages) { stage in
                                    LifeStageCarouselCard(
                                        stage: stage,
                                        isFocused: focusedStage == stage,
                                        isPremiumUnlocked: premiumStore.hasPremiumAccess,
                                        usesCompactMetrics: usesCompactMetrics,
                                        action: { select(stage) }
                                    )
                                    .frame(width: cardWidth, height: cardHeight)
                                    .id(stage)
                                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                        content
                                            .scaleEffect(reduceMotion || phase.isIdentity ? 1 : 0.965)
                                            .opacity(reduceMotion || phase.isIdentity ? 1 : 0.78)
                                    }
                                }
                            }
                            .scrollTargetLayout()
                            .offset(x: carouselNudgeOffset)
                        }
                        .frame(height: cardHeight)
                        .contentMargins(.horizontal, leadingInset, for: .scrollContent)
                        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                        .scrollPosition(id: $focusedStage, anchor: .center)
                        .scrollIndicators(.hidden)
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.58, dampingFraction: 0.9),
                            value: focusedStage
                        )
                        .accessibilityAdjustableAction { direction in
                            let focusedIndex = stages.firstIndex(of: focusedStage ?? viewModel.selectedStage) ?? 0
                            focusStage(at: focusedIndex + (direction == .increment ? 1 : -1))
                        }

                        LifeStagePageIndicator(
                            stages: stages,
                            focusedStage: focusedStage ?? viewModel.selectedStage
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .padding(.bottom, usesCompactMetrics ? AYASpacing.sm : AYASpacing.lg)
            .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        }
        .sheet(item: $premiumStage) { stage in
            PremiumPaywallView(stage: stage) {
                premiumStage = nil
                completeSelection(stage)
            }
        }
        .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
        .sensoryFeedback(.selection, trigger: focusedStage)
        .task {
            await premiumStore.prepare()
        }
        .task {
            await playSwipeNudgeIfNeeded()
        }
        .task(id: pendingEntitlementStage) {
            guard let stage = pendingEntitlementStage else { return }
            await premiumStore.prepare()
            guard !Task.isCancelled, pendingEntitlementStage == stage else { return }
            pendingEntitlementStage = nil
            selectResolved(stage)
        }
    }

    private func select(_ stage: LifeStage) {
        if stage.isPremium, !premiumStore.hasResolvedEntitlements {
            guard pendingEntitlementStage == nil else { return }
            pendingEntitlementStage = stage
            return
        }

        selectResolved(stage)
    }

    private func focusStage(at index: Int) {
        let stages = LifeStage.availableCases
        guard !stages.isEmpty else { return }
        focusedStage = stages[min(max(index, 0), stages.count - 1)]
    }

    @MainActor
    private func playSwipeNudgeIfNeeded() async {
        guard !hasShownSwipeNudge else { return }

        if reduceMotion {
            hasShownSwipeNudge = true
            return
        }

        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled, !hasShownSwipeNudge else { return }
        hasShownSwipeNudge = true

        withAnimation(.easeOut(duration: 0.16)) {
            carouselNudgeOffset = -26
        }
        try? await Task.sleep(for: .milliseconds(160))
        guard !Task.isCancelled else {
            carouselNudgeOffset = 0
            return
        }
        withAnimation(.easeInOut(duration: 0.20)) {
            carouselNudgeOffset = 0
        }
    }

    private func selectResolved(_ stage: LifeStage) {
        if !PremiumAccessPolicy.hasAccess(
            to: stage,
            entitlementsResolved: premiumStore.hasResolvedEntitlements,
            hasPremiumAccess: premiumStore.hasPremiumAccess
        ) {
            premiumStage = stage
            return
        }

        completeSelection(stage)
    }

    private func completeSelection(_ stage: LifeStage) {
        selectionFeedbackTrigger += 1
        viewModel.select(stage)
        if let onStageSelected {
            onStageSelected(stage)
        } else {
            navigationPath.append(stage)
        }
    }

    private func header(usesCompactMetrics: Bool) -> some View {
        VStack(spacing: AYASpacing.sm) {
            Text("life_stage.title")
                .ayaTypography(.screenTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .tracking(-0.5)
                .lineSpacing(-4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if !usesCompactMetrics {
                Text("life_stage.subtitle")
                    .ayaTypography(.body)
                    .foregroundStyle(AYAColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: AYALayout.readableContentMaxWidth)
        .frame(maxWidth: .infinity)
    }

}

private struct LifeStageCarouselCard: View {
    let stage: LifeStage
    let isFocused: Bool
    let isPremiumUnlocked: Bool
    let usesCompactMetrics: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var theme: LifeStageTheme { .theme(for: stage) }
    private var showsPremiumBadge: Bool { stage.isPremium && !isPremiumUnlocked }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                LifeStagePatternHeader(
                    stage: stage,
                    showsPremiumBadge: showsPremiumBadge,
                    usesCompactMetrics: usesCompactMetrics
                )
                .frame(height: geometry.size.height * (usesCompactMetrics ? 0.36 : 0.40))

                VStack(spacing: AYASpacing.md) {
                    VStack(spacing: AYASpacing.sm) {
                        Text(stage.titleKey)
                            .ayaTypography(.stageCardTitle)
                            .foregroundStyle(AYAColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            .minimumScaleFactor(0.9)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(stage.descriptionKey)
                            .ayaTypography(.body)
                            .foregroundStyle(AYAColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 300)

                    Spacer(minLength: AYASpacing.sm)

                    Button(action: action) {
                        Text(stage.actionKey)
                            .ayaTypography(.button)
                            .foregroundStyle(
                                stage == .cycle && colorScheme == .light
                                    ? AYAColors.secondary
                                    : AYAColors.onAccent
                            )
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                theme.accentColor(for: colorScheme),
                                in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("life_stage.card.\(stage.rawValue)")
                    .accessibilityLabel(stage.titleKey)
                    .accessibilityHint(stage.descriptionKey)
                    .accessibilityAddTraits(isFocused ? .isSelected : [])
                }
                .padding(usesCompactMetrics ? AYASpacing.lg : AYASpacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AYAColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: AYARadius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.hero, style: .continuous)
                .stroke(
                    isFocused
                        ? theme.accentColor(for: colorScheme).opacity(0.24)
                        : theme.borderColor(for: colorScheme).opacity(0.72),
                    lineWidth: 1
                )
        }
        .ayaCardShadow()
    }

}

private struct LifeStagePatternHeader: View {
    let stage: LifeStage
    let showsPremiumBadge: Bool
    let usesCompactMetrics: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            patternBackground

            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(
                    width: usesCompactMetrics ? 94 : 112,
                    height: usesCompactMetrics ? 94 : 112
                )
                // The supplied files include outer canvas; compensate without
                // changing the card's established illustration frame.
                .scaleEffect(1.36)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: usesCompactMetrics ? 24 : 28,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            if showsPremiumBadge {
                Text(stage.badgeKey)
                    .ayaTypography(.badge)
                    .foregroundStyle(patternForeground)
                    .padding(.horizontal, AYASpacing.md)
                    .frame(height: 28)
                    .background(patternForeground.opacity(0.16), in: Capsule())
                    .padding(usesCompactMetrics ? AYASpacing.md : AYASpacing.lg)
            }
        }
    }

    private var patternBackground: Color {
        switch stage {
        case .cycle: AYAColors.softPink
        case .pregnancy: AYAColors.pregnancySurface
        case .birthMoment: AYAColors.secondary
        case .postpartum: AYAColors.postpartumSurface
        case .motherhood03: AYAColors.motherhoodSurface
        }
    }

    private var patternForeground: Color {
        switch stage {
        case .birthMoment:
            return colorScheme == .dark ? AYAColors.onAccent : AYAColors.surface
        case .cycle, .pregnancy, .postpartum, .motherhood03:
            return colorScheme == .dark ? AYAColors.textPrimary : AYAColors.secondary
        }
    }

    private var assetName: String {
        switch stage {
        case .cycle: "LifeStageIconCycle"
        case .pregnancy: "LifeStageIconPregnancy"
        case .birthMoment: "LifeStageIconBirthMoment"
        case .postpartum: "LifeStageIconPostpartum"
        case .motherhood03: "LifeStageIconPostpartum"
        }
    }
}

private struct LifeStagePageIndicator: View {
    let stages: [LifeStage]
    let focusedStage: LifeStage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: AYASpacing.sm) {
            ForEach(stages) { stage in
                Capsule()
                    .fill(stage == focusedStage ? activeColor : AYAColors.textTertiary.opacity(0.28))
                    .frame(width: stage == focusedStage ? 18 : 6, height: 6)
            }
        }
        .frame(height: 18)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: focusedStage)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("life_stage.page_indicator")
        .accessibilityLabel(focusedStage.titleKey)
        .accessibilityValue(pageValue)
    }

    private var activeColor: Color {
        LifeStageTheme.theme(for: focusedStage).accentColor(for: colorScheme)
    }

    private var pageValue: Text {
        let index = stages.firstIndex(of: focusedStage).map { $0 + 1 } ?? 1
        return Text(verbatim: "\(index) / \(stages.count)")
    }
}

struct CycleDestinationView: View {
    @AppStorage(CyclePersistenceKeys.onboardingCompleted) private var isOnboardingCompleted = false
    var showThemes: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isOnboardingCompleted {
                CycleHomeView(showThemes: showThemes)
                    .hesiaScreenTransition(reduceMotion: reduceMotion)
            } else {
                CycleOnboardingView(returnToThemes: returnToThemes) {
                    isOnboardingCompleted = true
                }
                .hesiaScreenTransition(reduceMotion: reduceMotion)
            }
        }
        .hesiaScreenAnimation(reduceMotion: reduceMotion, value: isOnboardingCompleted)
    }

    private func returnToThemes() {
        if let showThemes { showThemes() } else { dismiss() }
    }
}

struct PregnancyDestinationView: View {
    @AppStorage(PregnancyPersistenceKeys.onboardingCompleted) private var isOnboardingCompleted = false
    var showThemes: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isOnboardingCompleted {
                PregnancyHomeView(showThemes: showThemes)
                    .hesiaScreenTransition(reduceMotion: reduceMotion)
            } else {
                PregnancySetupView(returnToThemes: returnToThemes) {
                    isOnboardingCompleted = true
                }
                .hesiaScreenTransition(reduceMotion: reduceMotion)
            }
        }
        .hesiaScreenAnimation(reduceMotion: reduceMotion, value: isOnboardingCompleted)
    }

    private func returnToThemes() {
        if let showThemes { showThemes() } else { dismiss() }
    }
}

struct PostpartumDestinationView: View {
    @AppStorage(PostpartumPersistenceKeys.onboardingCompleted) private var isOnboardingCompleted = false
    var showThemes: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isOnboardingCompleted {
                PostpartumHomeView(showThemes: showThemes)
                    .hesiaScreenTransition(reduceMotion: reduceMotion)
            } else {
                PostpartumPersonalizationView(returnToThemes: returnToThemes) {
                    isOnboardingCompleted = true
                }
                .hesiaScreenTransition(reduceMotion: reduceMotion)
            }
        }
        .hesiaScreenAnimation(reduceMotion: reduceMotion, value: isOnboardingCompleted)
    }

    private func returnToThemes() {
        if let showThemes { showThemes() } else { dismiss() }
    }
}

struct BirthMomentDestinationView: View {
    var showThemes: (() -> Void)? = nil

    var body: some View {
        BirthMomentHomeView(showThemes: showThemes)
    }
}


struct MotherhoodDestinationView: View {
    @AppStorage(MotherhoodPersistenceKeys.onboardingCompleted) private var isOnboardingCompleted = false
    @AppStorage(MotherhoodPersistenceKeys.ageRange) private var ageRangeRawValue = ""
    var showThemes: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsDetail: Bool {
        isOnboardingCompleted && MotherhoodAgeRange(rawValue: ageRangeRawValue) != nil
    }

    var body: some View {
        ZStack {
            if showsDetail {
                MotherhoodDetailView(showThemes: showThemes)
                    .hesiaScreenTransition(reduceMotion: reduceMotion)
            } else {
                MotherhoodPersonalizationView(returnToThemes: returnToThemes) {
                    isOnboardingCompleted = true
                }
                .hesiaScreenTransition(reduceMotion: reduceMotion)
            }
        }
        .hesiaScreenAnimation(reduceMotion: reduceMotion, value: showsDetail)
    }

    private func returnToThemes() {
        if let showThemes { showThemes() } else { dismiss() }
    }
}

struct LifeStagePlaceholderView: View {
    let stage: LifeStage
    var showThemesAction: (() -> Void)? = nil

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @AppStorage("user.name") private var userName = ""
    @State private var isSettingsPresented = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AYAColors.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 9) {
                Text(stage.titleKey)
                    .ayaTypography(.screenTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("stage.coming_soon")
                    .ayaTypography(.body)
                    .foregroundStyle(AYAColors.textSecondary)
            }
            .hesiaScreenPadding()
        }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topTrailing) {
                if !isSettingsPresented {
                    settingsButton
                        .padding(.top, 8)
                        .padding(.trailing, 16)
                }
            }
            .overlay {
                if isSettingsPresented {
                    settingsOverlay
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: isSettingsPresented)
    }

    private var settingsButton: some View {
        AYAProfileButton(initial: userInitial) {
            isSettingsPresented = true
        }
    }

    private var settingsOverlay: some View {
        AYASettingsOverlay(
            languageCode: $languageCode,
            userName: $userName,
            activeStage: stage,
            close: closeSettings,
            showThemes: showThemes
        )
    }

    private func closeSettings() {
        isSettingsPresented = false
    }

    private func showThemes() {
        isSettingsPresented = false
        if let showThemesAction {
            showThemesAction()
        } else {
            dismiss()
        }
    }

    private var userInitial: String {
        guard let firstCharacter = userName.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "A"
        }
        return String(firstCharacter).uppercased(with: Locale.current)
    }
}


#Preview("TR · iPhone 16 Pro") {
    LifeStageSelectionView()
        .environment(\.locale, Locale(identifier: "tr"))
        .previewDevice("iPhone 16 Pro")
}

#Preview("EN · iPhone 16 Pro") {
    LifeStageSelectionView()
        .environment(\.locale, Locale(identifier: "en"))
        .previewDevice("iPhone 16 Pro")
}

#Preview("TR · Compact iPhone") {
    LifeStageSelectionView()
        .environment(\.locale, Locale(identifier: "tr"))
        .previewDevice("iPhone SE (3rd generation)")
}

#Preview("EN · Compact · XXL") {
    LifeStageSelectionView()
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.dynamicTypeSize, .xxLarge)
        .previewDevice("iPhone SE (3rd generation)")
}
