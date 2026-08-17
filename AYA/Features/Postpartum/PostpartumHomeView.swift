import SwiftUI

struct PostpartumHomeView: View {
    private let showThemesAction: (() -> Void)?

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @AppStorage("user.name") private var userName = ""
    @AppStorage(PostpartumPersistenceKeys.birthDate) private var birthDateTimestamp = 0.0
    @AppStorage(PostpartumPersistenceKeys.onboardingCompleted) private var isOnboardingCompleted = false
    @AppStorage(LifeStagePersistenceKeys.activeStage) private var activeStageRawValue = LifeStage.postpartum.rawValue
    @AppStorage(OfflineMeditationPreferenceKeys.isEnabled) private var isOfflineListeningEnabled = false

    @State private var isSettingsPresented = false
    @State private var isEditingBirthDate = false
    @State private var isTimelinePresented = false
    @State private var playbackSession: MeditationPlaybackSession?
    @State private var isPlayerPresented = false
    @State private var isPlaybackContinuationToastPresented = false
    @State private var infoContent: ContextualInfoContent?
    @State private var remoteMeditationMetadata: RemoteMeditationMetadata?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    private let tracker = PostpartumTracker()
    private let meditationProvider = PostpartumMeditationProvider()
    // Retained for a possible future return of the postpartum overview timeline.
    private let showsOverviewTimeline = true

    init(showThemes: (() -> Void)? = nil) {
        showThemesAction = showThemes
    }

    var body: some View {
        Group {
            if let profile {
                homeContent(profile: profile)
            } else {
                PostpartumPersonalizationView(returnToThemes: showThemes) {
                    isOnboardingCompleted = true
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isTimelinePresented) {
            if let profile {
                PostpartumTimelineView(profile: profile)
            }
        }
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
        .fullScreenCover(isPresented: $isEditingBirthDate) {
            NavigationStack {
                PostpartumPersonalizationView(mode: .edit) {
                    isEditingBirthDate = false
                }
            }
            .environment(\.locale, locale)
            .tint(AYAColors.primary)
        }
        .sheet(item: $infoContent) { content in
            ContextualInfoSheet(content: content)
                .environment(\.locale, locale)
        }
        .meditationPlaybackContinuationToast(
            isPresented: $isPlaybackContinuationToastPresented
        )
    }

    private var profile: PostpartumProfile? {
        guard birthDateTimestamp > 0 else { return nil }
        return PostpartumProfile(
            birthDate: Date(timeIntervalSince1970: birthDateTimestamp)
        )
    }

    private func homeContent(profile: PostpartumProfile) -> some View {
        let calculation = tracker.calculate(profile: profile)
        let meditation = meditationProvider.meditation(for: calculation)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(calculation: calculation)

                PostpartumInsightCard(
                    calculation: calculation,
                    showInfo: { infoContent = $0 }
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("postpartum.meditation.today")
                        .ayaTypography(.homeSectionHeading)
                        .foregroundStyle(AYAColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    DailyMeditationCard(
                        meditation: meditation,
                        remoteMetadata: remoteMeditationMetadata,
                        playbackViewModel: playbackViewModel(for: meditation)
                    ) {
                        startMeditation(meditation)
                    }
                }

                if showsOverviewTimeline {
                    PostpartumOverviewSection(
                        days: tracker.timelineDays(around: calculation.currentDay),
                        currentDay: calculation.currentDay,
                        viewTimeline: { isTimelinePresented = true }
                    )
                }

                if HESIAFeatureFlags.supportsMotherhood,
                   calculation.shouldOfferMotherhoodTransition {
                    LifeStageContinuationCard(
                        destination: .motherhood03,
                        titleKey: "postpartum.transition.motherhood.title",
                        messageKey: "postpartum.transition.motherhood.message",
                        actionKey: "postpartum.transition.motherhood.action",
                        action: continueToMotherhood
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .task(id: meditation.id) {
            await loadRemoteMetadata(for: meditation)
        }
        .task(id: offlinePackageTaskID(calculation: calculation)) {
            syncOfflinePackage(calculation: calculation)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            syncOfflinePackage(calculation: tracker.calculate(profile: profile))
        }
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .overlay {
            if isSettingsPresented {
                AYASettingsOverlay(
                    languageCode: $languageCode,
                    userName: $userName,
                    activeStage: .postpartum,
                    close: closeSettings,
                    showThemes: showThemes,
                    editPostpartum: editBirthDate
                )
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: isSettingsPresented)
    }

    private func header(calculation: PostpartumCalculation) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(verbatim: greetingText)
                    .ayaTypography(.homeGreeting)
                    .foregroundStyle(AYAColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(verbatim: postpartumDayText(calculation.currentDay))
                    .ayaTypography(.homeSupporting)
                    .foregroundStyle(AYAColors.textSecondary)
            }

            Spacer(minLength: 8)

            if !isSettingsPresented {
                AYAProfileButton(initial: userInitial) {
                    isSettingsPresented = true
                }
            }
        }
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
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
    }

    private func loadRemoteMetadata(for meditation: DailyMeditation) async {
        remoteMeditationMetadata = nil
        guard let source = meditation.remoteAudioSource else { return }

        do {
            let metadata = try await RemoteMeditationContentLoader.loadMetadata(source: source)
            guard !Task.isCancelled else { return }
            remoteMeditationMetadata = metadata
        } catch {
            guard !Task.isCancelled else { return }
            remoteMeditationMetadata = nil
        }
    }

    private func offlinePackageTaskID(calculation: PostpartumCalculation) -> String {
        [
            isOfflineListeningEnabled ? "enabled" : "disabled",
            String(calculation.currentDay),
            selectedLanguage.rawValue
        ].joined(separator: "-")
    }

    private func syncOfflinePackage(calculation: PostpartumCalculation) {
        guard isOfflineListeningEnabled else { return }
        OfflineMeditationManager.shared.syncPostpartumPackage(
            currentDay: calculation.currentDay,
            language: selectedLanguage
        )
    }

    private var greetingText: String {
        let format = selectedLanguage.localizedString(forKey: greetingLocalizationKey)
        return String(format: format, locale: locale, userName)
    }

    private var greetingLocalizationKey: String {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: Date())
        return switch hour {
        case 5..<12: "postpartum.home.greeting.morning"
        case 12..<18: "postpartum.home.greeting.day"
        default: "postpartum.home.greeting.evening"
        }
    }

    private func postpartumDayText(_ day: Int) -> String {
        let format = selectedLanguage.localizedString(forKey: "postpartum.home.day")
        return String(format: format, locale: locale, day)
    }

    private var userInitial: String {
        guard let firstCharacter = userName.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "H"
        }
        return String(firstCharacter).uppercased(with: locale)
    }

    private func closeSettings() {
        isSettingsPresented = false
    }

    private func showThemes() {
        isSettingsPresented = false
        stopPlaybackSession()
        if let showThemesAction { showThemesAction() } else { dismiss() }
    }

    private func editBirthDate() {
        isSettingsPresented = false
        isEditingBirthDate = true
    }

    private func continueToMotherhood() {
        stopPlaybackSession()
        activeStageRawValue = LifeStage.motherhood03.rawValue
    }
}

private struct PostpartumInsightCard: View {
    let calculation: PostpartumCalculation
    let showInfo: (ContextualInfoContent) -> Void

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    private let detailTheme = LifeStageDetailTheme.theme(for: .postpartum)

    var body: some View {
        Group {
            if usesVerticalLayout {
                VStack(alignment: .leading, spacing: 16) {
                    progressRing.frame(maxWidth: .infinity, alignment: .center)
                    insight
                }
            } else {
                HStack(spacing: 16) {
                    progressRing
                    insight
                }
            }
        }
        .padding(16)
        .frame(minHeight: LifeStageHeroMetrics.minHeight)
        .background { LifeStageHeroBackground(theme: detailTheme) }
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.hero, style: .continuous)
                .stroke(detailTheme.heroBorder, lineWidth: 1)
        }
        .ayaCardShadow()
    }

    private var progressRing: some View {
        StageProgressRing(
            currentValue: calculation.currentDay,
            totalLabelKey: "postpartum.home.total_days",
            progress: calculation.progress,
            accessibilityLabelKey: "postpartum.home.progress.accessibility",
            accessibilityValue: progressAccessibilityValue,
            trackColor: detailTheme.ringTrack,
            progressColor: detailTheme.ringProgress
        )
    }

    private var insight: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                Text(verbatim: localized(calculation.stage.titleLocalizationKey))
                    .ayaTypography(.homeBadge)
                    .foregroundStyle(AYAColors.emphasis)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 27)
                    .background(detailTheme.badgeSurface, in: Capsule())

                ContextualInfoButton(
                    accessibilityLabel: localized(postpartumInfo.accessibilityLabelKey),
                    action: { showInfo(postpartumInfo) }
                )
            }

            Text(verbatim: localized(calculation.stage.headlineLocalizationKey))
                .ayaTypography(.homeInsightTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: localized(calculation.stage.bodyLocalizationKey))
                .ayaTypography(.homeBody)
                .foregroundStyle(AYAColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var postpartumInfo: ContextualInfoContent {
        PostpartumInfoProvider.content(for: calculation.stage)
    }

    private var usesVerticalLayout: Bool {
        dynamicTypeSize >= .xxxLarge
    }

    private func localized(_ key: String) -> String {
        selectedLanguage.localizedString(forKey: key)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }

    private var progressAccessibilityValue: String {
        let format = selectedLanguage.localizedString(forKey: "postpartum.home.progress.value")
        return String(
            format: format,
            locale: locale,
            calculation.currentDay,
            PostpartumJourney.totalDays
        )
    }
}

private struct PostpartumOverviewSection: View {
    let days: [Int]
    let currentDay: Int
    let viewTimeline: () -> Void
    private let detailTheme = LifeStageDetailTheme.theme(for: .postpartum)

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.xs) {
            HStack(spacing: 12) {
                Text("postpartum.timeline.title")
                    .ayaTypography(.homeSectionHeading)
                    .foregroundStyle(AYAColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button(action: viewTimeline) {
                    HStack(spacing: 5) {
                        Text("postpartum.timeline.view")
                        HesiaIcon.caretRight.view(size: 12)
                    }
                    .ayaTypography(.homeLink)
                    .foregroundStyle(AYAColors.emphasis)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("postpartum.home.timeline.button")
            }

            LifeStageHorizontalTimeline(
                values: days,
                currentValue: currentDay,
                accessibilityLabelKey: "postpartum.timeline.accessibility",
                activeColor: detailTheme.timelineActive,
                inactiveColor: detailTheme.timelineInactive,
                connectorColor: detailTheme.timelineConnector
            )
        }
    }
}

#Preview("Postpartum Home — Türkçe") {
    NavigationStack {
        PostpartumHomeView()
            .environment(\.locale, Locale(identifier: "tr"))
    }
}
