import SwiftUI

enum MeditationPlayerPresentation {
    case standard
    case tutorialPreview
}

@MainActor
final class MeditationPlaybackSession {
    let meditation: DailyMeditation
    let viewModel: MeditationPlayerViewModel

    init(meditation: DailyMeditation, language: AppLanguage) {
        self.meditation = meditation
        viewModel = MeditationPlayerViewModel(
            meditation: meditation,
            language: language,
            autoPlay: true
        )
    }
}

struct PlaybackWaveformIndicator: View {
    let isPlaying: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let restingHeights: [CGFloat] = [9, 13, 10]
    private let amplitudes: [CGFloat] = [1.5, 2, 1.5]
    private let phaseOffsets: [Double] = [0, 1.8, 3.6]

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: !isPlaying || reduceMotion
            )
        ) { context in
            HStack(spacing: 3) {
                ForEach(restingHeights.indices, id: \.self) { index in
                    Capsule()
                        .fill(AYAColors.onAccent)
                        .frame(width: 2, height: barHeight(at: index, date: context.date))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func barHeight(at index: Int, date: Date) -> CGFloat {
        guard isPlaying, !reduceMotion else { return restingHeights[index] }

        let phase = date.timeIntervalSinceReferenceDate * 1.25 + phaseOffsets[index]
        return restingHeights[index] + CGFloat(sin(phase)) * amplitudes[index]
    }
}

struct MeditationPlaybackContinuationToastModifier: ViewModifier {
    @Binding var isPresented: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    HStack(spacing: AYASpacing.md) {
                        PlaybackWaveformIndicator(isPlaying: true)
                            .frame(width: 36, height: 36)
                            .background(AYAColors.emphasis, in: Circle())

                        VStack(alignment: .leading, spacing: AYASpacing.xxs) {
                            Text("meditation.player.continues.title")
                                .ayaTypography(.homeCTA)
                                .foregroundStyle(AYAColors.textPrimary)

                            Text("meditation.player.continues.message")
                                .ayaTypography(.homeSupporting)
                                .foregroundStyle(AYAColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, AYASpacing.lg)
                    .padding(.vertical, AYASpacing.md)
                    .background(
                        AYAColors.surfaceElevated,
                        in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                            .stroke(AYAColors.border, lineWidth: 1)
                    }
                    .ayaElevation(.raised)
                    .padding(.horizontal, AYASpacing.xl)
                    .padding(.bottom, AYASpacing.lg)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .bottom).combined(with: .opacity)
                    )
                    .accessibilityElement(children: .combine)
                    .allowsHitTesting(false)
                }
            }
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.22),
                value: isPresented
            )
            .task(id: isPresented) {
                guard isPresented else { return }
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                guard !Task.isCancelled else { return }
                isPresented = false
            }
    }
}

extension View {
    func meditationPlaybackContinuationToast(isPresented: Binding<Bool>) -> some View {
        modifier(MeditationPlaybackContinuationToastModifier(isPresented: isPresented))
    }
}

struct MeditationPlayerView: View {
    let meditation: DailyMeditation
    let presentation: MeditationPlayerPresentation
    private let stopsPlaybackOnDismiss: Bool

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @StateObject private var viewModel: MeditationPlayerViewModel
    @State private var isScrollAtTop = true
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        meditation: DailyMeditation,
        autoPlay: Bool = false,
        presentation: MeditationPlayerPresentation = .standard,
        playbackViewModel: MeditationPlayerViewModel? = nil,
        stopsPlaybackOnDismiss: Bool = true
    ) {
        self.meditation = meditation
        self.presentation = presentation
        self.stopsPlaybackOnDismiss = stopsPlaybackOnDismiss
        let storedLanguageCode = UserDefaults.standard.string(forKey: "app.language")
        let language = AppLanguage(rawValue: storedLanguageCode ?? "")
            ?? AppLanguage.defaultExplicitLanguage
        _viewModel = StateObject(
            wrappedValue: playbackViewModel ?? MeditationPlayerViewModel(
                meditation: meditation,
                language: language,
                autoPlay: autoPlay
            )
        )
    }

    var body: some View {
        BiometricProtectedContent {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        scrollPositionReader

                        if presentation == .standard {
                            topControls
                        }

                        meditationHeader
                            .padding(.top, presentation == .standard ? AYASpacing.xxl : AYASpacing.lg)

                        Spacer(minLength: presentation == .standard ? AYASpacing.xxl : AYASpacing.sm)

                        if viewModel.isAudioUnavailable {
                            audioUnavailableState
                        } else {
                            focalPlaybackControl

                            if presentation == .standard {
                                Spacer(minLength: AYASpacing.lg)

                                transportControls
                                    .padding(.top, AYASpacing.sm)

                                Spacer(minLength: AYASpacing.xl)

                                progressControls
                            }
                        }

                        Spacer(minLength: presentation == .standard ? AYASpacing.xl : AYASpacing.sm)
                    }
                    .padding(.horizontal, presentation == .standard ? AYASpacing.xl : AYASpacing.lg)
                    .padding(.top, presentation == .standard ? AYASpacing.sm : 0)
                    .padding(.bottom, presentation == .standard ? AYASpacing.xl : AYASpacing.sm)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always)
                .coordinateSpace(name: MeditationPlayerScrollCoordinateSpace.name)
                .onPreferenceChange(MeditationPlayerScrollTopPreferenceKey.self) { minY in
                    isScrollAtTop = minY >= -1
                }
                .simultaneousGesture(dismissGesture(viewportHeight: geometry.size.height))
            }
        }
        .background(playerBackground)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.selection, trigger: viewModel.isPlaying)
        .sensoryFeedback(.success, trigger: viewModel.playbackEnded)
        .onAppear {
            if presentation == .standard {
                configureNowPlayingMetadata()
                viewModel.autoPlayIfReady()
            }
        }
        .onChange(of: languageCode) {
            if presentation == .standard {
                configureNowPlayingMetadata()
            }
        }
        .onDisappear {
            if presentation == .standard, stopsPlaybackOnDismiss {
                viewModel.stop()
            }
        }
    }

    private var scrollPositionReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: MeditationPlayerScrollTopPreferenceKey.self,
                value: proxy.frame(in: .named(MeditationPlayerScrollCoordinateSpace.name)).minY
            )
        }
        .frame(height: 0)
        .accessibilityHidden(true)
    }

    private func dismissGesture(viewportHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onEnded { value in
                guard
                    presentation == .standard,
                    isScrollAtTop,
                    MeditationPlayerDismissalPolicy.shouldDismiss(
                        translationWidth: value.translation.width,
                        translationHeight: value.translation.height,
                        predictedTranslationHeight: value.predictedEndTranslation.height,
                        viewportHeight: viewportHeight
                    )
                else { return }

                dismissPlayer()
            }
    }

    private var playerBackground: some View {
        ZStack {
            AYAColors.backgroundPrimary
            // Whisper-soft warmth centered behind the orb — immersive, not a glow.
            RadialGradient(
                colors: [AYAColors.accent.opacity(0.06), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 320
            )
            .offset(y: -20)
            .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }

    private var topControls: some View {
        HStack {
            Button {
                dismissPlayer()
            } label: {
                HesiaIcon.caretDown.view(size: 19)
                    .foregroundStyle(AYAColors.textPrimary)
                    .frame(width: 46, height: 46)
                    .background(AYAColors.surface, in: Circle())
                    .ayaElevation(.card)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("meditation.player.close")
            .accessibilityIdentifier("meditation.player.close")

            Spacer()
        }
    }

    private func dismissPlayer() {
        if stopsPlaybackOnDismiss {
            viewModel.stop()
        }
        dismiss()
    }

    private var meditationHeader: some View {
        VStack(spacing: 0) {
            Text(verbatim: phaseBadgeText)
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.emphasis)
                .padding(.horizontal, AYASpacing.lg)
                .frame(minHeight: 38)
                .background(AYAColors.accentSoft, in: Capsule())

            Text(verbatim: meditationTitle)
                .ayaTypography(.playerTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, AYASpacing.xl)

            if presentation == .standard {
                Text(verbatim: meditationDescription)
                    .ayaTypography(.body)
                    .foregroundStyle(AYAColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AYASpacing.lg)

                metadata
                    .padding(.top, AYASpacing.xl)
            }
        }
        .frame(maxWidth: 520)
    }

    private var metadata: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AYASpacing.lg) {
                metadataItem(icon: .clock) {
                    Text(verbatim: durationText)
                }

                Rectangle()
                    .fill(AYAColors.separator)
                    .frame(width: 1, height: 28)
                    .accessibilityHidden(true)

                metadataItem(icon: .headphones) {
                    Text(verbatim: voiceText)
                        .foregroundStyle(AYAColors.textPrimary)
                }
            }

            VStack(spacing: AYASpacing.md) {
                metadataItem(icon: .clock) {
                    Text(verbatim: durationText)
                }
                metadataItem(icon: .headphones) {
                    Text(verbatim: voiceText)
                        .foregroundStyle(AYAColors.textPrimary)
                }
            }
        }
        .ayaTypography(.metadata)
        .foregroundStyle(AYAColors.textSecondary)
    }

    private func metadataItem<Content: View>(
        icon: HesiaIcon,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Label {
            content()
        } icon: {
            icon.view(size: 18)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var focalPlaybackControl: some View {
        ZStack {
            MeditationAmbientRings(
                isAnimating: viewModel.isPlaying,
                reduceMotion: reduceMotion
            )

            Circle()
                .fill(AYAColors.accent.opacity(0.035))
                .frame(width: 184, height: 184)
                .accessibilityHidden(true)

            Circle()
                .fill(AYAColors.accentSoft)
                .frame(width: 144, height: 144)
                .accessibilityHidden(true)

            playbackButton(size: 108, iconSize: 30, identifier: "meditation.player.focal")
        }
        .frame(width: 296, height: 296)
    }

    private var transportControls: some View {
        HStack {
            skipButton(
                direction: .backward,
                label: "meditation.player.skip_back",
                identifier: "meditation.player.skip_back"
            ) {
                viewModel.skipBackward(seconds: 15)
            }

            Spacer(minLength: AYASpacing.xxl)

            skipButton(
                direction: .forward,
                label: "meditation.player.skip_forward",
                identifier: "meditation.player.skip_forward"
            ) {
                viewModel.skipForward(seconds: 15)
            }
        }
        .frame(maxWidth: 260)
    }

    private func skipButton(
        direction: HesiaSeekIcon.Direction,
        label: LocalizedStringKey,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HesiaSeekIcon(direction: direction, seconds: 15)
                .foregroundStyle(AYAColors.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoadingAudio)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var progressControls: some View {
        HStack(spacing: AYASpacing.md) {
            Text(verbatim: MeditationTimeFormatter.clock(viewModel.currentTime))
                .foregroundStyle(AYAColors.textSecondary)
                .frame(minWidth: 43, alignment: .leading)

            Slider(
                value: Binding(
                    get: { viewModel.progress },
                    set: { viewModel.seek(toProgress: $0) }
                ),
                in: 0...1
            )
            .tint(AYAColors.emphasis)
            .accessibilityLabel("meditation.player.progress")
            .accessibilityValue(progressAccessibilityValue)
            .accessibilityIdentifier("meditation.player.progress")

            Text(verbatim: MeditationTimeFormatter.clock(viewModel.duration))
                .foregroundStyle(AYAColors.textTertiary)
                .frame(minWidth: 43, alignment: .trailing)
        }
        .ayaTypography(.metadata)
        .frame(maxWidth: 620)
    }

    private func playbackButton(size: CGFloat, iconSize: CGFloat, identifier: String) -> some View {
        Button(action: viewModel.togglePlayback) {
            Group {
                if viewModel.isLoadingAudio {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AYAColors.onAccent)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(AYAColors.onAccent)
                }
            }
            .frame(width: size, height: size)
            .background(AYAColors.emphasis, in: Circle())
            .ayaElevation(.raised)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoadingAudio)
        .accessibilityLabel(playbackAccessibilityLabel)
        .accessibilityIdentifier(identifier)
    }

    private var audioUnavailableState: some View {
        VStack(spacing: AYASpacing.lg) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(AYAColors.textTertiary)
                .accessibilityHidden(true)

            Text("meditation.player.error.title")
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .multilineTextAlignment(.center)

            Text("meditation.player.error.message")
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("meditation.player.retry") {
                viewModel.retry()
            }
            .buttonStyle(.appPrimary)
            .frame(maxWidth: 280)
            .padding(.top, AYASpacing.sm)
            .accessibilityIdentifier("meditation.player.retry")
        }
        .frame(maxWidth: 360)
        .padding(.vertical, AYASpacing.xxl)
    }

    private var phaseBadgeText: String {
        meditation.localizedContext(language: selectedLanguage, locale: locale)
    }

    private var durationText: String {
        let format = selectedLanguage.localizedString(forKey: "meditation.player.duration_minutes")
        return String(format: format, locale: locale, viewModel.displayDurationMinutes)
    }

    private var meditationTitle: String {
        viewModel.remoteTitle
            ?? selectedLanguage.localizedString(forKey: meditation.titleLocalizationKey)
    }

    private var meditationDescription: String {
        viewModel.remoteDescription
            ?? selectedLanguage.localizedString(forKey: meditation.descriptionLocalizationKey)
    }

    private var voiceText: String {
        guard let narrator = viewModel.remoteNarrator else {
            return selectedLanguage.localizedString(forKey: meditation.voiceLocalizationKey)
        }
        let format = selectedLanguage.localizedString(forKey: "meditation.player.voice_format")
        return String(format: format, locale: locale, narrator)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }

    private func configureNowPlayingMetadata() {
        viewModel.configureNowPlaying(
            title: selectedLanguage.localizedString(forKey: meditation.titleLocalizationKey),
            artist: selectedLanguage.localizedString(forKey: meditation.voiceLocalizationKey),
            phase: phaseBadgeText
        )
    }

    private var playbackAccessibilityLabel: LocalizedStringKey {
        if viewModel.isLoadingAudio {
            return "meditation.player.loading"
        }
        if viewModel.isAudioUnavailable {
            return "meditation.player.audio_unavailable"
        }
        return viewModel.isPlaying ? "meditation.player.pause" : "meditation.player.play"
    }

    private var progressAccessibilityValue: String {
        let format = String(localized: "meditation.player.progress.value", locale: locale)
        let current = timeComponents(viewModel.currentTime)
        let total = timeComponents(viewModel.duration)
        return String(
            format: format,
            locale: locale,
            current.minutes,
            current.seconds,
            total.minutes,
            total.seconds
        )
    }

    private func timeComponents(_ time: TimeInterval) -> (minutes: Int, seconds: Int) {
        let totalSeconds = max(Int(time.rounded(.down)), 0)
        return (totalSeconds / 60, totalSeconds % 60)
    }

}

enum MeditationPlayerDismissalPolicy {
    static func shouldDismiss(
        translationWidth: CGFloat,
        translationHeight: CGFloat,
        predictedTranslationHeight: CGFloat,
        viewportHeight: CGFloat
    ) -> Bool {
        guard translationHeight > 0, translationHeight > abs(translationWidth) else {
            return false
        }

        let deliberateDistance = max(170, min(viewportHeight * 0.24, 220))
        let fastFlickMinimumDistance: CGFloat = 110
        let fastFlickPrediction = deliberateDistance * 1.50

        return translationHeight >= deliberateDistance
            || (translationHeight >= fastFlickMinimumDistance
                && predictedTranslationHeight >= fastFlickPrediction)
    }
}

private enum MeditationPlayerScrollCoordinateSpace {
    static let name = "meditation.player.scroll"
}

private struct MeditationPlayerScrollTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct MeditationAmbientRings: View {
    let isAnimating: Bool
    let reduceMotion: Bool

    var body: some View {
        Group {
            if isAnimating && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    animatedRings(at: context.date)
                }
            } else {
                staticRings
            }
        }
        .frame(width: 296, height: 296)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func animatedRings(at date: Date) -> some View {
        let elapsed = date.timeIntervalSinceReferenceDate

        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                let phase = ringPhase(elapsed: elapsed, index: index)
                let fade = sin(.pi * phase)

                Circle()
                    .stroke(
                        ringColor(index).opacity(0.11 * fade),
                        lineWidth: 1.35
                    )
                    .frame(
                        width: 190 + (phase * 102),
                        height: 190 + (phase * 102)
                    )
                    .blur(radius: 0.6 + (phase * 1.5))
            }
        }
    }

    private var staticRings: some View {
        ZStack {
            Circle()
                .stroke(AYAColors.softPink.opacity(0.075), lineWidth: 1)
                .frame(width: 216, height: 216)

            Circle()
                .stroke(AYAColors.primary.opacity(0.05), lineWidth: 1)
                .frame(width: 252, height: 252)

            Circle()
                .stroke(AYAColors.softPink.opacity(0.035), lineWidth: 1)
                .frame(width: 288, height: 288)
        }
    }

    private func ringPhase(elapsed: TimeInterval, index: Int) -> Double {
        let duration = 6.0
        let stagger = Double(index) / 3.0
        return ((elapsed / duration) + stagger).truncatingRemainder(dividingBy: 1)
    }

    private func ringColor(_ index: Int) -> Color {
        index == 1 ? AYAColors.primary : AYAColors.softPink
    }
}

#Preview("Meditation Player — Türkçe") {
    MeditationPlayerView(
        meditation: DailyMeditationProvider().meditation(for: .luteal, phaseDay: 6)
    )
    .environment(\.locale, Locale(identifier: "tr"))
}

#Preview("Meditation Player — English") {
    MeditationPlayerView(
        meditation: DailyMeditationProvider().meditation(for: .luteal, phaseDay: 6)
    )
    .environment(\.locale, Locale(identifier: "en"))
}
