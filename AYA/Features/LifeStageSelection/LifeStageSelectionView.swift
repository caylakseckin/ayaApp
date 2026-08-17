import SwiftUI
import StoreKit

struct LifeStageSelectionView: View {
    @StateObject private var viewModel: LifeStageSelectionViewModel
    @ObservedObject private var premiumStore = PremiumStore.shared
    @State private var navigationPath: [LifeStage] = []
    @State private var premiumStage: LifeStage?
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
            let horizontalPadding: CGFloat = 8
            let contentWidth = max(0, geometry.size.width - (horizontalPadding * 2))

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header(usesCompactMetrics: usesCompactMetrics, width: contentWidth)
                        .padding(.bottom, usesCompactMetrics ? 18 : 20)

                    LazyVStack(spacing: usesCompactMetrics ? 8 : 10) {
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
                .padding(.vertical, usesCompactMetrics ? 12 : 16)
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

private struct BirthMomentHomeView: View {
    private let showThemesAction: (() -> Void)?

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @AppStorage("user.name") private var userName = ""
    @AppStorage(OfflineMeditationPreferenceKeys.isEnabled) private var isOfflineListeningEnabled = false
    @AppStorage(LifeStagePersistenceKeys.activeStage) private var activeStageRawValue = LifeStage.birthMoment.rawValue
    @State private var isSettingsPresented = false
    @State private var playbackSession: MeditationPlaybackSession?
    @State private var isPlayerPresented = false
    @State private var isPlaybackContinuationToastPresented = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(showThemes: (() -> Void)? = nil) {
        showThemesAction = showThemes
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AYASpacing.xl) {
                header

                VStack(alignment: .leading, spacing: AYASpacing.sm) {
                    Text("birth_moment.home.title")
                        .ayaTypography(.screenTitle)
                        .foregroundStyle(AYAColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("birth_moment.home.description")
                        .ayaTypography(.body)
                        .foregroundStyle(AYAColors.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AYASpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    AYAColors.birthMomentHeroSurface,
                    in: RoundedRectangle(cornerRadius: AYARadius.hero, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AYARadius.hero, style: .continuous)
                        .stroke(AYAColors.primary.opacity(0.12), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: AYASpacing.md) {
                    Text("birth_moment.meditations.title")
                        .ayaTypography(.homeSectionHeading)
                        .foregroundStyle(AYAColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    VStack(spacing: AYASpacing.md) {
                        ForEach(BirthMomentMeditationProvider.meditations) { meditation in
                            BirthMomentMeditationRow(
                                meditation: meditation,
                                playbackViewModel: playbackViewModel(for: meditation),
                                action: { startMeditation(meditation) }
                            )
                        }
                    }
                }

                LifeStageContinuationCard(
                    destination: .postpartum,
                    titleKey: "birth_moment.transition.postpartum.title",
                    messageKey: "birth_moment.transition.postpartum.message",
                    actionKey: "birth_moment.transition.postpartum.action",
                    action: continueToPostpartum
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, AYASpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(
            isPresented: $isPlayerPresented,
            onDismiss: handlePlayerDismissed
        ) {
            if let playbackSession {
                HESIAMeditationTransitionContainer {
                    MeditationPlayerView(
                        meditation: playbackSession.meditation,
                        playbackViewModel: playbackSession.viewModel,
                        stopsPlaybackOnDismiss: false
                    )
                    .environment(\.locale, locale)
                    .tint(AYAColors.primary)
                }
            }
        }
        .overlay {
            if isSettingsPresented {
                AYASettingsOverlay(
                    languageCode: $languageCode,
                    userName: $userName,
                    activeStage: .birthMoment,
                    close: { isSettingsPresented = false },
                    showThemes: showThemes
                )
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: isSettingsPresented)
        .meditationPlaybackContinuationToast(
            isPresented: $isPlaybackContinuationToastPresented
        )
        .task(id: offlinePackageTaskID) {
            guard isOfflineListeningEnabled else { return }
            OfflineMeditationManager.shared.syncBirthPackage(
                practices: BirthMomentMeditationProvider.practiceIDs,
                language: selectedLanguage
            )
        }
    }

    private var header: some View {
        HStack {
            Text("life_stage.birthMoment.title")
                .ayaTypography(.homeGreeting)
                .foregroundStyle(AYAColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: AYASpacing.sm)

            if !isSettingsPresented {
                AYAProfileButton(initial: userInitial) {
                    isPlaybackContinuationToastPresented = false
                    isSettingsPresented = true
                }
            }
        }
    }

    private func showThemes() {
        isSettingsPresented = false
        stopPlaybackSession()
        if let showThemesAction { showThemesAction() } else { dismiss() }
    }

    private func continueToPostpartum() {
        stopPlaybackSession()
        activeStageRawValue = LifeStage.postpartum.rawValue
    }

    private func startMeditation(_ meditation: DailyMeditation) {
        isPlaybackContinuationToastPresented = false
        if playbackSession?.meditation.id != meditation.id {
            playbackSession?.viewModel.stop()
            playbackSession = MeditationPlaybackSession(
                meditation: meditation,
                language: selectedLanguage
            )
        }
        isPlayerPresented = true
    }

    private func handlePlayerDismissed() {
        isPlaybackContinuationToastPresented = playbackSession?.viewModel.isPlaying == true
    }

    private func playbackViewModel(for meditation: DailyMeditation) -> MeditationPlayerViewModel? {
        guard playbackSession?.meditation.id == meditation.id else { return nil }
        return playbackSession?.viewModel
    }

    private func stopPlaybackSession() {
        playbackSession?.viewModel.stop()
        playbackSession = nil
        isPlaybackContinuationToastPresented = false
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage.resolved(from: languageCode)
    }

    private var offlinePackageTaskID: String {
        "\(isOfflineListeningEnabled)-\(selectedLanguage.rawValue)-birth"
    }

    private var userInitial: String {
        guard let character = userName.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "H"
        }
        return String(character).uppercased(with: locale)
    }
}

enum BirthMomentMeditationProvider {
    static let practiceIDs = [
        "flower_breath",
        "arrow_breath",
        "zipper_breath",
        "curtain_breath"
    ]

    static let meditations: [DailyMeditation] = [
        meditation(id: "flower_breath", durationMinutes: 5),
        meditation(id: "arrow_breath", durationMinutes: 6),
        meditation(id: "zipper_breath", durationMinutes: 3),
        meditation(id: "curtain_breath", durationMinutes: 5)
    ]

    private static func meditation(id: String, durationMinutes: Int) -> DailyMeditation {
        DailyMeditation(
            id: "birth-moment-\(id)",
            titleLocalizationKey: "birth_moment.meditation.\(id).title",
            descriptionLocalizationKey: "birth_moment.meditation.\(id).description",
            contextNameLocalizationKey: "life_stage.birthMoment.title",
            contextFormatLocalizationKey: "birth_moment.meditation.context_format",
            contextValue: 0,
            durationMinutes: durationMinutes,
            voiceLocalizationKey: "meditation.voice.yaren",
            audioResourceName: nil,
            remoteAudioSource: RemoteMeditationAudioSource(birthPractice: id)
        )
    }
}

private struct BirthMomentMeditationRow: View {
    let meditation: DailyMeditation
    let playbackViewModel: MeditationPlayerViewModel?
    let action: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: AYASpacing.md) {
                VStack(alignment: .leading, spacing: AYASpacing.xs) {
                    Text(meditation.titleKey)
                        .ayaTypography(.sectionTitle)
                        .foregroundStyle(AYAColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(meditation.descriptionKey)
                        .ayaTypography(.homeSupporting)
                        .foregroundStyle(AYAColors.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: AYASpacing.xs) {
                        HesiaIcon.clock.view(size: 13)
                        Text(verbatim: durationText)
                    }
                    .ayaTypography(.homeMetadata)
                    .foregroundStyle(AYAColors.textTertiary)
                    .padding(.top, AYASpacing.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                playbackControl
            }
            .padding(AYASpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                AYAColors.surfaceElevated,
                in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                    .stroke(AYAColors.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .ayaElevation(.card)
        .accessibilityIdentifier("birth_moment.meditation.\(meditation.id)")
    }

    @ViewBuilder
    private var playbackControl: some View {
        if let playbackViewModel {
            BirthMomentActiveMeditationControl(viewModel: playbackViewModel)
        } else {
            Image(systemName: "play.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AYAColors.onAccent)
                .frame(width: 44, height: 44)
                .background(AYAColors.emphasis, in: Circle())
                .accessibilityHidden(true)
        }
    }

    private var durationText: String {
        let format = String(localized: "meditation.duration.minutes", locale: locale)
        return String(format: format, locale: locale, meditation.durationMinutes)
    }
}

private struct BirthMomentActiveMeditationControl: View {
    @ObservedObject var viewModel: MeditationPlayerViewModel

    var body: some View {
        Group {
            if viewModel.isLoadingAudio {
                ProgressView()
                    .tint(AYAColors.onAccent)
            } else if viewModel.isPlaying {
                PlaybackWaveformIndicator(isPlaying: true)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AYAColors.onAccent)
            }
        }
        .frame(width: 44, height: 44)
        .background(AYAColors.emphasis, in: Circle())
        .accessibilityHidden(true)
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
            .padding(.horizontal, 24)
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

struct AYAProfileButton: View {
    let initial: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AYAColors.emphasis)

                Text(initial)
                    .font(AYATypography.ui(size: 19, weight: .bold))
                    .foregroundStyle(AYAColors.onAccent)
            }
            .frame(width: 44, height: 44)
            .overlay {
                Circle().stroke(AYAColors.onAccent.opacity(0.65), lineWidth: 1)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .frame(width: 44, height: 44)
        .accessibilityIdentifier("settings.button")
        .accessibilityLabel("settings.title")
    }
}

struct AYASettingsOverlay: View {
    @Binding var languageCode: String
    @Binding var userName: String
    let activeStage: LifeStage?
    let close: () -> Void
    let showThemes: () -> Void
    var editCycle: (() -> Void)? = nil
    var pregnancyWeek: Int? = nil
    var editPregnancy: (() -> Void)? = nil
    var editPostpartum: (() -> Void)? = nil
    var motherhoodRange: MotherhoodAgeRange? = nil
    var editMotherhood: (() -> Void)? = nil
    var presentation: SettingsPanelPresentation = .standard

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                AYAColors.overlay
                    .ignoresSafeArea()
                    .onTapGesture(perform: close)

                SettingsPanel(
                    languageCode: $languageCode,
                    userName: $userName,
                    activeStage: activeStage,
                    close: close,
                    showThemes: showThemes,
                    editCycle: editCycle,
                    pregnancyWeek: pregnancyWeek,
                    editPregnancy: editPregnancy,
                    editPostpartum: editPostpartum,
                    motherhoodRange: motherhoodRange,
                    editMotherhood: editMotherhood,
                    topSafeAreaInset: geometry.safeAreaInsets.top,
                    bottomSafeAreaInset: geometry.safeAreaInsets.bottom,
                    presentation: presentation
                )
                .frame(width: min(336, geometry.size.width * 0.88))
                .frame(maxHeight: .infinity)
                .transition(.move(edge: .trailing))
            }
        }
        .ignoresSafeArea()
    }
}

enum SettingsPanelPresentation {
    case standard
    case tutorialPreview
}

struct SettingsPanel: View {
    @Binding var languageCode: String
    @Binding var userName: String
    let activeStage: LifeStage?
    let close: () -> Void
    let showThemes: () -> Void
    let editCycle: (() -> Void)?
    let pregnancyWeek: Int?
    let editPregnancy: (() -> Void)?
    let editPostpartum: (() -> Void)?
    let motherhoodRange: MotherhoodAgeRange?
    let editMotherhood: (() -> Void)?
    let topSafeAreaInset: CGFloat
    let bottomSafeAreaInset: CGFloat
    var presentation: SettingsPanelPresentation = .standard

    @State private var isLanguageExpanded = false
    @State private var isTutorialPresented = false
    @State private var isManageSubscriptionsPresented = false
    @ObservedObject private var premiumStore = PremiumStore.shared
    @AppStorage("app.appearance") private var appearanceRawValue = AppAppearance.system.rawValue
    @FocusState private var isNameFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("settings.title")
                    .ayaTypography(.screenTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button(action: close) {
                    HesiaIcon.close.view(size: 15)
                        .foregroundStyle(AYAColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AYAColors.cardSurface, in: Circle())
                        .overlay { Circle().stroke(AYAColors.divider, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.close.button")
                .accessibilityLabel("common.close")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    themesButton
                    if presentation == .tutorialPreview {
                        profileSection
                        if HESIAFeatureFlags.supportsMultipleLanguages {
                            languageSection
                        }
                        supportSection
                    } else {
                        howHesiaWorksButton
                        if activeStage == .cycle, let editCycle {
                            cycleSettingsButton(action: editCycle)
                        }
                        if
                            activeStage == .pregnancy,
                            let pregnancyWeek,
                            let editPregnancy
                        {
                            pregnancySettingsButton(week: pregnancyWeek, action: editPregnancy)
                        }
                        if activeStage == .postpartum, let editPostpartum {
                            postpartumSettingsButton(action: editPostpartum)
                        }
                        if
                            activeStage == .motherhood03,
                            let motherhoodRange,
                            let editMotherhood
                        {
                            motherhoodSettingsButton(range: motherhoodRange, action: editMotherhood)
                        }
                        if premiumStore.hasPremiumAccess {
                            premiumSection
                        }
                        profileSection
                        if HESIAFeatureFlags.supportsMultipleLanguages {
                            languageSection
                        }
                        appearanceSection
                        BiometricLockSettings()
                        OfflineMeditationSettings()
                        MeditationReminderSettings(presentation: .settings)
                        supportSection
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 20)
        .padding(.top, max(topSafeAreaInset + 14, 72))
        .padding(.bottom, max(bottomSafeAreaInset + 16, 24))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AYAColors.backgroundPrimary)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: AYARadius.hero, bottomLeadingRadius: AYARadius.hero))
        .ayaElevation(.panel)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $isTutorialPresented) {
            HESIATutorialView(context: .replayFromSettings) {
                isTutorialPresented = false
            }
        }
        .manageSubscriptionsSheet(isPresented: $isManageSubscriptionsPresented)
        .task {
            await premiumStore.refreshEntitlements()
        }
    }

    private var premiumSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("settings.premium.section")
                .font(AYATypography.ui(size: 13, weight: .medium))
                .foregroundStyle(AYAColors.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                HStack(spacing: AYASpacing.md) {
                    HesiaIcon.lock.view(size: 18)
                        .foregroundStyle(AYAColors.accent)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("settings.premium.title")
                            .font(AYATypography.ui(size: 15, weight: .medium))
                            .foregroundStyle(AYAColors.textPrimary)

                        Text(verbatim: premiumStatusText)
                            .font(AYATypography.ui(size: 12))
                            .foregroundStyle(AYAColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: AYASpacing.sm)

                    HesiaIcon.check.view(size: 17)
                        .foregroundStyle(AYAColors.accent)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, AYASpacing.lg)
                .padding(.vertical, AYASpacing.md)

                if premiumStore.subscription != nil {
                    divider

                    Button {
                        isManageSubscriptionsPresented = true
                    } label: {
                        HStack(spacing: AYASpacing.md) {
                            Text("settings.premium.manage")
                            Spacer()
                            HesiaIcon.caretRight.view(size: 13)
                                .foregroundStyle(AYAColors.textSecondary)
                        }
                        .font(AYATypography.ui(size: 14, weight: .medium))
                        .foregroundStyle(AYAColors.textPrimary)
                        .padding(.horizontal, AYASpacing.lg)
                        .frame(minHeight: 50)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.premium.manage.button")
                }
            }
            .background(
                AYAColors.cardSurface,
                in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                    .stroke(AYAColors.divider, lineWidth: 1)
            }
        }
    }

    private var premiumStatusText: String {
        guard let subscription = premiumStore.subscription else {
            return localizedString("settings.premium.subscription.active")
        }

        guard let renewalDate = subscription.renewalDate else {
            return localizedString("settings.premium.subscription.active")
        }

        let language = AppLanguage(rawValue: languageCode) ?? .system
        let date = renewalDate.formatted(
            Date.FormatStyle(date: .long, time: .omitted).locale(language.locale)
        )
        let key = subscription.willAutoRenew == false
            ? "settings.premium.subscription.expires"
            : "settings.premium.subscription.renews"
        let format = language.localizedString(forKey: key)
        return String(format: format, locale: language.locale, date)
    }

    private func localizedString(_ key: String) -> String {
        let language = AppLanguage(rawValue: languageCode) ?? .system
        return language.localizedString(forKey: key)
    }

    private var howHesiaWorksButton: some View {
        Button {
            isTutorialPresented = true
        } label: {
            HStack(spacing: AYASpacing.md) {
                HesiaIcon.info.view(size: 19)
                    .frame(width: 22)
                Text("settings.how_hesia_works")
                Spacer()
                HesiaIcon.caretRight.view(size: 13)
                    .foregroundStyle(AYAColors.textSecondary)
            }
            .font(AYATypography.ui(size: 15, weight: .medium))
            .foregroundStyle(AYAColors.textPrimary)
            .padding(.horizontal, AYASpacing.lg)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            AYAColors.cardSurface,
            in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                .stroke(AYAColors.divider, lineWidth: 1)
        }
        .accessibilityIdentifier("settings.how_hesia_works.button")
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("settings.support.section")
                .font(AYATypography.ui(size: 13, weight: .medium))
                .foregroundStyle(AYAColors.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                supportLink("settings.support.help", icon: .info, url: "https://hesia.app/hesia-legal-site/support.html")
                divider
                supportLink("settings.support.privacy", icon: .lock, url: "https://hesia.app/hesia-legal-site/privacy.html")
                divider
                supportLink("settings.support.terms", icon: .document, url: "https://hesia.app/hesia-legal-site/terms.html")
            }
            .background(
                AYAColors.cardSurface,
                in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                    .stroke(AYAColors.divider, lineWidth: 1)
            }
        }
    }

    private var appearanceSection: some View {
        let selectedAppearance = Binding(
            get: { AppAppearance(rawValue: appearanceRawValue) ?? .system },
            set: { appearanceRawValue = $0.rawValue }
        )

        return VStack(alignment: .leading, spacing: 9) {
            Text("settings.appearance.section")
                .font(AYATypography.ui(size: 13, weight: .medium))
                .foregroundStyle(AYAColors.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            Picker("settings.appearance.section", selection: selectedAppearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.titleKey).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.appearance.picker")
        }
    }

    private func cycleSettingsButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HesiaIcon.calendar.view(size: 19)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text("cycle.settings.title")
                        .font(AYATypography.ui(size: 15, weight: .medium))
                    Text("cycle.settings.edit")
                        .font(AYATypography.ui(size: 12))
                        .foregroundStyle(AYAColors.textSecondary)
                }

                Spacer()

                HesiaIcon.caretRight.view(size: 13)
                    .foregroundStyle(AYAColors.textSecondary)
            }
            .foregroundStyle(AYAColors.textPrimary)
            .padding(.horizontal, 16)
            .frame(minHeight: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(AYAColors.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AYAColors.divider, lineWidth: 1)
        }
        .accessibilityIdentifier("settings.cycle.button")
    }

    private func pregnancySettingsButton(
        week: Int,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HesiaIcon.calendar.view(size: 19)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text("pregnancy.settings.title")
                        .font(AYATypography.ui(size: 15, weight: .medium))
                    Text(verbatim: pregnancyWeekText(week))
                        .font(AYATypography.ui(size: 12))
                        .foregroundStyle(AYAColors.textSecondary)
                }

                Spacer()

                HesiaIcon.caretRight.view(size: 13)
                    .foregroundStyle(AYAColors.textSecondary)
            }
            .foregroundStyle(AYAColors.textPrimary)
            .padding(.horizontal, 16)
            .frame(minHeight: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(AYAColors.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AYAColors.divider, lineWidth: 1)
        }
        .accessibilityIdentifier("settings.pregnancy.button")
    }

    private func postpartumSettingsButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HesiaIcon.calendar.view(size: 19)
                    .frame(width: 22)

                Text("settings.postpartum.update_birth_date")
                    .font(AYATypography.ui(size: 15, weight: .medium))

                Spacer()

                HesiaIcon.caretRight.view(size: 13)
                    .foregroundStyle(AYAColors.textSecondary)
            }
            .foregroundStyle(AYAColors.textPrimary)
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(AYAColors.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AYAColors.divider, lineWidth: 1)
        }
        .accessibilityIdentifier("settings.postpartum.button")
    }

    private func motherhoodSettingsButton(
        range: MotherhoodAgeRange,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "figure.and.child.holdinghands")
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text("settings.motherhood.age_range")
                        .font(AYATypography.ui(size: 15, weight: .medium))
                    Text(LocalizedStringKey(range.titleLocalizationKey))
                        .font(AYATypography.ui(size: 12))
                        .foregroundStyle(AYAColors.textSecondary)
                }

                Spacer()

                HesiaIcon.caretRight.view(size: 13)
                    .foregroundStyle(AYAColors.textSecondary)
            }
            .foregroundStyle(AYAColors.textPrimary)
            .padding(.horizontal, 16)
            .frame(minHeight: 62)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(AYAColors.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AYAColors.divider, lineWidth: 1)
        }
        .accessibilityIdentifier("settings.motherhood.button")
    }

    private func pregnancyWeekText(_ week: Int) -> String {
        let language = AppLanguage(rawValue: languageCode) ?? .system
        let format = language.localizedString(forKey: "pregnancy.week.value")
        return String(format: format, locale: language.locale, week)
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("settings.profile.section")
                .font(AYATypography.ui(size: 13, weight: .medium))
                .foregroundStyle(AYAColors.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 7) {
                Text("settings.profile.name")
                    .font(AYATypography.ui(size: 12, weight: .medium))
                    .foregroundStyle(AYAColors.textSecondary)

                TextField("welcome.name.placeholder", text: $userName)
                    .font(AYATypography.ui(size: 15))
                    .foregroundStyle(AYAColors.textPrimary)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit {
                        userName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
                        isNameFocused = false
                    }
                    .frame(minHeight: 32)
                    .accessibilityIdentifier("settings.name.field")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(AYAColors.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AYAColors.divider, lineWidth: 1)
            }
        }
    }

    private var themesButton: some View {
        Button(action: showThemes) {
            HStack(spacing: 12) {
                HesiaIcon.themes.view(size: 19)
                    .frame(width: 22)
                Text("settings.themes")
                Spacer()
                HesiaIcon.caretRight.view(size: 13)
                    .foregroundStyle(AYAColors.textSecondary)
            }
            .font(AYATypography.ui(size: 15, weight: .medium))
            .foregroundStyle(AYAColors.textPrimary)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(AYAColors.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AYAColors.divider, lineWidth: 1)
        }
        .accessibilityIdentifier("settings.themes.button")
    }

    private var languageSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    isLanguageExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    HesiaIcon.globe.view(size: 19)
                        .frame(width: 22)
                    Text("settings.language")
                    Spacer()
                    HesiaIcon.caretDown.view(size: 13)
                        .rotationEffect(.degrees(isLanguageExpanded ? 180 : 0))
                }
                .font(AYATypography.ui(size: 15, weight: .medium))
                .foregroundStyle(AYAColors.textPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.language.button")

            if isLanguageExpanded {
                divider

                ForEach(AppLanguage.selectableCases) { language in
                    Button {
                        languageCode = language.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            HesiaSelectionIndicator(isSelected: languageCode == language.rawValue)
                            Text(verbatim: language.nativeTitle)
                            Spacer()
                        }
                        .font(AYATypography.ui(size: 14))
                        .foregroundStyle(AYAColors.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.language.\(language.rawValue)")
                }
            }
        }
        .background(AYAColors.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AYAColors.divider, lineWidth: 1)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(AYAColors.divider)
            .frame(height: 1)
            .padding(.leading, 50)
    }

    private func supportLink(_ key: LocalizedStringKey, icon: HesiaIcon, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                icon.view(size: 18)
                    .frame(width: 22)
                Text(key)
                Spacer()
                HesiaIcon.externalLink.view(size: 13)
                    .foregroundStyle(AYAColors.textSecondary)
            }
            .font(AYATypography.ui(size: 14, weight: .medium))
            .foregroundStyle(AYAColors.textPrimary)
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
