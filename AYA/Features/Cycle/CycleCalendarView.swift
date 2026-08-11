import SwiftUI

enum CycleCalendarPresentation: Equatable {
    case standard
    case tutorialPreview
}

struct CycleCalendarView: View {
    let profile: CycleProfile
    let presentation: CycleCalendarPresentation

    @State private var displayedMonth: Date
    @State private var selectedDate: Date

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @Environment(\.calendar) private var environmentCalendar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(
        profile: CycleProfile,
        presentation: CycleCalendarPresentation = .standard
    ) {
        self.profile = profile
        self.presentation = presentation
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        _displayedMonth = State(initialValue: calendar.dateInterval(of: .month, for: today)?.start ?? today)
        _selectedDate = State(initialValue: today)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AYASpacing.xl) {
                if presentation == .standard {
                    header
                }
                calendarSurface
                if presentation == .standard {
                    selectedDaySurface
                    phaseLegend

                    Text("cycle.calendar.disclaimer")
                        .ayaTypography(.metadata)
                        .foregroundStyle(AYAColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, AYASpacing.lg)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, presentation == .standard ? AYASpacing.xl : 0)
            .padding(.top, presentation == .standard ? AYASpacing.md : 0)
            .padding(.bottom, presentation == .standard ? AYASpacing.xxl : 0)
        }
        .scrollIndicators(.hidden)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard presentation == .tutorialPreview, !reduceMotion else { return }
            try? await Task.sleep(for: .milliseconds(1_050))
            guard
                !Task.isCancelled,
                let previewDate = calendar.date(byAdding: .day, value: 1, to: selectedDate)
            else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                selectedDate = previewDate
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                HesiaIcon.caretLeft.view(size: 17)
                    .foregroundStyle(AYAColors.emphasis)
                    .frame(width: 44, height: 44)
                    .background(AYAColors.surface, in: Circle())
                    .overlay { Circle().stroke(AYAColors.border, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("cycle.calendar.back")

            Text("cycle.calendar.title")
                .ayaTypography(.screenTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
    }

    private var calendarSurface: some View {
        VStack(spacing: AYASpacing.lg) {
            monthNavigation
            weekdayHeader

            LazyVGrid(columns: columns, spacing: AYASpacing.sm) {
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayButton(date)
                    } else {
                        Color.clear
                            .frame(height: 44)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(presentation == .standard ? AYASpacing.lg : AYASpacing.sm)
        .background(AYAColors.surfaceElevated, in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(AYAColors.border, lineWidth: 1)
        }
        .ayaCardShadow()
    }

    private var monthNavigation: some View {
        HStack {
            monthButton(
                icon: .caretLeft,
                accessibilityKey: "cycle.calendar.previous_month",
                offset: -1
            )

            Spacer()

            Text(verbatim: monthTitle)
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            monthButton(
                icon: .caretRight,
                accessibilityKey: "cycle.calendar.next_month",
                offset: 1
            )
        }
    }

    private func monthButton(
        icon: HesiaIcon,
        accessibilityKey: LocalizedStringKey,
        offset: Int
    ) -> some View {
        Button {
            moveMonth(by: offset)
        } label: {
            icon.view(size: 14)
                .foregroundStyle(AYAColors.emphasis)
                .frame(width: 44, height: 44)
                .background(AYAColors.accentSoft, in: Circle())
                .overlay { Circle().stroke(AYAColors.separator, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityKey)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(verbatim: symbol)
                    .ayaTypography(.metadata)
                    .foregroundStyle(AYAColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityHidden(true)
    }

    private func dayButton(_ date: Date) -> some View {
        let calculation = calculator.calculate(profile: profile, on: date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)

        return Button {
            if reduceMotion {
                selectedDate = date
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedDate = date
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        isSelected
                            ? AYAColors.emphasis
                            : CycleCalendarPhaseTheme.surface(for: calculation.currentPhase)
                    )

                Text(verbatim: "\(calendar.component(.day, from: date))")
                    .ayaTypography(.metadata)
                    .foregroundStyle(isSelected ? AYAColors.onAccent : AYAColors.textPrimary)

                if isToday && isSelected {
                    Circle()
                        .fill(AYAColors.onAccent)
                        .frame(width: 4, height: 4)
                        .offset(y: 14)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 40, height: 40)
            .overlay {
                if isToday && !isSelected {
                    Circle().stroke(AYAColors.emphasis, lineWidth: 1.5)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dayAccessibilityLabel(date, calculation: calculation))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedDaySurface: some View {
        let calculation = calculator.calculate(profile: profile, on: selectedDate)

        return VStack(alignment: .leading, spacing: AYASpacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AYASpacing.md) {
                    selectedDayIdentity(calculation)
                    Spacer(minLength: AYASpacing.sm)
                    selectedDayBadges(calculation.currentPhase)
                }

                VStack(alignment: .leading, spacing: AYASpacing.sm) {
                    selectedDayIdentity(calculation)
                    selectedDayBadges(calculation.currentPhase)
                }
            }

            Text(LocalizedStringKey(calculation.currentPhase.calendarHelperLocalizationKey))
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AYASpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AYAColors.cycleHeroSurface, in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(AYAColors.border, lineWidth: 1)
        }
    }

    private func selectedDayIdentity(_ calculation: CycleCalculation) -> some View {
        VStack(alignment: .leading, spacing: AYASpacing.xs) {
            Text(verbatim: selectedDateTitle)
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: cycleDayText(calculation.currentCycleDay))
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textSecondary)
        }
    }

    private func selectedDayBadges(_ phase: CyclePhase) -> some View {
        HStack(spacing: AYASpacing.sm) {
            if calendar.isDateInToday(selectedDate) {
                Text("cycle.calendar.today")
                    .ayaTypography(.metadata)
                    .foregroundStyle(AYAColors.textSecondary)
                    .padding(.horizontal, AYASpacing.sm)
                    .frame(minHeight: 28)
                    .background(AYAColors.surfaceElevated, in: Capsule())
            }

            Text(verbatim: localized(phase.nameLocalizationKey))
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.emphasis)
                .padding(.horizontal, AYASpacing.md)
                .frame(minHeight: 28)
                .background(CycleCalendarPhaseTheme.surface(for: phase), in: Capsule())
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var phaseLegend: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: AYASpacing.md
        ) {
            ForEach(CyclePhase.allCases) { phase in
                HStack(spacing: AYASpacing.sm) {
                    Circle()
                        .fill(CycleCalendarPhaseTheme.surface(for: phase))
                        .frame(width: 12, height: 12)
                        .overlay { Circle().stroke(AYAColors.separator, lineWidth: 1) }
                        .accessibilityHidden(true)

                    Text(verbatim: localized(phase.nameLocalizationKey))
                        .ayaTypography(.metadata)
                        .foregroundStyle(AYAColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(AYASpacing.lg)
        .background(AYAColors.surfaceElevated, in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(AYAColors.border, lineWidth: 1)
        }
    }

    private var calendar: Calendar {
        var calendar = environmentCalendar
        calendar.locale = locale
        return calendar
    }

    private var calculator: CycleCalculator {
        CycleCalculator(calendar: calendar)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    private var monthTitle: String {
        displayedMonth.formatted(
            .dateTime
                .month(.wide)
                .year()
                .locale(locale)
        )
    }

    private var selectedDateTitle: String {
        selectedDate.formatted(
            .dateTime
                .day()
                .month(.wide)
                .weekday(.wide)
                .locale(locale)
        )
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    private var monthCells: [Date?] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth)
        else { return [] }

        let firstDay = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingCount = (weekday - calendar.firstWeekday + 7) % 7
        let leading: [Date?] = Array(repeating: nil, count: leadingCount)
        let dates = dayRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
        return leading + dates.map(Optional.some)
    }

    private func moveMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else {
            return
        }
        displayedMonth = newMonth
        selectedDate = calendar.dateInterval(of: .month, for: newMonth)?.start ?? newMonth
    }

    private func localized(_ key: String) -> String {
        let language = AppLanguage(rawValue: languageCode) ?? .system
        return language.localizedString(forKey: key)
    }

    private func cycleDayText(_ day: Int) -> String {
        let format = localized("cycle.calendar.cycle_day_format")
        return String(format: format, locale: locale, day)
    }

    private func dayAccessibilityLabel(_ date: Date, calculation: CycleCalculation) -> String {
        let dateText = date.formatted(.dateTime.day().month(.wide).year().locale(locale))
        var components = [
            dateText,
            cycleDayText(calculation.currentCycleDay),
            localized(calculation.currentPhase.nameLocalizationKey)
        ]

        if calendar.isDate(date, inSameDayAs: selectedDate) {
            components.append(localized("cycle.calendar.selected"))
        }
        if calendar.isDateInToday(date) {
            components.append(localized("cycle.calendar.today"))
        }

        return components.joined(separator: ", ")
    }
}

#Preview("Cycle Calendar — Türkçe") {
    NavigationStack {
        CycleCalendarView(
            profile: CycleProfile(
                lastPeriodStartDate: Date().addingTimeInterval(-22 * 86_400),
                averageCycleLength: 28,
                averagePeriodDuration: 5
            )!
        )
        .environment(\.locale, Locale(identifier: "tr"))
    }
}

#Preview("Cycle Calendar — English — Large Type") {
    NavigationStack {
        CycleCalendarView(
            profile: CycleProfile(
                lastPeriodStartDate: Date().addingTimeInterval(-17 * 86_400),
                averageCycleLength: 28,
                averagePeriodDuration: 5
            )!
        )
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.dynamicTypeSize, .accessibility2)
    }
}
