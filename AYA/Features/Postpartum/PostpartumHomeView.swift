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
    @State private var isMeditationBrowserPresented = false
    @State private var playbackSession: MeditationPlaybackSession?
    @State private var isPlayerPresented = false
    @State private var isPlaybackContinuationToastPresented = false
    @State private var infoContent: ContextualInfoContent?
    @State private var metadataState: DailyMeditationMetadataState = .loading

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    private let tracker = PostpartumTracker()
    private let meditationProvider = PostpartumMeditationProvider()
    private let detailTheme = LifeStageDetailTheme.theme(for: .postpartum)

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
        .sheet(isPresented: $isEditingBirthDate) {
            NavigationStack {
                PostpartumPersonalizationView(mode: .edit) {
                    isEditingBirthDate = false
                }
            }
            .environment(\.locale, locale)
            .tint(AYAColors.primary)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isMeditationBrowserPresented) {
            if let profile {
                JourneyMeditationBrowser(
                    journey: .postpartum,
                    currentValue: tracker.calculate(profile: profile).currentDay
                )
                .environment(\.locale, locale)
            }
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

        return HomeScreenScaffold(contentTopPadding: AYALayout.screenTopPadding) {
            HomeHeader(
                greeting: greetingText,
                userInitial: userInitial,
                showsProfileButton: !isSettingsPresented,
                openSettings: { isSettingsPresented = true }
            ) {
                HStack(spacing: AYASpacing.xxs) {
                    HomeHeaderDetail(text: postpartumDayText(calculation.currentDay))

                    ContextualInfoButton(
                        accessibilityLabel: localized(postpartumInfo(for: calculation).accessibilityLabelKey),
                        action: { infoContent = postpartumInfo(for: calculation) }
                    )
                }
            }
        } content: {
            PostpartumHeroCard(
                theme: detailTheme,
                dayDisplay: heroDayDisplay(calculation.currentDay),
                badgeText: localized(calculation.recoveryStage.titleLocalizationKey),
                title: localized(calculation.stage.headlineLocalizationKey),
                message: localized(calculation.stage.bodyLocalizationKey),
                progressText: postpartumProgressText(calculation.currentDay),
                accessibilityValue: progressAccessibilityValue(calculation: calculation)
            )

            VStack(alignment: .leading, spacing: AYASpacing.md) {
                SectionHeader("postpartum.meditation.today")

                DailyMeditationCard(
                    meditation: meditation,
                    metadataState: metadataState,
                    playbackViewModel: playbackViewModel(for: meditation),
                    contextPlacement: .eyebrow
                ) {
                    startMeditation(meditation)
                }
                JourneyMeditationBrowseLink {
                    stopPlaybackSession()
                    isPlaybackContinuationToastPresented = false
                    isMeditationBrowserPresented = true
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            LifeStageOverviewSection(
                titleKey: "postpartum.timeline.title",
                linkKey: "postpartum.timeline.view",
                linkAccessibilityIdentifier: "postpartum.home.timeline.button",
                action: { isTimelinePresented = true }
            ) {
                PostpartumStageTimeline(
                    currentStage: calculation.recoveryStage,
                    accessibilityValue: progressAccessibilityValue(calculation: calculation),
                    theme: detailTheme
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

    private func postpartumInfo(for calculation: PostpartumCalculation) -> ContextualInfoContent {
        PostpartumInfoProvider.content(for: calculation.stage)
    }

    private func localized(_ key: String) -> String {
        selectedLanguage.localizedString(forKey: key)
    }

    private func progressAccessibilityValue(calculation: PostpartumCalculation) -> String {
        String(
            format: selectedLanguage.localizedString(forKey: "postpartum.home.progress.value"),
            locale: locale,
            calculation.currentDay,
            PostpartumJourney.totalDays
        )
    }

    private func heroDayDisplay(_ day: Int) -> String {
        HesiaOrdinalFormatter.string(day, language: selectedLanguage)
    }

    private func postpartumProgressText(_ day: Int) -> String {
        let format = selectedLanguage.localizedString(forKey: "postpartum.hero.progress")
        return String(
            format: format,
            locale: locale,
            min(day, PostpartumJourney.totalDays),
            PostpartumJourney.totalDays
        )
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
        guard let source = meditation.remoteAudioSource else {
            metadataState = .loaded(nil)
            return
        }

        metadataState = .loading
        do {
            let metadata = try await RemoteMeditationContentLoader.loadMetadata(source: source)
            guard !Task.isCancelled else { return }
            metadataState = .loaded(metadata)
        } catch {
            guard !Task.isCancelled else { return }
            metadataState = .failed
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

private struct PostpartumHeroCard: View {
    let theme: LifeStageDetailTheme
    let dayDisplay: String
    let badgeText: String
    let title: String
    let message: String
    let progressText: String
    let accessibilityValue: String

    var body: some View {
        HeroAdaptiveRow {
            VStack(alignment: .leading, spacing: AYASpacing.md) {
                HesiaBadge(verbatim: badgeText, prominence: .themed(theme.badgeSurface))

                HeroMetricColumn(
                    value: dayDisplay,
                    unitKey: "postpartum.hero.day_unit",
                    accessibilityLabelKey: "postpartum.home.progress.accessibility",
                    accessibilityValue: accessibilityValue
                ) {
                    HeroDivider(theme: theme)
                        .padding(.vertical, AYASpacing.sm)

                    Text(verbatim: progressText)
                        .ayaTypography(.homeMetadata)
                        .foregroundStyle(AYAColors.textSecondary)
                }
            }
        } trailing: {
            HeroInsight(title: title, message: message)
        }
        .lifeStageHeroSurface(theme: theme)
    }
}

private struct PostpartumStageTimeline: View {
    let currentStage: PostpartumRecoveryStage
    let accessibilityValue: String
    let theme: LifeStageDetailTheme

    @AppStorage("app.language") private var languageCode = AppLanguage.defaultExplicitLanguage.rawValue

    var body: some View {
        VStack(spacing: AYASpacing.md) {
            ZStack(alignment: .top) {
                Capsule()
                    .fill(theme.timelineConnector)
                    .frame(height: 1)
                    .padding(.horizontal, AYASpacing.xl)
                    .offset(y: AYASpacing.sm)
                    .accessibilityHidden(true)

                HStack(alignment: .top, spacing: 0) {
                    ForEach(PostpartumRecoveryStage.allCases, id: \.self) { stage in
                        stageMarker(stage)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

        }
        // İlerleme metni ("50 / 90 gün") hemen üstteki hero kartında zaten var;
        // ekranda iki kez göstermek yerine burada yalnızca sesli erişime bırakılır.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("postpartum.timeline.progress.accessibility")
        .accessibilityValue(accessibilityValue)
    }

    private func stageMarker(_ stage: PostpartumRecoveryStage) -> some View {
        let isCurrent = stage == currentStage

        return VStack(spacing: AYASpacing.sm) {
            Circle()
                .fill(isCurrent ? theme.timelineActive : theme.timelineInactive)
                .frame(
                    width: isCurrent ? AYASpacing.lg : AYASpacing.md,
                    height: isCurrent ? AYASpacing.lg : AYASpacing.md
                )
                .frame(height: AYASpacing.lg)

            Text(LocalizedStringKey(stage.titleLocalizationKey))
                .ayaTypography(.homeMetadata)
                .foregroundStyle(isCurrent ? AYAColors.emphasis : AYAColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: localized(stage.titleLocalizationKey)))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func localized(_ key: String) -> String {
        selectedLanguage.localizedString(forKey: key)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .defaultExplicitLanguage
    }
}

#Preview("Postpartum Home — Türkçe") {
    NavigationStack {
        PostpartumHomeView()
            .environment(\.locale, Locale(identifier: "tr"))
    }
}

#Preview("Postpartum Recovery — Small English", traits: .fixedLayout(width: 320, height: 720)) {
    ScrollView {
        VStack(alignment: .leading, spacing: AYALayout.sectionSpacing) {
            PostpartumHeroCard(
                theme: .theme(for: .postpartum),
                dayDisplay: "18th",
                badgeText: "First Weeks",
                title: "You are in a season of rest and recovery.",
                message: "A gentle time to slow down, care for your body, and create calm moments for yourself and your baby.",
                progressText: "18 / 90 days",
                accessibilityValue: "Day 18 of the first 90 days"
            )

            LifeStageOverviewSection(
                titleKey: "postpartum.timeline.title",
                linkKey: "postpartum.timeline.view",
                linkAccessibilityIdentifier: "postpartum.home.timeline.button",
                action: {}
            ) {
                PostpartumStageTimeline(
                    currentStage: .firstWeeks,
                    accessibilityValue: "Day 18 of the first 90 days",
                    theme: .theme(for: .postpartum)
                )
            }
        }
        .hesiaScreenPadding()
    }
    .background(AYAColors.backgroundPrimary)
    .environment(\.locale, Locale(identifier: "en"))
}

#Preview("Postpartum Hero — Content Lengths", traits: .fixedLayout(width: 393, height: 1_120)) {
    let theme = LifeStageDetailTheme.theme(for: .postpartum)

    ScrollView {
        VStack(alignment: .leading, spacing: AYASpacing.xl) {
            PostpartumHeroCard(
                theme: theme,
                dayDisplay: "3.",
                badgeText: "İlk Günler",
                title: "Bugün dinleniyorsun.",
                message: "Bedenine sakin bir alan aç.",
                progressText: "3 / 90 gün",
                accessibilityValue: "90 günün 3. günü"
            )

            PostpartumHeroCard(
                theme: theme,
                dayDisplay: "30.",
                badgeText: "İlk Haftalar",
                title: "Dinlenme ve toparlanma dönemindesin.",
                message: "Yavaşlamak, bedenine alan açmak ve kendinle sakin anlar yaratmak için nazik bir dönem.",
                progressText: "30 / 90 gün",
                accessibilityValue: "90 günün 30. günü"
            )

            PostpartumHeroCard(
                theme: theme,
                dayDisplay: "86.",
                badgeText: "Yeni Ritim",
                title: "Sana ait yeni bir ritim keşfediyorsun.",
                message: "Günlük hayat yeniden şekillenirken kendinle bağını korumak ve yenileyici molalara alan açmak için destekleyici bir dönem.",
                progressText: "86 / 90 gün",
                accessibilityValue: "90 günün 86. günü"
            )
        }
        .hesiaScreenPadding()
        .padding(.vertical, AYASpacing.xl)
    }
    .background(AYAColors.backgroundPrimary)
    .environment(\.locale, Locale(identifier: "tr"))
}
