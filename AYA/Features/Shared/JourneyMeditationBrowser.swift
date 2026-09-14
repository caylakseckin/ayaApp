import SwiftUI

/// Browsing never writes to the tracked pregnancy week or birth date.
enum MeditationJourney {
    case pregnancy, postpartum

    var range: ClosedRange<Int> {
        switch self {
        case .pregnancy: RemoteMeditationAudioSource.supportedPregnancyWeeks
        case .postpartum: RemoteMeditationAudioSource.supportedPostpartumDays
        }
    }

    var selectionKey: String {
        self == .pregnancy ? "meditation.browse.week" : "meditation.browse.day"
    }

    var returnKey: LocalizedStringKey {
        self == .pregnancy ? "meditation.browse.return_week" : "meditation.browse.return_day"
    }

    func meditation(at value: Int) -> DailyMeditation {
        switch self {
        case .pregnancy: PregnancyContentProvider().meditation(forWeek: value)
        case .postpartum: PostpartumMeditationProvider().meditation(forDay: value)
        }
    }
}

struct JourneyMeditationBrowseLink: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AYASpacing.xs) {
                Text("meditation.browse.link")
                HesiaIcon.caretRight.view(size: HesiaIconSize.sm)
            }
            .ayaTypography(.homeLink)
            .foregroundStyle(AYAColors.emphasis)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("meditation.browse.open")
    }
}

struct JourneyMeditationBrowser: View {
    let journey: MeditationJourney
    @State private var selection: Int
    @State private var metadataState: DailyMeditationMetadataState = .loading
    @State private var isPlayerPresented = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue

    init(journey: MeditationJourney, currentValue: Int) {
        self.journey = journey
        _selection = State(initialValue: min(max(currentValue, journey.range.lowerBound), journey.range.upperBound))
    }

    private var meditation: DailyMeditation { journey.meditation(at: selection) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AYASpacing.xl) {
                    Text("meditation.browse.explanation")
                        .ayaTypography(.body)
                        .foregroundStyle(AYAColors.textSecondary)

                    Picker(LocalizedStringKey(journey.selectionKey), selection: $selection) {
                        ForEach(Array(journey.range), id: \.self) { value in
                            Text(verbatim: selectionLabel(value)).tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("meditation.browse.selection")

                    DailyMeditationCard(
                        meditation: meditation,
                        metadataState: metadataState,
                        contextPlacement: .eyebrow
                    ) {
                        isPlayerPresented = true
                    }
                }
                .padding(.vertical, AYASpacing.xl)
                .hesiaScreenPadding()
            }
            .background(AYAColors.backgroundPrimary)
            .navigationTitle("meditation.browse.title")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(journey.returnKey) { dismiss() }
                    .buttonStyle(.appPrimary)
                    .accessibilityIdentifier("meditation.browse.return")
                    .hesiaBottomBar()
            }
            .task(id: selection) { await loadMetadata() }
            .fullScreenCover(isPresented: $isPlayerPresented) {
                HESIAMeditationTransitionContainer {
                    // Temporary playback ends when leaving this player.
                    MeditationPlayerView(meditation: meditation, stopsPlaybackOnDismiss: true)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func selectionLabel(_ value: Int) -> String {
        let language = AppLanguage(rawValue: languageCode) ?? .system
        return String(format: language.localizedString(forKey: journey.selectionKey), locale: language.locale, value)
    }

    private func loadMetadata() async {
        metadataState = .loading
        guard let source = meditation.remoteAudioSource else {
            metadataState = .loaded(nil)
            return
        }
        do {
            let metadata = try await RemoteMeditationContentLoader.loadMetadata(source: source)
            guard !Task.isCancelled else { return }
            metadataState = .loaded(metadata)
        } catch {
            guard !Task.isCancelled else { return }
            metadataState = .failed
        }
    }
}
