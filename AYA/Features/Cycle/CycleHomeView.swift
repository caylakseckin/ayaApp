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
    @State private var playbackSession: MeditationPlaybackSession?
    @State private var isPlayerPresented = false
    @State private var isPlaybackContinuationToastPresented = false
    @State private var infoContent: ContextualInfoContent?
    @State private var remoteMeditationMetadata: RemoteMeditationMetadata?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    private let calculator = CycleCalculator()
    private let meditationProvider = DailyMeditationProvider()
    // Retained for a possible future return of the cycle overview timeline.
    private let showsOverviewTimeline = true

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
                CycleCalendarView(profile: profile)
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

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(calculation: calculation)

                CycleSummaryView(
                    profile: profile,
                    calculation: calculation,
                    showInfo: { infoContent = $0 }
                )

                VStack(alignment: .leading, spacing: AYASpacing.md) {
                    SectionHeader("cycle.home.today_meditation")

                    DailyMeditationCard(
                        meditation: meditation,
                        remoteMetadata: remoteMeditationMetadata,
                        playbackViewModel: playbackViewModel(for: meditation)
                    ) {
                        startMeditation(meditation)
                    }
                }

                if showsOverviewTimeline {
                    CycleOverviewSection(
                        days: calculator.surroundingDays(
                            currentDay: calculation.currentCycleDay,
                            cycleLength: profile.averageCycleLength
                        ),
                        currentDay: calculation.currentCycleDay,
                        viewCalendar: { isCalendarPresented = true }
                    )
                }

            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
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
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
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
    }

    private func header(calculation: CycleCalculation) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(verbatim: greetingText)
                    .ayaTypography(.homeGreeting)
                    .foregroundStyle(AYAColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(verbatim: cycleDayText(calculation.currentCycleDay))
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
        remoteMeditationMetadata = nil
        guard let source = meditation.remoteAudioSource else {
            return
        }

        do {
            let metadata = try await RemoteMeditationContentLoader.loadMetadata(source: source)
            guard !Task.isCancelled else { return }
            remoteMeditationMetadata = metadata
        } catch {
            guard !Task.isCancelled else { return }
            remoteMeditationMetadata = nil
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

struct CycleSummaryView: View {
    let profile: CycleProfile
    let calculation: CycleCalculation
    let showInfo: (ContextualInfoContent) -> Void

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    private let detailTheme = LifeStageDetailTheme.theme(for: .cycle)

    var body: some View {
        Group {
            if usesVerticalLayout {
                VStack(alignment: .leading, spacing: 16) {
                    progressRing
                        .frame(maxWidth: .infinity, alignment: .center)
                    phaseInsight
                }
            } else {
                HStack(spacing: 16) {
                    progressRing
                    phaseInsight
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
        ZStack {
            Circle()
                .stroke(detailTheme.ringTrack, lineWidth: 7)

            Circle()
                .trim(from: 0, to: min(max(calculation.cycleProgress, 0), 1))
                .stroke(
                    detailTheme.ringProgress,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(calculation.currentCycleDay)")
                    .ayaTypography(.homeMetricValue)
                    .foregroundStyle(AYAColors.textPrimary)
                Text("/ \(profile.averageCycleLength)")
                    .ayaTypography(.homeMetadata)
                    .foregroundStyle(AYAColors.textTertiary)
                Text("cycle.unit.day")
                    .ayaTypography(.homeMetadata)
                    .foregroundStyle(AYAColors.textTertiary)
            }
        }
        .frame(width: 112, height: 112)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("cycle.home.progress.accessibility")
        .accessibilityValue(progressAccessibilityValue)
    }

    private var phaseInsight: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                Text(verbatim: localized(calculation.currentPhase.nameLocalizationKey))
                    .ayaTypography(.homeBadge)
                    .foregroundStyle(AYAColors.emphasis)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 26)
                    .background(
                        detailTheme.badgeSurface,
                        in: Capsule()
                    )

                ContextualInfoButton(
                    accessibilityLabel: localized(phaseInfo.accessibilityLabelKey),
                    action: { showInfo(phaseInfo) }
                )
            }

            Text(verbatim: localized(calculation.currentPhase.insightTitleLocalizationKey))
                .ayaTypography(.homeInsightTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: localized(calculation.currentPhase.insightDescriptionLocalizationKey))
                .ayaTypography(.homeBody)
                .foregroundStyle(AYAColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var phaseInfo: ContextualInfoContent {
        CycleInfoProvider.content(for: calculation.currentPhase)
    }

    private var usesVerticalLayout: Bool {
        dynamicTypeSize >= .xxxLarge
    }

    private func localized(_ key: String) -> String {
        let language = AppLanguage(rawValue: languageCode) ?? .system
        return language.localizedString(forKey: key)
    }

    private var progressAccessibilityValue: String {
        let format = String(localized: "cycle.home.progress.value", locale: locale)
        return String(
            format: format,
            locale: locale,
            calculation.currentCycleDay,
            profile.averageCycleLength
        )
    }
}

struct DailyMeditationCard: View {
    let meditation: DailyMeditation
    let remoteMetadata: RemoteMeditationMetadata?
    let playbackViewModel: MeditationPlayerViewModel?
    let infoAccessibilityLabel: String?
    let infoAction: (() -> Void)?
    let start: () -> Void

    @Environment(\.locale) private var locale
    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @State private var excludedTapFrames: [CGRect] = []

    private let coordinateSpaceName = "dailyMeditationCard"

    init(
        meditation: DailyMeditation,
        remoteMetadata: RemoteMeditationMetadata? = nil,
        playbackViewModel: MeditationPlayerViewModel? = nil,
        infoAccessibilityLabel: String? = nil,
        infoAction: (() -> Void)? = nil,
        start: @escaping () -> Void
    ) {
        self.meditation = meditation
        self.remoteMetadata = remoteMetadata
        self.playbackViewModel = playbackViewModel
        self.infoAccessibilityLabel = infoAccessibilityLabel
        self.infoAction = infoAction
        self.start = start
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 2) {
                Text(verbatim: titleText)
                    .ayaTypography(.homeMeditationTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let infoAction, let infoAccessibilityLabel {
                    ContextualInfoButton(
                        accessibilityLabel: infoAccessibilityLabel,
                        action: infoAction
                    )
                    .background {
                        interactiveControlFrameReader
                    }
                }
            }

            Text(verbatim: meditation.localizedContext(language: selectedLanguage, locale: locale))
                .ayaTypography(.homeBadge)
                .foregroundStyle(AYAColors.textSecondary)
                .padding(.top, 6)

            Text(verbatim: descriptionText)
                .ayaTypography(.homeBody)
                .foregroundStyle(AYAColors.textSecondary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            HStack(alignment: .center, spacing: AYASpacing.md) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) {
                        metadata(icon: .clock, text: durationText)
                        Rectangle()
                            .fill(AYAColors.divider)
                            .frame(width: 1, height: 18)
                            .accessibilityHidden(true)
                        metadata(icon: .headphones, text: voiceText)
                    }

                    VStack(alignment: .leading, spacing: AYASpacing.xs) {
                        metadata(icon: .clock, text: durationText)
                        metadata(icon: .headphones, text: voiceText)
                    }
                }

                Spacer(minLength: AYASpacing.md)

                playbackControl
                .accessibilityIdentifier("cycle.home.meditation.start")
                .offset(x: -6, y: -6)
                .background {
                    interactiveControlFrameReader
                }
            }
            .padding(.top, AYASpacing.xl)
        }
        .padding(AYASpacing.lg)
        .contentShape(RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))
        .coordinateSpace(name: coordinateSpaceName)
        .onPreferenceChange(DailyMeditationInteractiveControlFramesKey.self) {
            excludedTapFrames = $0
        }
        .onTapGesture(coordinateSpace: .named(coordinateSpaceName)) { location in
            guard !excludedTapFrames.contains(where: { $0.contains(location) }) else { return }
            start()
        }
        .background(AYAColors.surface, in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(AYAColors.border, lineWidth: 1)
        }
    }

    private var durationText: String {
        let format = String(localized: "meditation.duration.minutes", locale: locale)
        return String(
            format: format,
            locale: locale,
            remoteMetadata?.durationMinutes ?? meditation.durationMinutes
        )
    }

    private var titleText: String {
        remoteMetadata?.localizedTitle(for: selectedLanguage)
            ?? selectedLanguage.localizedString(forKey: meditation.titleLocalizationKey)
    }

    private var descriptionText: String {
        remoteMetadata?.localizedDescription(for: selectedLanguage)
            ?? selectedLanguage.localizedString(forKey: meditation.descriptionLocalizationKey)
    }

    private var voiceText: String {
        guard let narrator = remoteMetadata?.narrator else {
            return selectedLanguage.localizedString(forKey: meditation.voiceLocalizationKey)
        }
        let format = selectedLanguage.localizedString(forKey: "meditation.player.voice_format")
        return String(format: format, locale: locale, narrator)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }

    @ViewBuilder
    private var playbackControl: some View {
        if let playbackViewModel {
            ActiveMeditationCardButton(
                viewModel: playbackViewModel,
                action: start
            )
        } else {
            Button(action: start) {
                MeditationCardPlayIcon()
                    .frame(width: 54, height: 54)
                    .background(AYAColors.emphasis, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("meditation.start")
        }
    }

    private var interactiveControlFrameReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: DailyMeditationInteractiveControlFramesKey.self,
                value: [proxy.frame(in: .named(coordinateSpaceName))]
            )
        }
    }

    private func metadata(icon: HesiaIcon, text: String) -> some View {
        HStack(spacing: 5) {
            icon.view(size: 14)
            Text(verbatim: text)
        }
        .ayaTypography(.homeMetadata)
        .foregroundStyle(AYAColors.textTertiary)
    }
}

private struct DailyMeditationInteractiveControlFramesKey: PreferenceKey {
    static var defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

private struct ActiveMeditationCardButton: View {
    @ObservedObject var viewModel: MeditationPlayerViewModel
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if viewModel.isLoadingAudio {
                    ProgressView()
                        .tint(AYAColors.onAccent)
                } else if viewModel.isPlaying {
                    PlaybackWaveformIndicator(isPlaying: true)
                } else {
                    MeditationCardPlayIcon()
                }
            }
            .frame(width: 54, height: 54)
            .background(AYAColors.emphasis, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: LocalizedStringKey {
        if viewModel.isLoadingAudio {
            return "meditation.player.loading"
        }
        return viewModel.isPlaying
            ? "meditation.player.open_playing"
            : "meditation.player.open"
    }
}

private struct MeditationCardPlayIcon: View {
    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(AYAColors.onAccent)
    }
}

private struct CycleOverviewSection: View {
    let days: [Int]
    let currentDay: Int
    let viewCalendar: () -> Void
    private let detailTheme = LifeStageDetailTheme.theme(for: .cycle)

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.xs) {
            SectionHeader("cycle.home.overview") {
                Button(action: viewCalendar) {
                    HStack(spacing: AYASpacing.xs) {
                        Text("cycle.home.view_calendar")
                        HesiaIcon.caretRight.view(size: 12)
                    }
                    .ayaTypography(.homeLink)
                    .foregroundStyle(AYAColors.accent)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cycle.home.calendar.button")
            }

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        TimelineDay(
                            day: day,
                            isCurrent: day == currentDay,
                            relativeOffset: index - (days.count / 2),
                            detailTheme: detailTheme
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("cycle.home.timeline.accessibility")
            .accessibilityValue("\(currentDay)")
        }
    }
}

private struct TimelineDay: View {
    let day: Int
    let isCurrent: Bool
    let relativeOffset: Int
    let detailTheme: LifeStageDetailTheme

    var body: some View {
        VStack(spacing: 7) {
            Text("\(day)")
                .ayaTypography(.homeMetadata)
                .foregroundStyle(isCurrent ? AYAColors.onAccent : AYAColors.textTertiary)
                .frame(width: 32, height: 32)
                .background(isCurrent ? detailTheme.timelineActive : AYAColors.surface, in: Circle())
                .overlay {
                    if !isCurrent {
                        Circle().stroke(AYAColors.separator, lineWidth: 1)
                    }
                }

            marker
        }
    }

    // Minimal per-day phase marker: burgundy for the current day, a soft filled
    // dot for past days, and a light empty ring for upcoming days. No connecting
    // line — keeps the timeline calm and editorial rather than dashboard-like.
    private var marker: some View {
        Circle()
            .fill(markerFill)
            .frame(width: 6, height: 6)
            .overlay {
                if markerIsUpcoming {
                    Circle().stroke(AYAColors.separator, lineWidth: 1)
                }
            }
            .accessibilityHidden(true)
    }

    private var markerFill: Color {
        if isCurrent { return detailTheme.timelineActive }
        return relativeOffset < 0 ? detailTheme.timelineInactive : .clear
    }

    private var markerIsUpcoming: Bool {
        !isCurrent && relativeOffset > 0
    }
}

private enum CyclePhaseStyle {
    static func surface(for phase: CyclePhase) -> Color {
        switch phase {
        case .menstrual: AYAColors.softPink.opacity(0.42)
        case .follicular: AYAColors.tertiary.opacity(0.52)
        case .ovulatory: AYAColors.primary.opacity(0.12)
        case .luteal: AYAColors.softPink.opacity(0.30)
        }
    }
}

#Preview("Cycle Home — Türkçe") {
    NavigationStack {
        CycleHomeView()
            .environment(\.locale, Locale(identifier: "tr"))
    }
}
