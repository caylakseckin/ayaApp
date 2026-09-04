import SwiftUI

struct PregnancyCalendarView: View {
    let profile: PregnancyProfile

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let tracker = PregnancyTracker()

    var body: some View {
        ScrollView {
            VStack(spacing: AYASpacing.xl) {
                header
                currentWeekSummary

                VStack(spacing: AYASpacing.md) {
                    ForEach(PregnancyTrimester.allCases, id: \.rawValue) { trimester in
                        trimesterSection(trimester)
                    }
                }

                Text("pregnancy.calendar.note")
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

    private var calculation: PregnancyCalculation {
        tracker.calculate(profile: profile)
    }

    private var currentWeek: Int {
        calculation.currentWeek
    }

    private var totalSupportedWeeks: Int {
        PregnancyTracker.supportedWeekRange.upperBound
    }

    private var calendarProgress: Double {
        min(max(Double(currentWeek) / Double(totalSupportedWeeks), 0), 1)
    }

    private var header: some View {
        VStack(spacing: AYASpacing.sm) {
            ScreenHeader(
                "pregnancy.calendar.title",
                backAccessibilityKey: "pregnancy.calendar.back"
            ) {
                dismiss()
            }

            Text(verbatim: currentStatusText)
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentWeekSummary: some View {
        VStack(alignment: .leading, spacing: AYASpacing.lg) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AYASpacing.lg) {
                    weekMetric
                    Spacer(minLength: AYASpacing.sm)
                    trimesterBadge(calculation.trimester)
                }

                VStack(alignment: .leading, spacing: AYASpacing.md) {
                    weekMetric
                    trimesterBadge(calculation.trimester)
                }
            }

            ProgressView(value: calendarProgress)
                .tint(AYAColors.accent)
                .accessibilityLabel("pregnancy.calendar.progress.accessibility")
                .accessibilityValue(Text(verbatim: currentStatusText))
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

    private var weekMetric: some View {
        VStack(alignment: .leading, spacing: AYASpacing.xs) {
            Text(verbatim: "\(currentWeek)")
                .ayaTypography(.homeMetricValue)
                .foregroundStyle(AYAColors.textPrimary)

            Text(verbatim: totalWeeksText)
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textTertiary)
        }
    }

    private func trimesterSection(_ trimester: PregnancyTrimester) -> some View {
        let isCurrent = trimester == calculation.trimester

        return VStack(alignment: .leading, spacing: AYASpacing.lg) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AYASpacing.md) {
                    trimesterIdentity(trimester)
                    Spacer(minLength: AYASpacing.sm)
                    if isCurrent { currentBadge }
                }

                VStack(alignment: .leading, spacing: AYASpacing.sm) {
                    trimesterIdentity(trimester)
                    if isCurrent { currentBadge }
                }
            }

            LazyVGrid(columns: weekColumns, spacing: AYASpacing.sm) {
                ForEach(Array(trimester.weekRange), id: \.self) { week in
                    weekCell(week, trimester: trimester)
                }
            }
        }
        .padding(AYASpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isCurrent ? AYAColors.pregnancyTint : AYAColors.surfaceElevated,
            in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(isCurrent ? AYAColors.accent : AYAColors.border, lineWidth: 1)
        }
    }

    private func trimesterIdentity(_ trimester: PregnancyTrimester) -> some View {
        VStack(alignment: .leading, spacing: AYASpacing.xs) {
            Text(LocalizedStringKey(trimester.calendarTitleLocalizationKey))
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(LocalizedStringKey(trimester.calendarSubtitleLocalizationKey))
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentBadge: some View {
        Text("pregnancy.calendar.current")
            .ayaTypography(.metadata)
            .foregroundStyle(AYAColors.emphasis)
            .padding(.horizontal, AYASpacing.sm)
            .frame(minHeight: 28)
            .background(AYAColors.pregnancySurface, in: Capsule())
            .fixedSize()
    }

    private func trimesterBadge(_ trimester: PregnancyTrimester) -> some View {
        Text(LocalizedStringKey(trimester.calendarTitleLocalizationKey))
            .ayaTypography(.metadata)
            .foregroundStyle(AYAColors.emphasis)
            .padding(.horizontal, AYASpacing.md)
            .frame(minHeight: 32)
            .background(AYAColors.pregnancySurface, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }

    private func weekCell(_ week: Int, trimester: PregnancyTrimester) -> some View {
        let state = PregnancyJourneyWeekState(week: week, currentWeek: currentWeek)

        return Text(verbatim: "\(week)")
            .ayaTypography(.metadata)
            .foregroundStyle(weekForeground(for: state))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(weekBackground(for: state), in: Circle())
            .overlay {
                if state == .future {
                    Circle().stroke(AYAColors.border, lineWidth: 1)
                }
            }
            .accessibilityLabel(Text(verbatim: weekAccessibilityLabel(week, trimester: trimester, state: state)))
            .accessibilityAddTraits(state == .current ? .isSelected : [])
    }

    private func weekForeground(for state: PregnancyJourneyWeekState) -> Color {
        switch state {
        case .past: AYAColors.textSecondary
        case .current: AYAColors.onAccent
        case .future: AYAColors.textPrimary
        }
    }

    private func weekBackground(for state: PregnancyJourneyWeekState) -> Color {
        switch state {
        case .past: AYAColors.accentSoft
        case .current: AYAColors.emphasis
        case .future: AYAColors.surfaceElevated
        }
    }

    private var weekColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 44), spacing: AYASpacing.sm)]
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }

    private var currentStatusText: String {
        let format = selectedLanguage.localizedString(forKey: "pregnancy.calendar.current_status")
        return String(
            format: format,
            locale: locale,
            currentWeek,
            selectedLanguage.localizedString(forKey: calculation.trimester.calendarTitleLocalizationKey)
        )
    }

    private var totalWeeksText: String {
        let format = selectedLanguage.localizedString(forKey: "pregnancy.calendar.total_weeks")
        return String(format: format, locale: locale, totalSupportedWeeks)
    }

    private func weekAccessibilityLabel(
        _ week: Int,
        trimester: PregnancyTrimester,
        state: PregnancyJourneyWeekState
    ) -> String {
        let format = selectedLanguage.localizedString(forKey: "pregnancy.calendar.week.accessibility")
        return String(
            format: format,
            locale: locale,
            week,
            selectedLanguage.localizedString(forKey: state.localizationKey),
            selectedLanguage.localizedString(forKey: trimester.calendarTitleLocalizationKey)
        )
    }
}

#Preview("Pregnancy Overview — Week 18") {
    NavigationStack {
        PregnancyCalendarView(
            profile: PregnancyProfile(referenceWeek: 18, referenceDate: Date())!
        )
        .environment(\.locale, Locale(identifier: "en"))
    }
}

#Preview("Pregnancy Overview — Week 42 — Large Type") {
    NavigationStack {
        PregnancyCalendarView(
            profile: PregnancyProfile(referenceWeek: 42, referenceDate: Date())!
        )
        .environment(\.locale, Locale(identifier: "tr"))
        .environment(\.dynamicTypeSize, .accessibility3)
    }
}
