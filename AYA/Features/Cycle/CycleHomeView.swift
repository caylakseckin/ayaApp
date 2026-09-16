import SwiftUI

struct CycleHomeView: View {
    private let showThemesAction: (() -> Void)?

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @AppStorage("user.name") private var userName = ""
    @AppStorage(CyclePersistenceKeys.lastPeriodStartDate) private var lastPeriodTimestamp = 0.0
    @AppStorage(CyclePersistenceKeys.averageLength) private var averageLength = 0
    @AppStorage(CyclePersistenceKeys.averagePeriodDuration) private var averagePeriodDuration = 0
    @AppStorage(CyclePersistenceKeys.onboardingCompleted) private var isOnboardingCompleted = false
    @AppStorage(OfflineMeditationPreferenceKeys.isEnabled) private var isOfflineListeningEnabled = false

    @State private var isSettingsPresented = false
    @State private var isEditingCycle = false
    @State private var isCalendarPresented = false
    @State private var isPeriodStartPickerPresented = false
    @State private var periodStartDraft = Date()
    @State private var periodStartDates: [Date] = []
    @State private var periodHistoryMutation: CyclePeriodHistoryMutation?
    @State private var playbackSession: MeditationPlaybackSession?
    @State private var isPlayerPresented = false
    @State private var isPlaybackContinuationToastPresented = false
    @State private var infoContent: ContextualInfoContent?
    @State private var metadataState: DailyMeditationMetadataState = .loading

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    private let calculator = CycleCalculator()
    private let detailTheme = LifeStageDetailTheme.theme(for: .cycle)
    private let meditationProvider = DailyMeditationProvider()

    init(showThemes: (() -> Void)? = nil) {
        showThemesAction = showThemes
    }

    var body: some View {
        Group {
            if let profile {
                homeContent(profile: profile)
            } else {
                CycleOnboardingView(mode: .initial, returnToThemes: showThemes) {
                    isOnboardingCompleted = true
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isCalendarPresented) {
            if let profile {
                CycleCalendarView(
                    profile: profile,
                    periodStartDates: periodStartDates,
                    onRecordPeriodStart: recordPeriodStart
                )
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
        .fullScreenCover(isPresented: $isEditingCycle) {
            NavigationStack {
                CycleOnboardingView(mode: .edit) {
                    isEditingCycle = false
                    preparePeriodHistory()
                }
            }
            .environment(\.locale, locale)
            .tint(AYAColors.primary)
        }
        .sheet(item: $infoContent) { content in
            ContextualInfoSheet(content: content)
                .environment(\.locale, locale)
        }
        .sheet(isPresented: $isPeriodStartPickerPresented) {
            periodStartPicker
        }
        .meditationPlaybackContinuationToast(
            isPresented: $isPlaybackContinuationToastPresented
        )
        .onAppear(perform: preparePeriodHistory)
    }

    private var profile: CycleProfile? {
        guard lastPeriodTimestamp > 0 else { return nil }
        return CycleProfile(
            lastPeriodStartDate: Date(timeIntervalSince1970: lastPeriodTimestamp),
            averageCycleLength: averageLength,
            averagePeriodDuration: averagePeriodDuration
        )
    }

    private func homeContent(profile: CycleProfile) -> some View {
        let calculation = calculator.calculate(profile: profile)
        let meditation = meditationProvider.meditation(
            for: calculation.currentPhase,
            phaseDay: calculation.phaseDay,
            cycleDay: calculation.currentCycleDay
        )

        return HomeScreenScaffold {
            HomeHeader(
                greeting: greetingText,
                userInitial: userInitial,
                showsProfileButton: !isSettingsPresented,
                openSettings: { isSettingsPresented = true }
            ) {
                HomeHeaderDetail(text: cycleDayText(calculation.currentCycleDay))
            }
        } content: {
            LifeStageHeroCard(
                theme: detailTheme,
                badgeText: localized(calculation.currentPhase.nameLocalizationKey),
                title: localized(calculation.currentPhase.insightTitleLocalizationKey),
                message: localized(calculation.currentPhase.insightDescriptionLocalizationKey)
            ) {
                StageProgressRing(
                    currentText: "\(calculation.currentCycleDay)",
                    totalLabelKey: "cycle.home.total_days",
                    totalLabelText: cycleTotalDaysText(profile.averageCycleLength),
                    progress: calculation.cycleProgress,
                    accessibilityLabelKey: "cycle.home.progress.accessibility",
                    accessibilityValue: progressAccessibilityValue(
                        calculation: calculation,
                        profile: profile
                    ),
                    trackColor: detailTheme.ringTrack,
                    progressColor: detailTheme.ringProgress
                )
            } accessory: {
                ContextualInfoButton(
                    accessibilityLabel: localized(phaseInfo(for: calculation).accessibilityLabelKey),
                    action: { infoContent = phaseInfo(for: calculation) }
                )
            }

            periodStartAction

            VStack(alignment: .leading, spacing: AYASpacing.md) {
                SectionHeader("cycle.home.today_meditation")

                DailyMeditationCard(
                    meditation: meditation,
                    metadataState: metadataState,
                    playbackViewModel: playbackViewModel(for: meditation)
                ) {
                    startMeditation(meditation)
                }
            }

            LifeStageOverviewSection(
                titleKey: "cycle.home.overview",
                linkKey: "cycle.home.view_calendar",
                linkAccessibilityIdentifier: "cycle.home.calendar.button",
                values: calculator.surroundingDays(
                    currentDay: calculation.currentCycleDay,
                    cycleLength: profile.averageCycleLength
                ),
                currentValue: calculation.currentCycleDay,
                accessibilityLabelKey: "cycle.home.timeline.accessibility",
                theme: detailTheme,
                action: { isCalendarPresented = true }
            )
        }
        .task(id: meditation.id) {
            await loadRemoteMetadata(for: meditation)
        }
        .task(id: offlinePackageTaskID(calculation: calculation, profile: profile)) {
            syncOfflinePackage(calculation: calculation, profile: profile)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let refreshedCalculation = calculator.calculate(profile: profile)
            syncOfflinePackage(calculation: refreshedCalculation, profile: profile)
        }
        .overlay {
            if isSettingsPresented {
                AYASettingsOverlay(
                    languageCode: $languageCode,
                    userName: $userName,
                    activeStage: .cycle,
                    close: closeSettings,
                    showThemes: showThemes,
                    editCycle: editCycle
                )
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: isSettingsPresented)
        .task(id: periodHistoryMutation?.id) {
            guard periodHistoryMutation != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            periodHistoryMutation = nil
        }
    }

    @ViewBuilder private var periodStartAction: some View {
        if periodHistoryMutation != nil {
            periodStartRecordedRow("cycle.period_log.saved", showsUndo: true)
        } else if hasRecordedToday {
            periodStartRecordedRow("cycle.period_log.today_recorded", showsUndo: false)
        } else {
            Button {
                periodStartDraft = Calendar.autoupdatingCurrent.startOfDay(for: Date())
                isPeriodStartPickerPresented = true
            } label: {
                HStack(spacing: AYASpacing.md) {
                    HesiaIcon.calendar.view(size: HesiaIconSize.md)
                        .foregroundStyle(AYAColors.emphasis)
                        .frame(width: 32, height: 32)
                        .background(AYAColors.accentSoft, in: Circle())

                    Text("cycle.period_log.today_action")
                        .ayaTypography(.metadata)
                        .foregroundStyle(AYAColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HesiaIcon.caretRight.view(size: HesiaIconSize.sm)
                        .foregroundStyle(AYAColors.textTertiary)
                }
                .padding(.horizontal, AYASpacing.md)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AYAColors.surfaceElevated, in: RoundedRectangle(cornerRadius: AYARadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: AYARadius.control)
                        .stroke(AYAColors.border, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: AYARadius.control))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("cycle.period_log.open")
        }
    }

    private func periodStartRecordedRow(
        _ titleKey: LocalizedStringKey,
        showsUndo: Bool
    ) -> some View {
        HStack(spacing: AYASpacing.md) {
            HesiaIcon.check.view(size: HesiaIconSize.sm)
                .foregroundStyle(AYAColors.emphasis)
                .frame(width: 32, height: 32)
                .background(AYAColors.accentSoft, in: Circle())

            Text(titleKey)
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsUndo {
                Button("cycle.period_log.undo", action: undoPeriodStart)
                    .buttonStyle(.plain)
                    .ayaTypography(.metadata)
                    .foregroundStyle(AYAColors.emphasis)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, AYASpacing.md)
        .padding(.vertical, AYASpacing.xs)
        .background(AYAColors.backgroundSecondary, in: RoundedRectangle(cornerRadius: AYARadius.control))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cycle.period_log.recorded")
    }

    private var periodStartPicker: some View {
        VStack(alignment: .leading, spacing: AYASpacing.xl) {
            VStack(alignment: .leading, spacing: AYASpacing.sm) {
                Text("cycle.period_log.sheet.title")
                    .ayaTypography(.sectionTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("cycle.period_log.sheet.description")
                    .ayaTypography(.body)
                    .foregroundStyle(AYAColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DatePicker(
                "cycle.period_log.sheet.date",
                selection: $periodStartDraft,
                in: periodStartPickerRange,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(AYAColors.primary)

            Button {
                recordPeriodStart(periodStartDraft)
                isPeriodStartPickerPresented = false
            } label: {
                Text("cycle.period_log.save")
            }
            .buttonStyle(.appPrimary)
            .accessibilityIdentifier("cycle.period_log.save")
        }
        .padding(AYASpacing.xl)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var periodStartPickerRange: ClosedRange<Date> {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        let storedStart = calendar.startOfDay(
            for: Date(timeIntervalSince1970: lastPeriodTimestamp)
        )
        return min(storedStart, today)...today
    }

    private var hasRecordedToday: Bool {
        let calendar = Calendar.autoupdatingCurrent
        return periodStartDates.contains(where: calendar.isDateInToday)
    }

    private func preparePeriodHistory() {
        CyclePeriodHistoryStore.migrateLegacyStartDate()
        refreshPeriodHistory()
    }

    private func refreshPeriodHistory() {
        periodStartDates = CyclePeriodHistoryStore.dates()
    }

    private func recordPeriodStart(_ date: Date) {
        periodHistoryMutation = CyclePeriodHistoryStore.record(date)
        refreshPeriodHistory()
        WatchCompanionSync.shared.synchronizeCurrentPractice()
    }

    private func undoPeriodStart() {
        guard let periodHistoryMutation else { return }
        CyclePeriodHistoryStore.restore(periodHistoryMutation)
        self.periodHistoryMutation = nil
        refreshPeriodHistory()
        WatchCompanionSync.shared.synchronizeCurrentPractice()
    }

    private func phaseInfo(for calculation: CycleCalculation) -> ContextualInfoContent {
        CycleInfoProvider.content(for: calculation.currentPhase)
    }

    private func localized(_ key: String) -> String {
        selectedLanguage.localizedString(forKey: key)
    }

    private func cycleTotalDaysText(_ length: Int) -> String {
        String(
            format: selectedLanguage.localizedString(forKey: "cycle.home.total_days"),
            locale: locale,
            length
        )
    }

    private func progressAccessibilityValue(
        calculation: CycleCalculation,
        profile: CycleProfile
    ) -> String {
        String(
            format: String(localized: "cycle.home.progress.value", locale: locale),
            locale: locale,
            calculation.currentCycleDay,
            profile.averageCycleLength
        )
    }

    private var greetingText: String {
        let format = selectedLanguage.localizedString(forKey: greetingLocalizationKey)
        return String(format: format, locale: locale, userName)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }

    private var greetingLocalizationKey: String {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "cycle.home.greeting.morning"
        case 12..<18:
            return "cycle.home.greeting.day"
        default:
            return "cycle.home.greeting.evening"
        }
    }

    private var userInitial: String {
        guard let firstCharacter = userName.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "A"
        }
        return String(firstCharacter).uppercased(with: locale)
    }

    private func cycleDayText(_ day: Int) -> String {
        let format = selectedLanguage.localizedString(forKey: "cycle.home.day")
        return String(format: format, locale: locale, day)
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

    private func editCycle() {
        isSettingsPresented = false
        isEditingCycle = true
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

    private func offlinePackageTaskID(
        calculation: CycleCalculation,
        profile: CycleProfile
    ) -> String {
        [
            isOfflineListeningEnabled ? "enabled" : "disabled",
            String(calculation.currentCycleDay),
            String(profile.averageCycleLength),
            selectedLanguage.rawValue
        ].joined(separator: "-")
    }

    private func syncOfflinePackage(
        calculation: CycleCalculation,
        profile: CycleProfile
    ) {
        guard isOfflineListeningEnabled else { return }
        OfflineMeditationManager.shared.syncCyclePackage(
            currentDay: calculation.currentCycleDay,
            cycleLength: profile.averageCycleLength,
            language: selectedLanguage
        )
    }
}


#Preview("Cycle Home — Türkçe") {
    NavigationStack {
        CycleHomeView()
            .environment(\.locale, Locale(identifier: "tr"))
    }
}
