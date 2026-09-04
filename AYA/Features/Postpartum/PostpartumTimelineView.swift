import SwiftUI

struct PostpartumTimelineView: View {
    let profile: PostpartumProfile

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let tracker = PostpartumTracker()

    var body: some View {
        ScrollView {
            VStack(spacing: AYASpacing.xl) {
                header
                summaryCard

                VStack(spacing: AYASpacing.md) {
                    ForEach(PostpartumJourneyPhase.allCases, id: \.self) { phase in
                        phaseCard(for: phase)
                    }
                }

                Text("postpartum.timeline.note")
                    .ayaTypography(.metadata)
                    .foregroundStyle(AYAColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AYASpacing.lg)
            }
            .hesiaScreenPadding()
            .padding(.top, AYASpacing.md)
            .padding(.bottom, AYASpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .hesiaInteractivePopGesture()
    }

    private var calculation: PostpartumCalculation {
        tracker.calculate(profile: profile)
    }

    private var currentJourneyPhase: PostpartumJourneyPhase {
        .phase(containing: calculation.currentDay)
    }

    private var displayedJourneyDay: Int {
        min(calculation.currentDay, PostpartumJourney.totalDays)
    }

    private var header: some View {
        ScreenHeader(
            "postpartum.timeline.title",
            backAccessibilityKey: "postpartum.timeline.back"
        ) {
            dismiss()
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: AYASpacing.lg) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AYASpacing.lg) {
                    currentDaySummary
                    Spacer(minLength: AYASpacing.sm)
                    currentPhaseBadge
                }

                VStack(alignment: .leading, spacing: AYASpacing.md) {
                    currentDaySummary
                    currentPhaseBadge
                }
            }

            VStack(alignment: .leading, spacing: AYASpacing.sm) {
                Text(verbatim: progressText)
                    .ayaTypography(.metadata)
                    .foregroundStyle(AYAColors.textTertiary)

                ProgressView(value: calculation.progress)
                    .tint(AYAColors.accent)
                    .accessibilityLabel("postpartum.timeline.progress.accessibility")
                    .accessibilityValue(Text(verbatim: progressText))
            }
        }
        .padding(AYASpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AYAColors.surfaceElevated,
            in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(AYAColors.border, lineWidth: 1)
        }
        .ayaElevation(.card)
    }

    private var currentDaySummary: some View {
        VStack(alignment: .leading, spacing: AYASpacing.xs) {
            Text(verbatim: "\(calculation.currentDay)")
                .ayaTypography(.homeMetricValue)
                .foregroundStyle(AYAColors.textPrimary)

            Text("postpartum.timeline.current_day")
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentPhaseBadge: some View {
        Text(LocalizedStringKey(currentJourneyPhase.titleLocalizationKey))
            .ayaTypography(.metadata)
            .foregroundStyle(AYAColors.emphasis)
            .padding(.horizontal, AYASpacing.md)
            .frame(minHeight: 32)
            .background(AYAColors.postpartumSurface, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }

    private func phaseCard(for phase: PostpartumJourneyPhase) -> some View {
        let state = phase.state(on: calculation.currentDay)

        return HStack(alignment: .top, spacing: AYASpacing.md) {
            VStack(alignment: .leading, spacing: AYASpacing.sm) {
                Text(LocalizedStringKey(phase.rangeLocalizationKey))
                    .ayaTypography(.metadata)
                    .foregroundStyle(AYAColors.textTertiary)

                Text(LocalizedStringKey(phase.titleLocalizationKey))
                    .ayaTypography(.sectionTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(LocalizedStringKey(phase.descriptionLocalizationKey))
                    .ayaTypography(.body)
                    .foregroundStyle(AYAColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AYASpacing.sm)
            phaseStateIndicator(state)
        }
        .padding(AYASpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            phaseSurface(for: state),
            in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(phaseBorder(for: state), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: phaseAccessibilityLabel(phase, state: state)))
    }

    @ViewBuilder
    private func phaseStateIndicator(_ state: PostpartumJourneyPhaseState) -> some View {
        switch state {
        case .completed:
            HesiaIcon.check.view(size: 14)
                .foregroundStyle(AYAColors.textTertiary)
                .frame(width: 32, height: 32)
                .background(AYAColors.accentSoft, in: Circle())
                .accessibilityHidden(true)
        case .current:
            Text(LocalizedStringKey(state.localizationKey))
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.emphasis)
                .padding(.horizontal, AYASpacing.sm)
                .frame(minHeight: 28)
                .background(AYAColors.postpartumSurface, in: Capsule())
                .fixedSize()
                .accessibilityHidden(true)
        case .upcoming:
            Circle()
                .stroke(AYAColors.separator, lineWidth: 1)
                .frame(width: 16, height: 16)
                .padding(AYASpacing.sm)
                .accessibilityHidden(true)
        }
    }

    private func phaseSurface(for state: PostpartumJourneyPhaseState) -> Color {
        state == .current ? AYAColors.postpartumHeroSurface : AYAColors.surfaceElevated
    }

    private func phaseBorder(for state: PostpartumJourneyPhaseState) -> Color {
        state == .current ? AYAColors.accent : AYAColors.border
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }

    private var progressText: String {
        let format = selectedLanguage.localizedString(forKey: "postpartum.timeline.progress")
        return String(format: format, locale: locale, displayedJourneyDay)
    }

    private func phaseAccessibilityLabel(
        _ phase: PostpartumJourneyPhase,
        state: PostpartumJourneyPhaseState
    ) -> String {
        let format = selectedLanguage.localizedString(forKey: "postpartum.timeline.phase.accessibility")
        return String(
            format: format,
            locale: locale,
            selectedLanguage.localizedString(forKey: phase.titleLocalizationKey),
            selectedLanguage.localizedString(forKey: phase.rangeLocalizationKey),
            selectedLanguage.localizedString(forKey: state.localizationKey),
            selectedLanguage.localizedString(forKey: phase.descriptionLocalizationKey)
        )
    }
}

#Preview("Postpartum Timeline — Day 10") {
    NavigationStack {
        PostpartumTimelineView(
            profile: PostpartumProfile(
                birthDate: Calendar.current.date(byAdding: .day, value: -9, to: Date())!
            )!
        )
    }
}

#Preview("Postpartum Timeline — Large Type") {
    NavigationStack {
        PostpartumTimelineView(
            profile: PostpartumProfile(
                birthDate: Calendar.current.date(byAdding: .day, value: -29, to: Date())!
            )!
        )
        .environment(\.dynamicTypeSize, .accessibility3)
    }
}
