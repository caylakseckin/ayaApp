import SwiftUI

/// A focused, low-cognitive-load practice picker for the moment of birth.
/// Unlike the other life-stage homes, this screen intentionally has no time,
/// progress or transition metaphor.
struct BirthMomentHomeView: View {
    private let showThemesAction: (() -> Void)?

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @AppStorage("user.name") private var userName = ""
    @AppStorage(OfflineMeditationPreferenceKeys.isEnabled) private var isOfflineListeningEnabled = false
    @State private var isSettingsPresented = false
    @State private var playbackSession: MeditationPlaybackSession?
    @State private var isPlayerPresented = false
    @State private var isPlaybackContinuationToastPresented = false
    @State private var metadataStates: [String: DailyMeditationMetadataState] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let detailTheme = LifeStageDetailTheme.theme(for: .birthMoment)

    init(showThemes: (() -> Void)? = nil) {
        showThemesAction = showThemes
    }

    var body: some View {
        HomeScreenScaffold {
            HomeHeader(
                greeting: localized("life_stage.birthMoment.title"),
                userInitial: userInitial,
                showsProfileButton: !isSettingsPresented,
                openSettings: {
                    isPlaybackContinuationToastPresented = false
                    isSettingsPresented = true
                }
            ) {
                EmptyView()
            }
        } content: {
            BirthMomentHero(theme: detailTheme)

            VStack(alignment: .leading, spacing: AYASpacing.md) {
                SectionHeader("birth_moment.meditations.title")

                VStack(spacing: AYASpacing.md) {
                    ForEach(BirthMomentMeditationProvider.practices) { practice in
                        BirthMomentMeditationRow(
                            practice: practice,
                            metadataState: metadataStates[practice.id] ?? .loading,
                            playbackViewModel: playbackViewModel(for: practice.meditation),
                            action: { startMeditation(practice.meditation) }
                        )
                    }
                }
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
        .task {
            await loadMeditationMetadata()
        }
    }

    private func showThemes() {
        isSettingsPresented = false
        stopPlaybackSession()
        if let showThemesAction { showThemesAction() } else { dismiss() }
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

    @MainActor
    private func loadMeditationMetadata() async {
        let practicesToLoad = BirthMomentMeditationProvider.practices.filter {
            metadataStates[$0.id] == nil
        }
        guard !practicesToLoad.isEmpty else { return }

        for practice in practicesToLoad {
            metadataStates[practice.id] = .loading
        }

        await withTaskGroup(
            of: (String, Result<RemoteMeditationMetadata, Error>).self
        ) { group in
            for practice in practicesToLoad {
                group.addTask {
                    guard let source = practice.meditation.remoteAudioSource else {
                        return (practice.id, .failure(URLError(.badURL)))
                    }
                    do {
                        let metadata = try await RemoteMeditationContentLoader.loadMetadata(
                            source: source
                        )
                        return (practice.id, .success(metadata))
                    } catch {
                        return (practice.id, .failure(error))
                    }
                }
            }

            for await (practiceID, result) in group {
                guard !Task.isCancelled else { return }
                switch result {
                case let .success(metadata):
                    metadataStates[practiceID] = .loaded(metadata)
                case .failure:
                    metadataStates[practiceID] = .failed
                }
            }
        }
    }

    private func localized(_ key: String) -> String {
        selectedLanguage.localizedString(forKey: key)
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

private struct BirthMomentHero: View {
    let theme: LifeStageDetailTheme

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.md) {
            HesiaBadge("birth_moment.hero.badge", prominence: .themed(theme.badgeSurface))

            HeroInsight(
                title: localized("birth_moment.home.title"),
                message: localized("birth_moment.home.description"),
                isHeader: true
            )
        }
        .lifeStageHeroSurface(theme: theme)
    }

    private func localized(_ key: String) -> String {
        (AppLanguage(rawValue: languageCode) ?? .system).localizedString(forKey: key)
    }
}

struct BirthMomentPractice: Identifiable {
    let id: String
    let categoryLocalizationKey: String
    let meditation: DailyMeditation
}

enum BirthMomentMeditationProvider {
    static let practices: [BirthMomentPractice] = [
        practice(
            id: "flower_breath",
            categoryKey: "birth_moment.category.breath",
            durationMinutes: 5
        ),
        practice(
            id: "arrow_breath",
            categoryKey: "birth_moment.category.release",
            durationMinutes: 6
        ),
        practice(
            id: "zipper_breath",
            categoryKey: "birth_moment.category.safety",
            durationMinutes: 3
        ),
        practice(
            id: "curtain_breath",
            categoryKey: "birth_moment.category.calm",
            durationMinutes: 5
        )
    ]

    static let practiceIDs = practices.map(\.id)
    static let meditations = practices.map(\.meditation)

    private static func practice(
        id: String,
        categoryKey: String,
        durationMinutes: Int
    ) -> BirthMomentPractice {
        BirthMomentPractice(
            id: id,
            categoryLocalizationKey: categoryKey,
            meditation: DailyMeditation(
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
        )
    }
}

private struct BirthMomentMeditationRow: View {
    let practice: BirthMomentPractice
    let metadataState: DailyMeditationMetadataState
    let playbackViewModel: MeditationPlayerViewModel?
    let action: () -> Void

    var body: some View {
        // Same reason as DailyMeditationCard: the indicator only tracks
        // loading → playing if the view model is actually observed.
        if let playbackViewModel {
            ObservedBirthMomentMeditationRow(
                practice: practice,
                metadataState: metadataState,
                viewModel: playbackViewModel,
                action: action
            )
        } else {
            BirthMomentMeditationRowContent(
                practice: practice,
                metadataState: metadataState,
                playbackState: .idle,
                action: action
            )
        }
    }
}

private struct ObservedBirthMomentMeditationRow: View {
    let practice: BirthMomentPractice
    let metadataState: DailyMeditationMetadataState
    @ObservedObject var viewModel: MeditationPlayerViewModel
    let action: () -> Void

    var body: some View {
        BirthMomentMeditationRowContent(
            practice: practice,
            metadataState: metadataState,
            playbackState: playbackState,
            action: action
        )
    }

    private var playbackState: DailyMeditationPlaybackState {
        if viewModel.isLoadingAudio { return .loading }
        return viewModel.isPlaying ? .playing : .idle
    }
}

private struct BirthMomentMeditationRowContent: View {
    let practice: BirthMomentPractice
    let metadataState: DailyMeditationMetadataState
    let playbackState: DailyMeditationPlaybackState
    let action: () -> Void

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var meditation: DailyMeditation { practice.meditation }

    var body: some View {
        Button(action: action) {
            responsiveLayout {
                VStack(alignment: .leading, spacing: AYASpacing.xs) {
                    Text(LocalizedStringKey(practice.categoryLocalizationKey))
                        .ayaTypography(.homeBadge)
                        .foregroundStyle(AYAColors.emphasis)

                    Text(verbatim: titleText)
                        .ayaTypography(.homeMeditationTitle)
                        .foregroundStyle(AYAColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(verbatim: descriptionText)
                        .ayaTypography(.homeMeditationDescription)
                        .foregroundStyle(AYAColors.textSecondary)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: AYASpacing.xs) {
                        HesiaIcon.clock.view(size: HesiaIconSize.sm)
                        Text(verbatim: durationText)
                    }
                    .ayaTypography(.homeMetadata)
                    .foregroundStyle(AYAColors.textTertiary)
                    .padding(.top, AYASpacing.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                playbackIndicator
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
        .buttonStyle(HesiaCardButtonStyle())
        .ayaElevation(.card)
        .accessibilityIdentifier("birth_moment.meditation.\(meditation.id)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("meditation.start")
    }

    private func responsiveLayout<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AYASpacing.md, content: content)
            } else {
                HStack(alignment: .center, spacing: AYASpacing.md, content: content)
            }
        }
    }

    /// Decorative — the whole row is the button.
    private var playbackIndicator: some View {
        Group {
            switch playbackState {
            case .loading:
                ProgressView()
                    .tint(AYAColors.onAccent)
            case .playing:
                PlaybackWaveformIndicator(isPlaying: true)
            case .idle:
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AYAColors.onAccent)
            }
        }
        .frame(width: 44, height: 44)
        .background(AYAColors.emphasis, in: Circle())
        .accessibilityHidden(true)
    }

    private var durationText: String {
        String(
            format: selectedLanguage.localizedString(forKey: "meditation.duration.minutes"),
            locale: selectedLanguage.locale,
            remoteMetadata?.durationMinutes ?? meditation.durationMinutes
        )
    }

    private var accessibilityLabel: String {
        [
            selectedLanguage.localizedString(forKey: practice.categoryLocalizationKey),
            titleText,
            accessibilityDurationText
        ].joined(separator: ", ")
    }

    private var accessibilityDurationText: String {
        String(
            format: selectedLanguage.localizedString(
                forKey: "meditation.duration.minutes_accessibility"
            ),
            locale: selectedLanguage.locale,
            remoteMetadata?.durationMinutes ?? meditation.durationMinutes
        )
    }

    private var remoteMetadata: RemoteMeditationMetadata? {
        guard case let .loaded(metadata) = metadataState else { return nil }
        return metadata
    }

    private var titleText: String {
        remoteMetadata?.localizedTitle(for: selectedLanguage)
            ?? selectedLanguage.localizedString(forKey: meditation.titleLocalizationKey)
    }

    private var descriptionText: String {
        remoteMetadata?.localizedDescription(for: selectedLanguage)
            ?? selectedLanguage.localizedString(forKey: meditation.descriptionLocalizationKey)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage.resolved(from: languageCode)
    }
}

#Preview("Birth Moment — Türkçe") {
    NavigationStack {
        BirthMomentHomeView()
            .environment(\.locale, Locale(identifier: "tr"))
    }
}

#Preview("Birth Moment — Small English") {
    NavigationStack {
        BirthMomentHomeView()
            .environment(\.locale, Locale(identifier: "en"))
    }
    .frame(width: 320)
}
