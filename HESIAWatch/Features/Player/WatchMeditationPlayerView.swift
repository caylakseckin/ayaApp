import SwiftUI

struct WatchMeditationPlayerView: View {
    @StateObject private var viewModel: WatchMeditationPlayerViewModel
    @ObservedObject private var sessionReceiver = WatchSessionReceiver.shared
    private let startsPlaying: Bool
    @Environment(\.scenePhase) private var scenePhase

    init(session: WatchMeditationSession, startsPlaying: Bool = true) {
        self.startsPlaying = startsPlaying
        _viewModel = StateObject(
            wrappedValue: WatchMeditationPlayerViewModel(
                session: session,
                isPlaying: false
            )
        )
    }

    var body: some View {
        VStack(spacing: 4) {
            playerHeader

            ZStack {
                Circle()
                    .stroke(HESIAWatchColors.controlSurface, lineWidth: 6)

                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        HESIAWatchColors.softPink,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Button(action: viewModel.togglePlayback) {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(HESIAWatchColors.emphasis)
                        } else {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 25, weight: .semibold))
                        }
                    }
                    .foregroundStyle(HESIAWatchColors.emphasis)
                    .frame(width: 58, height: 58)
                    .background(HESIAWatchColors.cardSurface, in: Circle())
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                .accessibilityLabel(viewModel.isPlaying ? "watch.player.pause" : "watch.player.play")
            }
            .frame(width: 78, height: 78)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("watch.player.progress")
            .accessibilityValue(progressAccessibilityValue)

            Text("\(formatted(viewModel.currentTime)) / \(formatted(viewModel.duration))")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(HESIAWatchColors.onCanvasSecondary)
                .accessibilityHidden(true)

            if viewModel.isPhoneUnavailable {
                Text("watch.player.unavailable")
                    .font(.caption2)
                    .foregroundStyle(HESIAWatchColors.onCanvasSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            } else {
                HStack {
                    skipButton(seconds: -15, symbol: "gobackward.15", label: "watch.player.back15")
                    Spacer(minLength: 24)
                    skipButton(seconds: 15, symbol: "goforward.15", label: "watch.player.forward15")
                }
                .padding(.horizontal, 19)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .containerBackground(HESIAWatchColors.canvas, for: .navigation)
        .onAppear {
            if startsPlaying {
                if let state = sessionReceiver.playbackState, state.isPlaying {
                    viewModel.applyRemotePlaybackState(state)
                } else {
                    viewModel.prepareAndPlay()
                }
            }
        }
        .onChange(of: sessionReceiver.playbackState) { _, state in
            guard let state else { return }
            viewModel.applyRemotePlaybackState(state)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, viewModel.isPlaying {
                viewModel.start()
            }
        }
        .onDisappear(perform: viewModel.stopObserving)
    }

    private var playerHeader: some View {
        Text(verbatim: viewModel.session.title)
            .font(HESIAWatchTypography.playerTitle)
            .foregroundStyle(HESIAWatchColors.onCanvas)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity)
            .padding(.top, 30)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private func skipButton(seconds: TimeInterval, symbol: String, label: LocalizedStringKey) -> some View {
        Button {
            viewModel.skip(by: seconds)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 36, height: 36)
                .background(HESIAWatchColors.controlSurface, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(HESIAWatchColors.onCanvas)
        .accessibilityLabel(label)
    }

    private func formatted(_ time: TimeInterval) -> String {
        let value = max(0, Int(time.rounded(.down)))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    private var progressAccessibilityValue: String {
        String(
            format: HESIAWatchConfiguration.localizedString(forKey: "watch.player.progress.value"),
            locale: HESIAWatchConfiguration.locale,
            formatted(viewModel.currentTime),
            formatted(viewModel.duration)
        )
    }
}

struct WatchMeditationPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WatchMeditationPlayerView(session: WatchMockData.pregnancyPractice)
        }
        .environment(\.locale, HESIAWatchConfiguration.locale)
        .previewDisplayName("Player")
    }
}
