import SwiftUI

struct PregnancyHomeView: View {
    private let showThemesAction: (() -> Void)?

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @AppStorage("user.name") private var userName = ""
    @AppStorage(PregnancyPersistenceKeys.referenceWeek) private var referenceWeek = 0
    @AppStorage(PregnancyPersistenceKeys.referenceDate) private var referenceTimestamp = 0.0
    @AppStorage(PregnancyPersistenceKeys.onboardingCompleted) private var isOnboardingCompleted = false
    @AppStorage(LifeStagePersistenceKeys.activeStage) private var activeStageRawValue = LifeStage.pregnancy.rawValue
    @AppStorage(OfflineMeditationPreferenceKeys.isEnabled) private var isOfflineListeningEnabled = false

    @State private var isSettingsPresented = false
    @State private var isWeekEditorPresented = false
    @State private var isCalendarPresented = false
    @State private var playbackSession: MeditationPlaybackSession?
    @State private var isPlayerPresented = false
    @State private var isPlaybackContinuationToastPresented = false
    @State private var weekInfoPresentation: PregnancyWeekInfoPresentation?
    @State private var remoteMeditationMetadata: RemoteMeditationMetadata?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    private let tracker = PregnancyTracker()
    private let contentProvider = PregnancyContentProvider()
    // Retained for a possible future return of the pregnancy overview timeline.
    private let showsOverviewTimeline = true

    init(showThemes: (() -> Void)? = nil) {
        showThemesAction = showThemes
    }

    var body: some View {
        Group {
            if let profile {
                homeContent(profile: profile)
            } else {
                PregnancySetupView(returnToThemes: showThemes) {
                    isOnboardingCompleted = true
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isCalendarPresented) {
            if let profile {
                PregnancyCalendarView(profile: profile)
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
        .sheet(isPresented: $isWeekEditorPresented) {
            PregnancyWeekEditorView(initialWeek: currentWeek) { newWeek in
                updatePregnancyWeek(newWeek)
                isWeekEditorPresented = false
            }
            .environment(\.locale, locale)
        }
        .sheet(item: $weekInfoPresentation) { presentation in
            PregnancyWeekInfoSheet(presentation: presentation)
                .environment(\.locale, locale)
        }
        .meditationPlaybackContinuationToast(
            isPresented: $isPlaybackContinuationToastPresented
        )
    }

    private var profile: PregnancyProfile? {
        guard referenceWeek > 0, referenceTimestamp > 0 else { return nil }
        return PregnancyProfile(
            referenceWeek: referenceWeek,
            referenceDate: Date(timeIntervalSince1970: referenceTimestamp)
        )
    }

    private var currentWeek: Int {
        guard let profile else { return min(max(referenceWeek, 1), 42) }
        return tracker.calculate(profile: profile).currentWeek
    }

    private func homeContent(profile: PregnancyProfile) -> some View {
        let calculation = tracker.calculate(profile: profile)
        let meditation = contentProvider.meditation(for: calculation)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(calculation: calculation)

                PregnancyInsightCard(calculation: calculation)

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("pregnancy.home.today_meditation")

                    DailyMeditationCard(
                        meditation: meditation,
                        remoteMetadata: remoteMeditationMetadata,
                        playbackViewModel: playbackViewModel(for: meditation)
                    ) {
                        startMeditation(meditation)
                    }
                }

                if showsOverviewTimeline {
                    PregnancyOverviewView(
                        weeks: tracker.overviewWeeks(around: calculation.currentWeek),
                        currentWeek: calculation.currentWeek,
                        viewCalendar: { isCalendarPresented = true }
                    )
                }

                if calculation.shouldOfferPostpartumTransition {
                    LifeStageContinuationCard(
                        destination: .postpartum,
                        titleKey: "pregnancy.transition.postpartum.title",
                        messageKey: "pregnancy.transition.postpartum.message",
                        actionKey: "pregnancy.transition.postpartum.action",
                        action: continueToPostpartum
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
            let refreshedCalculation = tracker.calculate(profile: profile)
            syncOfflinePackage(calculation: refreshedCalculation)
        }
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .overlay {
            if isSettingsPresented {
                AYASettingsOverlay(
                    languageCode: $languageCode,
                    userName: $userName,
                    activeStage: .pregnancy,
                    close: closeSettings,
                    showThemes: showThemes,
                    pregnancyWeek: calculation.currentWeek,
                    editPregnancy: editPregnancy
                )
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: isSettingsPresented)
    }

    private func header(calculation: PregnancyCalculation) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(verbatim: greetingText)
                    .ayaTypography(.homeGreeting)
                    .foregroundStyle(AYAColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: 2) {
                    Text(verbatim: pregnancyWeekText(calculation.currentWeek))
                        .ayaTypography(.homeSupporting)
                        .foregroundStyle(AYAColors.textSecondary)

                    ContextualInfoButton(
                        accessibilityLabel: pregnancyInfoAccessibility(for: calculation.currentWeek),
                        action: { showWeekInfo(for: calculation.currentWeek) }
                    )
                }
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

    private var greetingText: String {
        let format = selectedLanguage.localizedString(forKey: greetingLocalizationKey)
        return String(format: format, locale: locale, userName)
    }

    private var greetingLocalizationKey: String {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: Date())
        return switch hour {
        case 5..<12: "pregnancy.home.greeting.morning"
        case 12..<18: "pregnancy.home.greeting.day"
        default: "pregnancy.home.greeting.evening"
        }
    }

    private func pregnancyWeekText(_ week: Int) -> String {
        let format = selectedLanguage.localizedString(forKey: "pregnancy.home.week")
        return String(format: format, locale: locale, week)
    }

    private func pregnancyInfoAccessibility(for week: Int) -> String {
        let format = selectedLanguage.localizedString(forKey: "info.pregnancy.accessibility")
        return String(format: format, locale: locale, week)
    }

    private func showWeekInfo(for week: Int) {
        weekInfoPresentation = PregnancyWeekInfoPresentation(
            week: week,
            language: selectedLanguage,
            content: PregnancyWeekInfoRepository.shared.info(for: week, language: selectedLanguage)
        )
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

    private func offlinePackageTaskID(calculation: PregnancyCalculation) -> String {
        [
            isOfflineListeningEnabled ? "enabled" : "disabled",
            String(calculation.currentWeek),
            selectedLanguage.rawValue
        ].joined(separator: "-")
    }

    private func syncOfflinePackage(calculation: PregnancyCalculation) {
        guard isOfflineListeningEnabled else { return }
        OfflineMeditationManager.shared.syncPregnancyPackage(
            week: calculation.currentWeek,
            language: selectedLanguage
        )
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
        if let showThemesAction {
            showThemesAction()
        } else {
            dismiss()
        }
    }

    private func editPregnancy() {
        isSettingsPresented = false
        isWeekEditorPresented = true
    }

    private func updatePregnancyWeek(_ week: Int) {
        let normalizedToday = Calendar.current.startOfDay(for: Date())
        referenceWeek = min(max(week, 1), 42)
        referenceTimestamp = normalizedToday.timeIntervalSince1970
        isOnboardingCompleted = true
    }

    private func continueToPostpartum() {
        stopPlaybackSession()
        activeStageRawValue = LifeStage.postpartum.rawValue
    }
}

private struct PregnancyInsightCard: View {
    let calculation: PregnancyCalculation

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    private let detailTheme = LifeStageDetailTheme.theme(for: .pregnancy)

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
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(detailTheme.heroBorder, lineWidth: 1)
        }
        .ayaCardShadow()
    }

    private var progressRing: some View {
        StageProgressRing(
            currentValue: calculation.currentWeek,
            totalLabelKey: "pregnancy.home.total_weeks",
            progress: calculation.progress,
            accessibilityLabelKey: "pregnancy.home.progress.accessibility",
            accessibilityValue: progressAccessibilityValue,
            trackColor: detailTheme.ringTrack,
            progressColor: detailTheme.ringProgress
        )
    }

    private var insight: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: localized(calculation.trimester.nameLocalizationKey))
                .ayaTypography(.homeBadge)
                .foregroundStyle(AYAColors.emphasis)
                .padding(.horizontal, 11)
                .frame(minHeight: 27)
                .background(detailTheme.badgeSurface, in: Capsule())

            Text(verbatim: localized(calculation.trimester.insightTitleLocalizationKey))
                .ayaTypography(.homeInsightTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: localized(calculation.trimester.insightDescriptionLocalizationKey))
                .ayaTypography(.homeBody)
                .foregroundStyle(AYAColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func localized(_ key: String) -> String {
        (AppLanguage(rawValue: languageCode) ?? .system).localizedString(forKey: key)
    }

    private var usesVerticalLayout: Bool {
        dynamicTypeSize >= .xxxLarge
    }

    private var progressAccessibilityValue: String {
        let format = selectedLanguage.localizedString(forKey: "pregnancy.home.progress.value")
        return String(format: format, locale: locale, calculation.currentWeek, 40)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }
}

struct PregnancyOverviewView: View {
    let weeks: [Int]
    let currentWeek: Int
    let viewCalendar: () -> Void
    private let detailTheme = LifeStageDetailTheme.theme(for: .pregnancy)

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.xs) {
            SectionHeader("pregnancy.overview.title") {
                Button(action: viewCalendar) {
                    HStack(spacing: 5) {
                        Text("pregnancy.overview.view_calendar")
                        HesiaIcon.caretRight.view(size: 12)
                    }
                    .ayaTypography(.homeLink)
                    .foregroundStyle(AYAColors.emphasis)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pregnancy.home.calendar.button")
            }

            LifeStageHorizontalTimeline(
                values: weeks,
                currentValue: currentWeek,
                accessibilityLabelKey: "pregnancy.overview.accessibility",
                activeColor: detailTheme.timelineActive,
                inactiveColor: detailTheme.timelineInactive,
                connectorColor: detailTheme.timelineConnector
            )
        }
    }
}

struct PregnancyWeekEditorView: View {
    let initialWeek: Int
    let save: (Int) -> Void

    @State private var selectedWeek: Int
    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(initialWeek: Int, save: @escaping (Int) -> Void) {
        self.initialWeek = initialWeek
        self.save = save
        _selectedWeek = State(initialValue: min(max(initialWeek, 1), 42))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("pregnancy.settings.title")
                    .ayaTypography(.screenTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    HesiaIcon.close.view(size: 15)
                        .foregroundStyle(AYAColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AYAColors.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.close")
            }

            Picker("pregnancy.settings.title", selection: $selectedWeek) {
                ForEach(1...42, id: \.self) { week in
                    Text(verbatim: formattedWeek(week)).tag(week)
                }
            }
            .pickerStyle(.wheel)

            Button {
                save(selectedWeek)
            } label: {
                Text("pregnancy.settings.update")
            }
            .buttonStyle(.appPrimary)
            .accessibilityIdentifier("pregnancy.settings.update")
        }
        .padding(22)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func formattedWeek(_ week: Int) -> String {
        let language = AppLanguage(rawValue: languageCode) ?? .system
        let format = language.localizedString(forKey: "pregnancy.week.value")
        return String(format: format, locale: locale, week)
    }
}

#Preview("Pregnancy Home — English") {
    NavigationStack {
        PregnancyHomeView()
            .environment(\.locale, Locale(identifier: "en"))
    }
}
