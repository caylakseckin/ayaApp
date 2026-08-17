import SwiftUI

struct TodayPracticeWatchView: View {
    let session: WatchMeditationSession

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 200 || proxy.size.height < 240

            ScrollView {
                practiceCard(compact: compact)
                    .frame(minHeight: compact ? 184 : max(proxy.size.height - 8, 184))
                    .padding(.horizontal, 5)
                    .padding(.top, compact ? -14 : -10)
                    .padding(.bottom, compact ? 0 : 4)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .containerBackground(HESIAWatchColors.surface, for: .navigation)
    }

    private func practiceCard(compact: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            decorativeMotif

            VStack(alignment: .leading, spacing: compact ? 5 : 7) {
                Text("HESIA")
                    .font(HESIAWatchTypography.brand)
                    .tracking(1.5)
                    .foregroundStyle(HESIAWatchColors.primary)

                Text("watch.today.eyebrow")
                    .font(HESIAWatchTypography.eyebrow)
                    .foregroundStyle(HESIAWatchColors.secondaryText)

                Text(verbatim: session.title)
                    .font(compact ? HESIAWatchTypography.compactTitle : HESIAWatchTypography.title)
                    .foregroundStyle(HESIAWatchColors.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(stageMetadata)
                    .font(HESIAWatchTypography.metadata)
                    .foregroundStyle(HESIAWatchColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)

                Spacer(minLength: compact ? 2 : 5)

                HStack(alignment: .center, spacing: 8) {
                    Label(durationText, systemImage: "clock")
                        .font(HESIAWatchTypography.metadata)
                        .foregroundStyle(HESIAWatchColors.primaryText)

                    Spacer(minLength: 4)

                    // Starting on the paired iPhone does not require the audio file
                    // to have finished copying to the Watch. Keep the primary action
                    // available immediately after a theme/practice change; the player
                    // falls back to Watch-local playback only when needed.
                    NavigationLink(value: session) {
                        Image(systemName: "play.fill")
                            .font(.system(size: compact ? 17 : 19, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: compact ? 46 : 50, height: compact ? 46 : 50)
                            .background(HESIAWatchColors.emphasis, in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("watch.today.start")
                    .accessibilityHint("watch.today.start.hint")
                }
            }
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 7 : 14)
        }
        .contentShape(Rectangle())
    }

    private var decorativeMotif: some View {
        ZStack {
            Circle()
                .fill(HESIAWatchColors.pregnancy.opacity(0.36))
                .frame(width: 112, height: 112)
                .offset(x: 26, y: 36)
            Circle()
                .fill(HESIAWatchColors.softPink.opacity(0.22))
                .frame(width: 82, height: 82)
                .offset(x: 46, y: 48)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var stageMetadata: String {
        if let detailText = session.detailText, !detailText.isEmpty {
            return detailText
        }
        return String(
            format: HESIAWatchConfiguration.localizedString(forKey: "watch.today.stage.week"),
            locale: HESIAWatchConfiguration.locale,
            HESIAWatchConfiguration.localizedString(forKey: session.stageKey),
            Int64(session.displayWeek)
        )
    }

    private var durationText: String {
        String(
            format: HESIAWatchConfiguration.localizedString(forKey: "watch.duration.minutes"),
            locale: HESIAWatchConfiguration.locale,
            Int64(session.durationMinutes)
        )
    }
}

struct TodayPracticeWatchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TodayPracticeWatchView(
                session: WatchMockData.pregnancyPractice
            )
        }
        .environment(\.locale, HESIAWatchConfiguration.locale)
        .previewDisplayName("Bugünün Pratiği")
    }
}
