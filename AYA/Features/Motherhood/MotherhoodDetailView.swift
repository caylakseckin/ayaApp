import SwiftUI

struct MotherhoodDetailView: View {
    private let detailTheme = LifeStageDetailTheme.theme(for: .motherhood03)
    private let showThemesAction: (() -> Void)?

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @AppStorage("user.name") private var userName = ""
    @AppStorage(MotherhoodPersistenceKeys.ageRange) private var ageRangeRawValue = ""

    @State private var isSettingsPresented = false
    @State private var isStagesPresented = false
    @State private var isAgeRangeEditorPresented = false
    @State private var playbackSession: MeditationPlaybackSession?
    @State private var isPlayerPresented = false
    @State private var isPlaybackContinuationToastPresented = false
    @State private var infoContent: ContextualInfoContent?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let meditationProvider = MotherhoodMeditationProvider()
    // Retained for a possible future return of the motherhood overview timeline.

    init(showThemes: (() -> Void)? = nil) {
        showThemesAction = showThemes
    }

    var body: some View {
        Group {
            if let selectedRange {
                homeContent(range: selectedRange)
            } else {
                MotherhoodPersonalizationView(returnToThemes: showThemes) {}
            }
        }
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
        .sheet(isPresented: $isStagesPresented) {
            MotherhoodStagesSheet(
                selectedRange: selectedRange ?? .toddler
            )
                .environment(\.locale, locale)
        }
        .sheet(isPresented: $isAgeRangeEditorPresented) {
            MotherhoodAgeRangeEditorView(initialRange: selectedRange ?? .toddler) { range in
                ageRangeRawValue = range.rawValue
                isAgeRangeEditorPresented = false
            }
            .environment(\.locale, locale)
        }
        .sheet(item: $infoContent) { content in
            ContextualInfoSheet(content: content)
                .environment(\.locale, locale)
        }
        .meditationPlaybackContinuationToast(
            isPresented: $isPlaybackContinuationToastPresented
        )
    }

    private var selectedRange: MotherhoodAgeRange? {
        MotherhoodAgeRange(rawValue: ageRangeRawValue)
    }

    private func homeContent(range: MotherhoodAgeRange) -> some View {
        let meditation = meditationProvider.meditation(for: range)

        return HomeScreenScaffold {
            HomeHeader(
                greeting: greetingText,
                userInitial: userInitial,
                showsProfileButton: !isSettingsPresented,
                openSettings: { isSettingsPresented = true }
            ) {
                Text(verbatim: localized(range.detailSubtitleLocalizationKey))
                    .ayaTypography(.homeSupporting)
                    .foregroundStyle(AYAColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } content: {
            LifeStageHeroCard(
                theme: detailTheme,
                badgeText: localized(range.badgeLocalizationKey),
                title: localized(range.insightTitleLocalizationKey),
                message: localized(range.insightBodyLocalizationKey)
            ) {
                StageProgressRing(
                    currentText: localized(range.shortTitleLocalizationKey),
                    totalLabelKey: "motherhood.detail.ageUnit",
                    progress: range.progress,
                    accessibilityLabelKey: "motherhood.detail.progress.accessibility",
                    accessibilityValue: localized(range.titleLocalizationKey),
                    trackColor: detailTheme.ringTrack,
                    progressColor: detailTheme.ringProgress
                )
            }

            VStack(alignment: .leading, spacing: AYASpacing.md) {
                SectionHeader("motherhood.detail.todayMeditation") {
                    ContextualInfoButton(
                        accessibilityLabel: motherhoodInfoAccessibility(for: range),
                        action: { infoContent = MotherhoodInfoProvider.content(for: range) }
                    )
                }

                DailyMeditationCard(
                    meditation: meditation,
                    playbackViewModel: playbackViewModel(for: meditation)
                ) {
                    startMeditation(meditation)
                }
            }

            MotherhoodOverviewSection(
                selectedRange: range,
                viewStages: { isStagesPresented = true }
            )
        }
        .overlay {
            if isSettingsPresented {
                AYASettingsOverlay(
                    languageCode: $languageCode,
                    userName: $userName,
                    activeStage: .motherhood03,
                    close: closeSettings,
                    showThemes: showThemes,
                    motherhoodRange: range,
                    editMotherhood: editMotherhood
                )
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: isSettingsPresented)
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

    private var greetingText: String {
        let format = selectedLanguage.localizedString(forKey: greetingLocalizationKey)
        return String(format: format, locale: locale, userName)
    }

    private var greetingLocalizationKey: String {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: Date())
        return switch hour {
        case 5..<12: "motherhood.detail.greeting.morning"
        case 12..<18: "motherhood.detail.greeting.day"
        default: "motherhood.detail.greeting.evening"
        }
    }

    private var userInitial: String {
        guard let firstCharacter = userName.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "H"
        }
        return String(firstCharacter).uppercased(with: locale)
    }

    private func localized(_ key: String) -> String {
        selectedLanguage.localizedString(forKey: key)
    }

    private func motherhoodInfoAccessibility(for range: MotherhoodAgeRange) -> String {
        let content = MotherhoodInfoProvider.content(for: range)
        return localized(content.accessibilityLabelKey)
    }

    private func closeSettings() {
        isSettingsPresented = false
    }

    private func editMotherhood() {
        isSettingsPresented = false
        isAgeRangeEditorPresented = true
    }

    private func showThemes() {
        isSettingsPresented = false
        stopPlaybackSession()
        if let showThemesAction { showThemesAction() } else { dismiss() }
    }
}

private struct MotherhoodAgeRangeEditorView: View {
    let initialRange: MotherhoodAgeRange
    let save: (MotherhoodAgeRange) -> Void

    @State private var selectedRange: MotherhoodAgeRange
    @Environment(\.dismiss) private var dismiss

    init(
        initialRange: MotherhoodAgeRange,
        save: @escaping (MotherhoodAgeRange) -> Void
    ) {
        self.initialRange = initialRange
        self.save = save
        _selectedRange = State(initialValue: initialRange)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("settings.motherhood.age_range")
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

            Picker("settings.motherhood.age_range", selection: $selectedRange) {
                ForEach(MotherhoodAgeRange.allCases) { range in
                    Text(LocalizedStringKey(range.titleLocalizationKey)).tag(range)
                }
            }
            .pickerStyle(.wheel)
            .tint(AYAColors.primary)

            Button {
                save(selectedRange)
            } label: {
                Text("settings.motherhood.update")
            }
            .buttonStyle(.appPrimary)
            .accessibilityIdentifier("settings.motherhood.update")
        }
        .padding(22)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct MotherhoodOverviewSection: View {
    let selectedRange: MotherhoodAgeRange
    let viewStages: () -> Void

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    private let detailTheme = LifeStageDetailTheme.theme(for: .motherhood03)

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.xs) {
            SectionHeader("motherhood.detail.overviewTitle") {
                Button(action: viewStages) {
                    HStack(spacing: 5) {
                        Text("motherhood.detail.viewStages")
                        HesiaIcon.caretRight.view(size: 12)
                    }
                    .ayaTypography(.homeLink)
                    .foregroundStyle(AYAColors.emphasis)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("motherhood.detail.stages.button")
            }

            LifeStageHorizontalTimeline(
                values: localizedRanges,
                currentValue: localized(selectedRange.shortTitleLocalizationKey),
                accessibilityLabelKey: "motherhood.detail.stages.accessibility",
                activeColor: detailTheme.timelineActive,
                inactiveColor: detailTheme.timelineInactive,
                connectorColor: detailTheme.timelineConnector,
                fillsAvailableWidth: true
            )
        }
    }

    private var localizedRanges: [String] {
        MotherhoodAgeRange.allCases.map { localized($0.shortTitleLocalizationKey) }
    }

    private func localized(_ key: String) -> String {
        (AppLanguage(rawValue: languageCode) ?? .system).localizedString(forKey: key)
    }
}

private struct MotherhoodStagesSheet: View {
    let selectedRange: MotherhoodAgeRange

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AYASpacing.xl) {
                header

                VStack(spacing: AYASpacing.md) {
                    ForEach(MotherhoodAgeRange.allCases) { range in
                        stageCard(range)
                    }
                }

                Text("motherhood.journey.footer")
                    .ayaTypography(.metadata)
                    .foregroundStyle(AYAColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AYASpacing.lg)
            }
            .padding(.horizontal, AYASpacing.xl)
            .padding(.top, AYASpacing.md)
            .padding(.bottom, AYASpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AYASpacing.sm) {
            HStack(alignment: .center, spacing: AYASpacing.md) {
                Text("motherhood.detail.overviewTitle")
                    .ayaTypography(.screenTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: AYASpacing.sm)

                Button(action: { dismiss() }) {
                    HesiaIcon.close.view(size: 15)
                        .foregroundStyle(AYAColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AYAColors.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.close")
            }

            Text("motherhood.journey.subtitle")
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stageCard(_ range: MotherhoodAgeRange) -> some View {
        let isCurrent = range == selectedRange

        return VStack(alignment: .leading, spacing: AYASpacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AYASpacing.md) {
                    stageIdentity(range)
                    Spacer(minLength: AYASpacing.sm)
                    if isCurrent { currentBadge }
                }

                VStack(alignment: .leading, spacing: AYASpacing.sm) {
                    stageIdentity(range)
                    if isCurrent { currentBadge }
                }
            }

            Text(LocalizedStringKey(range.journeyDescriptionLocalizationKey))
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(LocalizedStringKey(range.journeyFocusLocalizationKey))
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AYASpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            isCurrent ? AYAColors.motherhoodHeroSurface : AYAColors.surfaceElevated,
            in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(isCurrent ? AYAColors.accent : AYAColors.border, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: stageAccessibilityLabel(range, isCurrent: isCurrent)))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func stageIdentity(_ range: MotherhoodAgeRange) -> some View {
        VStack(alignment: .leading, spacing: AYASpacing.xs) {
            Text(LocalizedStringKey(range.titleLocalizationKey))
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textTertiary)

            Text(LocalizedStringKey(range.journeyTitleLocalizationKey))
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentBadge: some View {
        Label {
            Text("motherhood.journey.state.current")
        } icon: {
            HesiaIcon.check.view(size: 12)
        }
            .ayaTypography(.metadata)
            .foregroundStyle(AYAColors.emphasis)
            .padding(.horizontal, AYASpacing.sm)
            .frame(minHeight: 28)
            .background(AYAColors.motherhoodSurface, in: Capsule())
            .fixedSize()
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }

    private func stageAccessibilityLabel(_ range: MotherhoodAgeRange, isCurrent: Bool) -> String {
        let format = selectedLanguage.localizedString(forKey: "motherhood.journey.stage.accessibility")
        let stateKey = isCurrent
            ? "motherhood.journey.state.current"
            : "motherhood.journey.state.other"

        return String(
            format: format,
            locale: locale,
            selectedLanguage.localizedString(forKey: range.journeyTitleLocalizationKey),
            selectedLanguage.localizedString(forKey: range.titleLocalizationKey),
            selectedLanguage.localizedString(forKey: stateKey),
            selectedLanguage.localizedString(forKey: range.journeyDescriptionLocalizationKey)
        )
    }
}

#Preview("Motherhood Detail — Türkçe") {
    NavigationStack {
        MotherhoodDetailView()
            .environment(\.locale, Locale(identifier: "tr"))
    }
}

#Preview("Motherhood Detail — English") {
    NavigationStack {
        MotherhoodDetailView()
            .environment(\.locale, Locale(identifier: "en"))
    }
}

#Preview("Motherhood Journey — Türkçe") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            MotherhoodStagesSheet(selectedRange: .infant)
                .environment(\.locale, Locale(identifier: "tr"))
        }
}

#Preview("Motherhood Journey — Large Type") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            MotherhoodStagesSheet(selectedRange: .preschool)
                .environment(\.locale, Locale(identifier: "en"))
                .environment(\.dynamicTypeSize, .accessibility3)
        }
}
