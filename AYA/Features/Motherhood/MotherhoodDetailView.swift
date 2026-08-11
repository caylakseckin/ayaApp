import SwiftUI

struct MotherhoodDetailView: View {
    private let showThemesAction: (() -> Void)?

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @AppStorage("user.name") private var userName = ""
    @AppStorage(MotherhoodPersistenceKeys.ageRange) private var ageRangeRawValue = ""

    @State private var isSettingsPresented = false
    @State private var isStagesPresented = false
    @State private var isAgeRangeEditorPresented = false
    @State private var selectedMeditation: DailyMeditation?
    @State private var infoContent: ContextualInfoContent?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let meditationProvider = MotherhoodMeditationProvider()
    // Retained for a possible future return of the motherhood overview timeline.
    private let showsOverviewTimeline = true

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
        .fullScreenCover(item: $selectedMeditation) { meditation in
            HESIAMeditationTransitionContainer {
                MeditationPlayerView(meditation: meditation, autoPlay: true)
                    .environment(\.locale, locale)
                    .tint(AYAColors.primary)
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
    }

    private var selectedRange: MotherhoodAgeRange? {
        MotherhoodAgeRange(rawValue: ageRangeRawValue)
    }

    private func homeContent(range: MotherhoodAgeRange) -> some View {
        let meditation = meditationProvider.meditation(for: range)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(range: range)

                MotherhoodInsightCard(range: range)

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("motherhood.detail.todayMeditation")

                    DailyMeditationCard(
                        meditation: meditation,
                        infoAccessibilityLabel: motherhoodInfoAccessibility(for: range),
                        infoAction: { infoContent = MotherhoodInfoProvider.content(for: range) },
                        start: { selectedMeditation = meditation }
                    )
                }

                if showsOverviewTimeline {
                    MotherhoodOverviewSection(
                        selectedRange: range,
                        viewStages: { isStagesPresented = true }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
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

    private func header(range: MotherhoodAgeRange) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(verbatim: greetingText)
                    .ayaTypography(.homeGreeting)
                    .foregroundStyle(AYAColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(verbatim: localized(range.detailSubtitleLocalizationKey))
                    .ayaTypography(.homeSupporting)
                    .foregroundStyle(AYAColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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

private struct MotherhoodInsightCard: View {
    let range: MotherhoodAgeRange

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let detailTheme = LifeStageDetailTheme.theme(for: .motherhood03)
    private let badgeHorizontalPadding: CGFloat = 11

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
            currentText: localized(range.shortTitleLocalizationKey),
            totalLabelKey: "motherhood.detail.ageUnit",
            progress: range.progress,
            accessibilityLabelKey: "motherhood.detail.progress.accessibility",
            accessibilityValue: localized(range.titleLocalizationKey),
            trackColor: detailTheme.ringTrack,
            progressColor: detailTheme.ringProgress
        )
    }

    private var insight: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: localized(range.badgeLocalizationKey))
                .ayaTypography(.homeBadge)
                .foregroundStyle(AYAColors.emphasis)
                .padding(.horizontal, badgeHorizontalPadding)
                .frame(minHeight: 27)
                .background(detailTheme.badgeSurface, in: Capsule())
                .alignmentGuide(.leading) { dimensions in
                    dimensions[.leading] + badgeHorizontalPadding
                }

            Text(verbatim: localized(range.insightTitleLocalizationKey))
                .ayaTypography(.homeInsightTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: localized(range.insightBodyLocalizationKey))
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
