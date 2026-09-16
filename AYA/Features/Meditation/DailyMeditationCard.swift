import SwiftUI

/// Loading state of the remote metadata backing a daily meditation card.
enum DailyMeditationMetadataState: Equatable {
    case loading
    case loaded(RemoteMeditationMetadata?)
    case failed
}

/// The primary action on every Home screen: today's meditation.
///
/// This used to be a `VStack` with an `.onTapGesture` plus a `PreferenceKey`
/// that collected the frames of the inner play/info buttons so the tap handler
/// could exclude them. That meant no pressed state, no `.isButton` trait, and —
/// worst of all — VoiceOver users could not activate the card at all. It is a
/// real `Button` now; the play control is purely decorative because tapping
/// anywhere already starts playback, and the info action moved out to the
/// section header so nothing is nested inside the button.
struct DailyMeditationCard: View {
    enum ContextPlacement: Equatable {
        case belowTitle
        case eyebrow
    }

    let meditation: DailyMeditation
    let metadataState: DailyMeditationMetadataState
    let playbackViewModel: MeditationPlayerViewModel?
    let contextPlacement: ContextPlacement
    let start: () -> Void

    init(
        meditation: DailyMeditation,
        metadataState: DailyMeditationMetadataState = .loaded(nil),
        playbackViewModel: MeditationPlayerViewModel? = nil,
        contextPlacement: ContextPlacement = .belowTitle,
        start: @escaping () -> Void
    ) {
        self.meditation = meditation
        self.metadataState = metadataState
        self.playbackViewModel = playbackViewModel
        self.contextPlacement = contextPlacement
        self.start = start
    }

    var body: some View {
        // The playback view model has to be observed for the indicator to track
        // loading → playing → paused. Reading it from a plain `let` renders the
        // card once and freezes it — which left a stuck spinner on the card
        // after dismissing the player mid-playback.
        if let playbackViewModel {
            ObservedDailyMeditationCard(
                meditation: meditation,
                metadataState: metadataState,
                contextPlacement: contextPlacement,
                viewModel: playbackViewModel,
                start: start
            )
        } else {
            DailyMeditationCardContent(
                meditation: meditation,
                metadataState: metadataState,
                playbackState: .idle,
                contextPlacement: contextPlacement,
                start: start
            )
        }
    }
}

/// Playback state the card renders, resolved from an observed view model.
enum DailyMeditationPlaybackState {
    case idle
    case loading
    case playing
}

/// Observes the active playback session so the card's indicator stays live.
private struct ObservedDailyMeditationCard: View {
    let meditation: DailyMeditation
    let metadataState: DailyMeditationMetadataState
    let contextPlacement: DailyMeditationCard.ContextPlacement
    @ObservedObject var viewModel: MeditationPlayerViewModel
    let start: () -> Void

    var body: some View {
        DailyMeditationCardContent(
            meditation: meditation,
            metadataState: metadataState,
            playbackState: playbackState,
            contextPlacement: contextPlacement,
            start: start
        )
    }

    private var playbackState: DailyMeditationPlaybackState {
        if viewModel.isLoadingAudio { return .loading }
        return viewModel.isPlaying ? .playing : .idle
    }
}

private struct DailyMeditationCardContent: View {
    let meditation: DailyMeditation
    let metadataState: DailyMeditationMetadataState
    let playbackState: DailyMeditationPlaybackState
    let contextPlacement: DailyMeditationCard.ContextPlacement
    let start: () -> Void

    @Environment(\.locale) private var locale
    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue

    var body: some View {
        Button(action: start) {
            VStack(alignment: .leading, spacing: 0) {
                if contextPlacement == .eyebrow {
                    contextText
                }

                Text(verbatim: titleText)
                    .ayaTypography(.homeMeditationTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, contextPlacement == .eyebrow ? AYASpacing.sm : 0)

                if contextPlacement == .belowTitle {
                    contextText
                        .padding(.top, AYASpacing.sm)
                }

                Text(verbatim: descriptionText)
                    .ayaTypography(.homeMeditationDescription)
                    .foregroundStyle(AYAColors.textSecondary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AYASpacing.sm)

                if metadataState == .failed {
                    offlineNotice
                        .padding(.top, AYASpacing.md)
                }

                HStack(alignment: .center, spacing: AYASpacing.md) {
                    metadataRow
                    Spacer(minLength: AYASpacing.md)
                    playbackIndicator
                }
                .padding(.top, AYASpacing.lg)
            }
            .padding(AYASpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityIdentifier("cycle.home.meditation.start")
        .accessibilityLabel(Text(verbatim: titleText))
        .accessibilityHint(playbackAccessibilityHint)
    }

    // MARK: - Pieces

    private var contextText: some View {
        Text(verbatim: meditation.localizedContext(language: selectedLanguage, locale: locale))
            .ayaTypography(.homeMetadata)
            .foregroundStyle(contextPlacement == .eyebrow ? AYAColors.emphasis : AYAColors.textSecondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var metadataRow: some View {
        if metadataState == .loading {
            // Placeholder matching the eventual layout, so the card does not
            // reflow when the real duration and narrator arrive.
            HStack(spacing: AYASpacing.lg) {
                MetadataSkeleton(width: 54)
                MetadataSkeleton(width: 96)
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AYASpacing.lg) {
                    metadata(icon: .clock, text: durationText)
                    Rectangle()
                        .fill(AYAColors.separator)
                        .frame(width: 1, height: 18)
                        .accessibilityHidden(true)
                    metadata(icon: .headphones, text: voiceText)
                }

                VStack(alignment: .leading, spacing: AYASpacing.xs) {
                    metadata(icon: .clock, text: durationText)
                    metadata(icon: .headphones, text: voiceText)
                }
            }
        }
    }

    private var offlineNotice: some View {
        HStack(spacing: AYASpacing.sm) {
            Image(systemName: "wifi.slash")
                .font(.system(size: HesiaIconSize.sm))
                .accessibilityHidden(true)

            Text("meditation.card.offline_notice")
                .ayaTypography(.homeMetadata)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AYAColors.textSecondary)
        .padding(.horizontal, AYASpacing.md)
        .padding(.vertical, AYASpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AYAColors.backgroundSecondary,
            in: RoundedRectangle(cornerRadius: AYARadius.chip, style: .continuous)
        )
    }

    /// Mirrors the focal control on the player. Decorative: the whole card is
    /// the button, so this must not be interactive or it would nest one button
    /// inside another.
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
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AYAColors.onAccent)
            }
        }
        .frame(width: 54, height: 54)
        .background(AYAColors.emphasis, in: Circle())
        .accessibilityHidden(true)
    }

    private func metadata(icon: HesiaIcon, text: String) -> some View {
        HStack(spacing: AYASpacing.xs) {
            icon.view(size: HesiaIconSize.sm)
            Text(verbatim: text)
        }
        .ayaTypography(.homeMetadata)
        .foregroundStyle(AYAColors.textTertiary)
    }

    // MARK: - Content

    private var remoteMetadata: RemoteMeditationMetadata? {
        if case let .loaded(metadata) = metadataState { return metadata }
        return nil
    }

    private var titleText: String {
        remoteMetadata?.localizedTitle(for: selectedLanguage)
            ?? selectedLanguage.localizedString(forKey: meditation.titleLocalizationKey)
    }

    private var descriptionText: String {
        remoteMetadata?.localizedDescription(for: selectedLanguage)
            ?? selectedLanguage.localizedString(forKey: meditation.descriptionLocalizationKey)
    }

    private var durationText: String {
        String(
            format: selectedLanguage.localizedString(forKey: "meditation.duration.minutes"),
            locale: locale,
            remoteMetadata?.durationMinutes ?? meditation.durationMinutes
        )
    }

    private var voiceText: String {
        guard let narrator = remoteMetadata?.narrator else {
            return selectedLanguage.localizedString(forKey: meditation.voiceLocalizationKey)
        }
        return String(
            format: selectedLanguage.localizedString(forKey: "meditation.player.voice_format"),
            locale: locale,
            narrator
        )
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }

    private var playbackAccessibilityHint: LocalizedStringKey {
        switch playbackState {
        case .loading: "meditation.player.loading"
        case .playing: "meditation.player.open_playing"
        case .idle: "meditation.start"
        }
    }
}

/// Shimmer-free placeholder bar. A calm app does not need a shimmer; a settled
/// grey block that matches the final layout is enough to stop the content jump.
private struct MetadataSkeleton: View {
    let width: CGFloat

    var body: some View {
        Capsule()
            .fill(AYAColors.separator)
            .frame(width: width, height: 12)
            .accessibilityHidden(true)
    }
}

/// Press feedback for full-card buttons: a restrained scale and dim, skipped
/// entirely under Reduce Motion.
struct HesiaCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration)
    }

    private struct StyleBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.94 : 1)
                .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.99 : 1))
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.12),
                    value: configuration.isPressed
                )
        }
    }
}
