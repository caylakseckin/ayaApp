import SwiftUI
import WidgetKit

struct HESIAWatchWidgetEntry: TimelineEntry {
    let date: Date
    let session: WatchMeditationSession?
}

struct HESIAWatchWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HESIAWatchWidgetEntry {
        entry
    }

    func getSnapshot(in context: Context, completion: @escaping (HESIAWatchWidgetEntry) -> Void) {
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HESIAWatchWidgetEntry>) -> Void) {
        completion(Timeline(entries: [entry], policy: .after(Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400))))
    }

    private var entry: HESIAWatchWidgetEntry {
        HESIAWatchWidgetEntry(
            date: Date(),
            session: WatchMeditationSharedStore.load()
        )
    }
}

struct HESIAWatchWidgetView: View {
    let entry: HESIAWatchWidgetEntry

    var body: some View {
        if let session = entry.session {
            practiceView(session: session)
        } else {
            syncView
        }
    }

    private func practiceView(session: WatchMeditationSession) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("watch.widget.title")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(HESIAWatchColors.primary)

                Text(verbatim: session.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HESIAWatchColors.primaryText)
                    .lineLimit(1)

                Text(widgetMetadata(for: session))
                    .font(.caption2)
                    .foregroundStyle(HESIAWatchColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            Image(systemName: "play.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(HESIAWatchColors.emphasis, in: Circle())
                .accessibilityHidden(true)
        }
        .widgetURL(URL(string: "hesia-watch://today-practice"))
        .containerBackground(HESIAWatchColors.background.gradient, for: .widget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("watch.widget.accessibility")
    }

    private var syncView: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone.and.arrow.forward")
                .foregroundStyle(HESIAWatchColors.primary)
            Text("watch.widget.sync")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HESIAWatchColors.primaryText)
                .lineLimit(2)
        }
        .containerBackground(HESIAWatchColors.background.gradient, for: .widget)
    }

    private func widgetMetadata(for session: WatchMeditationSession) -> String {
        if let detailText = session.detailText, !detailText.isEmpty {
            let duration = String(
                format: HESIAWatchConfiguration.localizedString(forKey: "watch.duration.minutes"),
                locale: HESIAWatchConfiguration.locale,
                Int64(session.durationMinutes)
            )
            return "\(duration) • \(detailText)"
        }
        return String(
            format: HESIAWatchConfiguration.localizedString(forKey: "watch.widget.metadata"),
            locale: HESIAWatchConfiguration.locale,
            Int64(session.durationMinutes),
            Int64(session.displayWeek)
        )
    }
}

@main
struct HESIAWatchWidget: Widget {
    let kind = "HESIAWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HESIAWatchWidgetProvider()) { entry in
            HESIAWatchWidgetView(entry: entry)
                .environment(\.locale, HESIAWatchConfiguration.locale)
        }
        .configurationDisplayName("watch.widget.display.name")
        .description("watch.widget.description")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct HESIAWatchWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        HESIAWatchWidgetView(
            entry: HESIAWatchWidgetEntry(
                date: .now,
                session: WatchMockData.pregnancyPractice
            )
        )
        .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
