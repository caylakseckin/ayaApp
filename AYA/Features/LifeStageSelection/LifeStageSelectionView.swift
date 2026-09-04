import SwiftUI
import StoreKit

struct LifeStageSelectionView: View {
    @StateObject private var viewModel: LifeStageSelectionViewModel
    @ObservedObject private var premiumStore = PremiumStore.shared
    @State private var navigationPath: [LifeStage] = []
    @State private var premiumStage: LifeStage?
    @State private var selectionFeedbackTrigger = 0
    private let onStageSelected: ((LifeStage) -> Void)?

    init(
        initialSelection: LifeStage = .cycle,
        onStageSelected: ((LifeStage) -> Void)? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: LifeStageSelectionViewModel(selectedStage: initialSelection)
        )
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
            let horizontalPadding = AYALayout.screenHorizontalPadding
            let contentWidth = max(0, geometry.size.width - (horizontalPadding * 2))

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header(usesCompactMetrics: usesCompactMetrics, width: contentWidth)
                        .padding(.bottom, usesCompactMetrics ? AYASpacing.lg : AYASpacing.xl)

                    LazyVStack(spacing: usesCompactMetrics ? AYASpacing.sm : AYASpacing.md) {
                        ForEach(LifeStage.availableCases) { stage in
                            LifeStageCardView(
                                stage: stage,
                                isSelected: viewModel.selectedStage == stage,
                                isPremiumUnlocked: premiumStore.hasPremiumAccess,
                                usesCompactMetrics: usesCompactMetrics,
                                action: { select(stage) }
                            )
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, usesCompactMetrics ? AYASpacing.md : AYASpacing.lg)
                .frame(minHeight: geometry.size.height, alignment: .center)
            }
            .scrollIndicators(.hidden)
            .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        }
        .sheet(item: $premiumStage) { stage in
            PremiumPaywallView(stage: stage) {
                premiumStage = nil
                completeSelection(stage)
            }
        }
        .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
        .task {
            await premiumStore.prepare()
        }
    }

    private func select(_ stage: LifeStage) {
        if stage.isPremium, !premiumStore.hasResolvedEntitlements {
            Task {
                await premiumStore.refreshEntitlements()
                select(stage)
            }
            return
        }

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

    private func header(usesCompactMetrics: Bool, width: CGFloat) -> some View {
        Text("life_stage.title")
            .ayaTypography(.screenTitle)
            .foregroundStyle(AYAColors.textPrimary)
            .tracking(-0.5)
            .lineSpacing(-4)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width, alignment: .center)
            .offset(y: 2)
            .accessibilityAddTraits(.isHeader)
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


#Preview("Türkçe") {
    LifeStageSelectionView()
        .environment(\.locale, Locale(identifier: "tr"))
}

#Preview("English") {
    LifeStageSelectionView()
        .environment(\.locale, Locale(identifier: "en"))
}
