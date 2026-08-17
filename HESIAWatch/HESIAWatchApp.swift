import SwiftUI

@main
struct HESIAWatchApp: App {
    @State private var navigationPath: [WatchMeditationSession] = []
    @StateObject private var sessionReceiver = WatchSessionReceiver.shared

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                Group {
                    if let session = sessionReceiver.todaySession {
                        TodayPracticeWatchView(
                            session: session
                        )
                    } else {
                        WatchPhoneSyncView(
                            isRequesting: sessionReceiver.isRequestingLatestPractice,
                            retry: {
                                sessionReceiver.requestLatestPractice(force: true)
                            }
                        )
                    }
                }
                .navigationDestination(for: WatchMeditationSession.self) { session in
                    WatchMeditationPlayerView(session: session)
                }
            }
            .tint(HESIAWatchColors.primary)
            .environment(\.locale, HESIAWatchConfiguration.locale)
            .onOpenURL { url in
                guard url.scheme == "hesia-watch", url.host == "today-practice" else { return }
                guard let session = sessionReceiver.todaySession else { return }
                navigationPath = [session]
            }
            .onAppear(perform: sessionReceiver.activate)
        }
    }
}

private struct WatchPhoneSyncView: View {
    let isRequesting: Bool
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(HESIAWatchColors.softPink)

            Text("watch.sync.title")
                .font(HESIAWatchTypography.playerTitle)
                .foregroundStyle(HESIAWatchColors.onCanvas)
                .multilineTextAlignment(.center)

            Text("watch.sync.message")
                .font(.caption)
                .foregroundStyle(HESIAWatchColors.onCanvasSecondary)
                .multilineTextAlignment(.center)

            Button(action: retry) {
                HStack(spacing: 6) {
                    if isRequesting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(HESIAWatchColors.onCanvas)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }

                    Text(isRequesting ? "watch.sync.retrying" : "watch.sync.retry")
                        .font(HESIAWatchTypography.control)
                }
                .foregroundStyle(HESIAWatchColors.onCanvas)
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .background(HESIAWatchColors.controlSurface, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)
            .accessibilityIdentifier("watch.sync.retry")
        }
        .padding(.horizontal, 12)
        .containerBackground(HESIAWatchColors.canvas, for: .navigation)
    }
}
