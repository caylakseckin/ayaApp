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
    @State private var isMeditationBrowserPresented = false
    @State private var playbackSession: MeditationPlaybackSession?
    @State private var isPlayerPresented = false
    @State private var isPlaybackContinuationToastPresented = false
    @State private var weekInfoPresentation: PregnancyWeekInfoPresentation?
    @State private var metadataState: DailyMeditationMetadataState = .loading

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    private let tracker = PregnancyTracker()
    private let contentProvider = PregnancyContentProvider()
    private let detailTheme = LifeStageDetailTheme.theme(for: .pregnancy)

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
            PregnancyWeekEditorView(
                initialWeek: currentWeek,
                initialWeekStartDay: currentWeekStartDay
            ) { newWeek, newWeekStartDay in
                updatePregnancyWeek(newWeek, weekStartDay: newWeekStartDay)
                isWeekEditorPresented = false
            }
            .environment(\.locale, locale)
        }
        .sheet(isPresented: $isMeditationBrowserPresented) {
            JourneyMeditationBrowser(journey: .pregnancy, currentValue: currentWeek)
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
        guard let profile else {
            return min(
                max(referenceWeek, PregnancyTracker.supportedWeekRange.lowerBound),
                PregnancyTracker.supportedWeekRange.upperBound
            )
        }
        return tracker.calculate(profile: profile).currentWeek
    }

    private var currentWeekStartDay: PregnancyWeekStartDay {
        guard let profile else { return .monday }
        return tracker.weekStartDay(for: profile.referenceDate)
    }

    private func homeContent(profile: PregnancyProfile) -> some View {
        let calculation = tracker.calculate(profile: profile)
        let meditation = contentProvider.meditation(for: calculation)

        return HomeScreenScaffold(contentTopPadding: AYALayout.screenTopPadding) {
            HomeHeader(
                greeting: greetingText,
                userInitial: userInitial,
                showsProfileButton: !isSettingsPresented,
                openSettings: { isSettingsPresented = true }
            ) {
                HomeHeaderDetail(text: pregnancyWeekText(calculation.currentWeek))
            }
        } content: {
            PregnancyHeroCard(
                theme: detailTheme,
                weekDisplay: heroWeekDisplay(calculation.currentWeek),
                badgeText: localized(calculation.trimester.nameLocalizationKey),
                title: localized(calculation.trimester.insightTitleLocalizationKey),
                message: localized(calculation.trimester.insightDescriptionLocalizationKey),
                accessibilityValue: progressAccessibilityValue(calculation: calculation),
                weekInsightDescription: weekInsightDescription(for: calculation.currentWeek),
                weekInsightAction: { showWeekInfo(for: calculation.currentWeek) }
            )

            VStack(alignment: .leading, spacing: AYASpacing.md) {
                SectionHeader("pregnancy.home.today_meditation")

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
                titleKey: "pregnancy.overview.title",
                linkKey: "pregnancy.overview.view_calendar",
                linkAccessibilityIdentifier: "pregnancy.home.calendar.button",
                action: { isCalendarPresented = true }
            ) {
                PregnancyOverviewJourney(
                    theme: detailTheme,
                    values: tracker.overviewWeeks(around: calculation.currentWeek),
                    currentValue: calculation.currentWeek
                )
            }

            if calculation.shouldOfferBirthMomentTransition {
                LifeStageContinuationCard(
                    destination: .birthMoment,
                    titleKey: "pregnancy.transition.birth_moment.title",
                    messageKey: "pregnancy.transition.birth_moment.message",
                    actionKey: "pregnancy.transition.birth_moment.action",
                    action: continueToBirthMoment
                )
            }
        }
        .task(id: meditation.id) {
            await loadRemoteMetadata(for: meditation, calculation: calculation)
        }
        .task(id: offlinePackageTaskID(calculation: calculation)) {
            syncOfflinePackage(calculation: calculation)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let refreshedCalculation = tracker.calculate(profile: profile)
            syncOfflinePackage(calculation: refreshedCalculation)
        }
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

    private func localized(_ key: String) -> String {
        selectedLanguage.localizedString(forKey: key)
    }

    private func progressAccessibilityValue(calculation: PregnancyCalculation) -> String {
        String(
            format: selectedLanguage.localizedString(forKey: "pregnancy.home.progress.value"),
            locale: locale,
            calculation.currentWeek,
            40
        )
    }

    private func weekInsightDescription(for week: Int) -> String {
        guard let description = PregnancyWeekInfoRepository.shared
            .info(for: week, language: selectedLanguage)?.baby
        else {
            return localized("pregnancy.week_insight.fallback")
        }

        guard let sentenceEnd = description.firstIndex(of: ".") else {
            return description
        }
        return String(description[...sentenceEnd])
    }

    private func heroWeekDisplay(_ week: Int) -> String {
        HesiaOrdinalFormatter.string(week, language: selectedLanguage)
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

    private func showWeekInfo(for week: Int) {
        weekInfoPresentation = PregnancyWeekInfoPresentation(
            week: week,
            language: selectedLanguage,
            content: PregnancyWeekInfoRepository.shared.info(for: week, language: selectedLanguage)
        )
    }

    private func loadRemoteMetadata(
        for meditation: DailyMeditation,
        calculation: PregnancyCalculation
    ) async {
        guard let source = meditation.remoteAudioSource else {
            metadataState = .loaded(nil)
            WatchCompanionSync.shared.sendPregnancyPractice(
                meditation: meditation,
                calculation: calculation,
                metadata: nil,
                language: selectedLanguage
            )
            return
        }

        metadataState = .loading
        do {
            let metadata = try await RemoteMeditationContentLoader.loadMetadata(source: source)
            guard !Task.isCancelled else { return }
            metadataState = .loaded(metadata)
            WatchCompanionSync.shared.sendPregnancyPractice(
                meditation: meditation,
                calculation: calculation,
                metadata: metadata,
                language: selectedLanguage
            )
        } catch {
            guard !Task.isCancelled else { return }
            metadataState = .failed
            WatchCompanionSync.shared.sendPregnancyPractice(
                meditation: meditation,
                calculation: calculation,
                metadata: nil,
                language: selectedLanguage
            )
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

    private func updatePregnancyWeek(
        _ week: Int,
        weekStartDay: PregnancyWeekStartDay
    ) {
        referenceWeek = min(
            max(week, PregnancyTracker.supportedWeekRange.lowerBound),
            PregnancyTracker.supportedWeekRange.upperBound
        )
        referenceTimestamp = tracker.referenceDate(for: weekStartDay).timeIntervalSince1970
        isOnboardingCompleted = true
    }

    private func continueToBirthMoment() {
        stopPlaybackSession()
        activeStageRawValue = LifeStage.birthMoment.rawValue
    }
}

private struct PregnancyHeroCard: View {
    let theme: LifeStageDetailTheme
    let weekDisplay: String
    let badgeText: String
    let title: String
    let message: String
    let accessibilityValue: String
    let weekInsightDescription: String
    let weekInsightAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.lg) {
            HesiaBadge(verbatim: badgeText, prominence: .themed(theme.badgeSurface))

            HeroAdaptiveRow {
                HeroMetricColumn(
                    value: weekDisplay,
                    unitKey: "pregnancy.hero.week_unit",
                    accessibilityLabelKey: "pregnancy.home.progress.accessibility",
                    accessibilityValue: accessibilityValue
                )
            } trailing: {
                HeroInsight(title: title, message: message)
            }

            HeroDivider(theme: theme)

            PregnancyWeekInsight(
                theme: theme,
                description: weekInsightDescription,
                action: weekInsightAction
            )
        }
        .lifeStageHeroSurface(theme: theme)
    }
}

private struct PregnancyWeekInsight: View {
    let theme: LifeStageDetailTheme
    let description: String
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            insightLayout
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(HesiaCardButtonStyle())
        .accessibilityLabel("pregnancy.week_insight.title")
        .accessibilityValue(Text(verbatim: description))
        .accessibilityHint("pregnancy.week_insight.accessibility_hint")
    }

    private var insightTitle: some View {
        Text("pregnancy.week_insight.title")
            .ayaTypography(.homeLink)
            .foregroundStyle(AYAColors.emphasis)
            .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var insightLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AYASpacing.sm) {
                insightTitle

                HStack(alignment: .top, spacing: AYASpacing.sm) {
                    Rectangle()
                        .fill(theme.timelineConnector)
                        .frame(width: 1)
                        .accessibilityHidden(true)

                    insightDescription
                    chevron
                }
            }
        } else {
            HStack(alignment: .center, spacing: AYASpacing.sm) {
                insightTitle

                Rectangle()
                    .fill(theme.timelineConnector)
                    .frame(width: 1, height: 40)
                    .accessibilityHidden(true)

                insightDescription
                chevron
            }
        }
    }

    private var insightDescription: some View {
        Text(verbatim: description)
            .ayaTypography(.homeBody)
            .foregroundStyle(AYAColors.textPrimary)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 4)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
    }

    private var chevron: some View {
        HesiaIcon.caretRight.view(size: HesiaIconSize.sm)
            .foregroundStyle(AYAColors.emphasis)
            .frame(width: HesiaIconSize.md, height: 44)
            .accessibilityHidden(true)
    }
}

#Preview("Pregnancy Week Insight — Content Lengths", traits: .fixedLayout(width: 393, height: 430)) {
    let theme = LifeStageDetailTheme.theme(for: .pregnancy)

    VStack(alignment: .leading, spacing: AYASpacing.lg) {
        PregnancyWeekInsight(
            theme: theme,
            description: "Bebeğin büyümeye devam ediyor.",
            action: {}
        )

        HeroDivider(theme: theme)

        PregnancyWeekInsight(
            theme: theme,
            description: "Bebeğinin hareketleri güçleniyor; dinlenme ve uyanıklık ritmi daha belirgin hale geliyor.",
            action: {}
        )

        HeroDivider(theme: theme)

        PregnancyWeekInsight(
            theme: theme,
            description: "Bebeğinin duyuları gelişmeye devam ederken hareketleri daha belirgin hissedilebilir; kendi ritmini dinleyerek dinlenmeye alan açabilirsin.",
            action: {}
        )
    }
    .lifeStageHeroSurface(theme: theme)
    .padding(AYASpacing.xl)
    .background(AYAColors.backgroundPrimary)
    .environment(\.locale, Locale(identifier: "tr"))
}

#Preview("Pregnancy Week Insight — Compact English", traits: .fixedLayout(width: 320, height: 250)) {
    let theme = LifeStageDetailTheme.theme(for: .pregnancy)

    PregnancyWeekInsight(
        theme: theme,
        description: "Your baby is becoming more responsive to sound and movement while a clearer rhythm of rest begins to emerge.",
        action: {}
    )
    .lifeStageHeroSurface(theme: theme)
    .padding(AYASpacing.lg)
    .background(AYAColors.backgroundPrimary)
    .environment(\.locale, Locale(identifier: "en"))
}

#Preview("Pregnancy Week Insight — Dynamic Type", traits: .fixedLayout(width: 393, height: 360)) {
    let theme = LifeStageDetailTheme.theme(for: .pregnancy)

    PregnancyWeekInsight(
        theme: theme,
        description: "Bebeğinin hareketleri güçlenirken dinlenme ve uyanıklık ritmi daha belirgin hale geliyor.",
        action: {}
    )
    .lifeStageHeroSurface(theme: theme)
    .padding(AYASpacing.xl)
    .background(AYAColors.backgroundPrimary)
    .environment(\.locale, Locale(identifier: "tr"))
    .environment(\.dynamicTypeSize, .accessibility2)
}

private struct PregnancyOverviewJourney: View {
    let theme: LifeStageDetailTheme
    let values: [Int]
    let currentValue: Int

    @AppStorage("app.language") private var languageCode = AppLanguage.defaultExplicitLanguage.rawValue
    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            Capsule()
                .fill(theme.timelineConnector)
                .frame(height: 1)
                .padding(.horizontal, AYASpacing.lg)
                .accessibilityHidden(true)

            HStack(spacing: 0) {
                ForEach(values, id: \.self) { week in
                    overviewMarker(for: week)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("pregnancy.overview.accessibility")
    }

    private func overviewMarker(for week: Int) -> some View {
        let isCurrent = week == currentValue

        return Text(verbatim: String(week))
            .ayaTypography(.homeMetadata)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .foregroundStyle(isCurrent ? AYAColors.onAccent : AYAColors.textSecondary)
            .frame(width: 32, height: 32)
            .background(isCurrent ? AYAColors.emphasis : AYAColors.surfaceElevated, in: Circle())
            .overlay {
                if !isCurrent {
                    Circle().stroke(theme.heroBorder, lineWidth: 1)
                }
            }
            .accessibilityLabel(accessibilityLabel(for: week, isCurrent: isCurrent))
            .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func accessibilityLabel(for week: Int, isCurrent: Bool) -> String {
        let key = isCurrent
            ? "pregnancy.home.progress.value"
            : "pregnancy.journey.week.accessibility"
        let format = selectedLanguage.localizedString(forKey: key)

        if isCurrent {
            return String(format: format, locale: locale, week, 40)
        }
        return String(format: format, locale: locale, week)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .defaultExplicitLanguage
    }
}

#Preview("Pregnancy Journey — 393 pt", traits: .fixedLayout(width: 393, height: 852)) {
    ScrollView {
        VStack(alignment: .leading, spacing: AYALayout.sectionSpacing) {
            PregnancyHeroCard(
                theme: .theme(for: .pregnancy),
                weekDisplay: "30.",
                badgeText: "3. Trimester",
                title: "Büyümenin ritmine yerleşiyorsun.",
                message: "Bedenin değişirken, nefesin ve bebeğinle bağın daha görünür hale geliyor.",
                accessibilityValue: "Toplam 40 haftanın 30. haftası",
                weekInsightDescription: "Bebeğinin emme refleksi güçleniyor; artık parmağını emebiliyor.",
                weekInsightAction: {}
            )

            LifeStageOverviewSection(
                titleKey: "pregnancy.overview.title",
                linkKey: "pregnancy.overview.view_calendar",
                linkAccessibilityIdentifier: "pregnancy.home.calendar.button",
                action: {}
            ) {
                PregnancyOverviewJourney(
                    theme: .theme(for: .pregnancy),
                    values: Array(27...34),
                    currentValue: 30
                )
            }
        }
        .hesiaScreenPadding()
    }
    .background(AYAColors.backgroundPrimary)
    .environment(\.locale, Locale(identifier: "tr"))
}

#Preview("Pregnancy Journey — Small + English", traits: .fixedLayout(width: 320, height: 720)) {
    ScrollView {
        VStack(alignment: .leading, spacing: AYALayout.sectionSpacing) {
            PregnancyHeroCard(
                theme: .theme(for: .pregnancy),
                weekDisplay: "21st",
                badgeText: "2nd Trimester",
                title: "You are settling into the rhythm of growth.",
                message: "As your body changes, your connection with your breath and your baby becomes more visible.",
                accessibilityValue: "Week 21 of 40 weeks",
                weekInsightDescription: "Your baby’s sleep and wake patterns are beginning to develop.",
                weekInsightAction: {}
            )

            LifeStageOverviewSection(
                titleKey: "pregnancy.overview.title",
                linkKey: "pregnancy.overview.view_calendar",
                linkAccessibilityIdentifier: "pregnancy.home.calendar.button",
                action: {}
            ) {
                PregnancyOverviewJourney(
                    theme: .theme(for: .pregnancy),
                    values: Array(18...25),
                    currentValue: 21
                )
            }
        }
        .hesiaScreenPadding()
    }
    .background(AYAColors.backgroundPrimary)
    .environment(\.locale, Locale(identifier: "en"))
}

struct PregnancyWeekEditorView: View {
    let initialWeek: Int
    let initialWeekStartDay: PregnancyWeekStartDay
    let save: (Int, PregnancyWeekStartDay) -> Void

    @State private var selectedWeek: Int
    @State private var selectedWeekStartDay: PregnancyWeekStartDay?
    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(
        initialWeek: Int,
        initialWeekStartDay: PregnancyWeekStartDay,
        save: @escaping (Int, PregnancyWeekStartDay) -> Void
    ) {
        self.initialWeek = initialWeek
        self.initialWeekStartDay = initialWeekStartDay
        self.save = save
        _selectedWeek = State(
            initialValue: min(
                max(initialWeek, PregnancyTracker.supportedWeekRange.lowerBound),
                PregnancyTracker.supportedWeekRange.upperBound
            )
        )
        _selectedWeekStartDay = State(initialValue: initialWeekStartDay)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AYASpacing.lg) {
                HStack {
                    Text("pregnancy.settings.title")
                        .ayaTypography(.screenTitle)
                        .foregroundStyle(AYAColors.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        HesiaIcon.close.view(size: HesiaIconSize.sm)
                            .foregroundStyle(AYAColors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(AYAColors.surfaceElevated, in: Circle())
                            .overlay { Circle().stroke(AYAColors.separator, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("common.close")
                }

                Picker("pregnancy.settings.title", selection: $selectedWeek) {
                    ForEach(PregnancyTracker.supportedWeekRange, id: \.self) { week in
                        Text(verbatim: formattedWeek(week)).tag(week)
                    }
                }
                .pickerStyle(.wheel)

                PregnancyWeekStartDayPicker(selection: $selectedWeekStartDay)

                Button {
                    guard let selectedWeekStartDay else { return }
                    save(selectedWeek, selectedWeekStartDay)
                } label: {
                    Text("pregnancy.settings.update")
                }
                .buttonStyle(.appPrimary)
                .disabled(selectedWeekStartDay == nil)
                .accessibilityIdentifier("pregnancy.settings.update")
            }
            .hesiaScreenPadding()
            .padding(.vertical, AYASpacing.xl)
        }
        .scrollIndicators(.hidden)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.large])
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
