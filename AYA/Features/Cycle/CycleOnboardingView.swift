import SwiftUI

private enum CycleOnboardingAdvisory {
    case lastPeriodDate
    case cycleLength
    case periodDuration

    var titleKey: LocalizedStringKey {
        switch self {
        case .lastPeriodDate: "cycle.onboarding.advisory.last_period.title"
        case .cycleLength: "cycle.onboarding.advisory.cycle_length.title"
        case .periodDuration: "cycle.onboarding.advisory.period_duration.title"
        }
    }

    var messageKey: LocalizedStringKey {
        switch self {
        case .lastPeriodDate: "cycle.onboarding.advisory.last_period.message"
        case .cycleLength: "cycle.onboarding.advisory.cycle_length.message"
        case .periodDuration: "cycle.onboarding.advisory.period_duration.message"
        }
    }
}

@MainActor
struct CycleOnboardingView: View {
    let mode: CycleOnboardingMode
    let returnToThemes: (() -> Void)?
    let completion: () -> Void

    @StateObject private var viewModel: CycleOnboardingViewModel
    @State private var isDatePickerPresented = false
    @State private var draftDate = Date()
    @State private var advisory: CycleOnboardingAdvisory?
    @State private var hasAcknowledgedOldDate = false
    @State private var stepFeedbackTrigger = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(
        mode: CycleOnboardingMode = .initial,
        returnToThemes: (() -> Void)? = nil,
        completion: @escaping () -> Void
    ) {
        self.mode = mode
        self.returnToThemes = returnToThemes
        self.completion = completion
        _viewModel = StateObject(wrappedValue: CycleOnboardingViewModel(mode: mode))
    }

    var body: some View {
        ZStack {
            AYAColors.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar

                    introduction
                        .padding(.top, 22)

                    stepContent
                        .id(viewModel.currentStep)
                        .padding(.top, 38)
                        .transition(stepTransition)

                    Spacer(minLength: 34)

                    if mode == .initial {
                        OnboardingPrivacyNotice(
                            descriptionKey: "cycle.onboarding.privacy.description"
                        )
                    }
                }
                .hesiaScreenPadding()
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.selection, trigger: stepFeedbackTrigger)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: AYASpacing.xs) {
                primaryAction
                if mode == .initial, let returnToThemes {
                    OnboardingReturnToThemesButton(
                        accessibilityIdentifier: "cycle.onboarding.return_to_themes",
                        action: returnToThemes
                    )
                }
            }
            .hesiaBottomBar()
        }
        .sheet(isPresented: $isDatePickerPresented) {
            datePickerSheet
        }
        .alert(
            advisory?.titleKey ?? "cycle.onboarding.advisory.cycle_length.title",
            isPresented: rangeAdvisoryBinding
        ) {
            Button("cycle.onboarding.advisory.edit", role: .cancel) {
                advisory = nil
            }
            Button("cycle.onboarding.advisory.continue") {
                advisory = nil
                performAdvance()
            }
        } message: {
            Text(advisory?.messageKey ?? "")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if mode == .edit {
                Button(action: goBack) {
                    HesiaIcon.caretLeft.view(size: 17)
                        .foregroundStyle(AYAColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AYAColors.surface, in: Circle())
                        .overlay {
                            Circle().stroke(AYAColors.separator, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("cycle.onboarding.back.accessibility")
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }

            Spacer()

            CycleProgressIndicator(currentStep: viewModel.currentStep)
                .frame(width: 118)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .padding(.top, 8)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("cycle.onboarding.title")
                .ayaTypography(.screenTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("cycle.onboarding.subtitle")
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var stepContent: some View {
        switch viewModel.currentStep {
        case .lastPeriodStart:
            question(
                title: "cycle.onboarding.last_period.title",
                description: "cycle.onboarding.last_period.description"
            ) {
                dateInput
                CycleInputGuidance(
                    guidanceKey: "cycle.onboarding.last_period.guidance",
                    validationKey: nil
                )
            }
        case .cycleLength:
            question(
                title: "cycle.onboarding.cycle_length.title",
                description: "cycle.onboarding.cycle_length.description"
            ) {
                CycleNumericInput(
                    text: Binding(
                        get: { viewModel.averageLengthText },
                        set: { viewModel.updateAverageLength($0) }
                    ),
                    placeholder: "cycle.onboarding.cycle_length.placeholder",
                    accessibilityLabel: "cycle.onboarding.cycle_length.title",
                    accessibilityIdentifier: "cycle.onboarding.cycle_length.input"
                )
                CycleInputGuidance(
                    guidanceKey: "cycle.onboarding.cycle_length.guidance",
                    validationKey: validationMessageKey
                )
            }
        case .periodDuration:
            question(
                title: "cycle.onboarding.period_duration.title",
                description: "cycle.onboarding.period_duration.description"
            ) {
                CycleNumericInput(
                    text: Binding(
                        get: { viewModel.averagePeriodDurationText },
                        set: { viewModel.updateAveragePeriodDuration($0) }
                    ),
                    placeholder: "cycle.onboarding.period_duration.placeholder",
                    accessibilityLabel: "cycle.onboarding.period_duration.title",
                    accessibilityIdentifier: "cycle.onboarding.period_duration.input"
                )
                CycleInputGuidance(
                    guidanceKey: "cycle.onboarding.period_duration.guidance",
                    validationKey: validationMessageKey
                )
            }
        }
    }

    private var validationMessageKey: LocalizedStringKey? {
        viewModel.validationIssue.map { LocalizedStringKey($0.localizationKey) }
    }

    private func question<Content: View>(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(description)
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AYASpacing.sm)

            content()
                .padding(.top, 18)
        }
    }

    private var dateInput: some View {
        Button {
            draftDate = viewModel.lastPeriodStartDate ?? viewModel.latestAllowedDate
            isDatePickerPresented = true
        } label: {
            HStack(spacing: 12) {
                HesiaIcon.calendar.view(size: 18)
                    .foregroundStyle(AYAColors.primary)
                    .frame(width: 22)

                Text(dateInputText)
                    .ayaTypography(.body)
                    .foregroundStyle(
                        viewModel.lastPeriodStartDate == nil
                            ? AYAColors.textSecondary
                            : AYAColors.textPrimary
                    )

                Spacer(minLength: 8)

                HesiaIcon.caretDown.view(size: 13)
                    .foregroundStyle(AYAColors.textSecondary)
            }
            .padding(.horizontal, AYASpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(AYAColors.surface, in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                    .stroke(AYAColors.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("cycle.onboarding.last_period.title")
        .accessibilityValue(dateInputText)
        .accessibilityIdentifier("cycle.onboarding.date.input")
    }

    private var dateInputText: LocalizedStringKey {
        guard let date = viewModel.lastPeriodStartDate else {
            return "cycle.onboarding.last_period.placeholder"
        }
        return LocalizedStringKey(
            date.formatted(
                .dateTime
                    .day()
                    .month(.wide)
                    .year()
                    .locale(locale)
            )
        )
    }

    private var datePickerSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("cycle.onboarding.last_period.title")
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            DatePicker(
                "cycle.onboarding.last_period.title",
                selection: $draftDate,
                in: ...viewModel.latestAllowedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(AYAColors.primary)

            Button {
                confirmDateSelection()
            } label: {
                Text("cycle.onboarding.date_picker.confirm")
            }
            .buttonStyle(.appPrimary)
            .accessibilityIdentifier("cycle.onboarding.date_picker.confirm")
        }
        .padding(22)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert(
            "cycle.onboarding.advisory.last_period.title",
            isPresented: dateAdvisoryBinding
        ) {
            Button("cycle.onboarding.advisory.review", role: .cancel) {
                advisory = nil
            }
            Button("cycle.onboarding.advisory.confirm") {
                hasAcknowledgedOldDate = true
                advisory = nil
                isDatePickerPresented = false
            }
        } message: {
            Text("cycle.onboarding.advisory.last_period.message")
        }
    }

    private var primaryAction: some View {
        Button(action: advance) {
            HStack(spacing: AYASpacing.sm) {
                Text(
                    viewModel.currentStep == .periodDuration
                        ? finalActionKey
                        : "cycle.onboarding.continue"
                )
                Spacer()
                HesiaIcon.arrowRight.view(size: 15)
            }
            .padding(.horizontal, AYASpacing.lg)
        }
        .buttonStyle(.appPrimary)
        .disabled(!viewModel.isCurrentStepValid)
        .accessibilityIdentifier("cycle.onboarding.primary_action")
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .opacity.combined(with: .offset(x: 10))
    }

    private var finalActionKey: LocalizedStringKey {
        mode == .edit
            ? "cycle.onboarding.save_changes"
            : "cycle.onboarding.complete"
    }

    private func goBack() {
        guard viewModel.moveToPreviousStep() else {
            dismiss()
            return
        }
    }

    private func advance() {
        if viewModel.currentStep == .lastPeriodStart,
           viewModel.isLastPeriodStartOlderThan28Days,
           !hasAcknowledgedOldDate {
            draftDate = viewModel.lastPeriodStartDate ?? viewModel.latestAllowedDate
            isDatePickerPresented = true
            Task { @MainActor in
                await Task.yield()
                advisory = .lastPeriodDate
            }
            return
        }

        if viewModel.currentStep == .cycleLength,
           viewModel.isAverageLengthOutsideTypicalRange {
            advisory = .cycleLength
            return
        }

        if viewModel.currentStep == .periodDuration,
           viewModel.isAveragePeriodDurationOutsideTypicalRange {
            advisory = .periodDuration
            return
        }

        performAdvance()
    }

    private func performAdvance() {
        stepFeedbackTrigger += 1
        let didComplete: Bool
        if reduceMotion {
            didComplete = viewModel.advance()
        } else {
            var completionResult = false
            withAnimation(.easeOut(duration: 0.2)) {
                completionResult = viewModel.advance()
            }
            didComplete = completionResult
        }

        if didComplete {
            completion()
        }
    }

    private func confirmDateSelection() {
        hasAcknowledgedOldDate = false
        viewModel.selectLastPeriodStartDate(draftDate)

        if viewModel.isLastPeriodStartOlderThan28Days {
            advisory = .lastPeriodDate
        } else {
            isDatePickerPresented = false
        }
    }

    private var rangeAdvisoryBinding: Binding<Bool> {
        Binding(
            get: { advisory == .cycleLength || advisory == .periodDuration },
            set: { isPresented in
                if !isPresented { advisory = nil }
            }
        )
    }

    private var dateAdvisoryBinding: Binding<Bool> {
        Binding(
            get: { advisory == .lastPeriodDate },
            set: { isPresented in
                if !isPresented { advisory = nil }
            }
        )
    }
}

private struct CycleProgressIndicator: View {
    let currentStep: CycleOnboardingStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(CycleOnboardingStep.allCases.enumerated()), id: \.element) { index, step in
                if index > 0 {
                    Rectangle()
                        .fill(index <= currentStep.rawValue ? AYAColors.primary.opacity(0.5) : AYAColors.separator)
                        .frame(height: 1)
                }

                Circle()
                    .fill(circleFill(for: step))
                    .frame(width: step == currentStep ? 8 : 7, height: step == currentStep ? 8 : 7)
                    .overlay {
                        Circle().stroke(circleBorder(for: step), lineWidth: 1)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("cycle.onboarding.progress.accessibility")
        .accessibilityValue("\(currentStep.rawValue + 1) / \(CycleOnboardingStep.allCases.count)")
    }

    private func circleFill(for step: CycleOnboardingStep) -> Color {
        if step == currentStep { return AYAColors.primary }
        if step.rawValue < currentStep.rawValue { return AYAColors.primary.opacity(0.5) }
        return AYAColors.backgroundPrimary
    }

    private func circleBorder(for step: CycleOnboardingStep) -> Color {
        step.rawValue <= currentStep.rawValue ? AYAColors.primary : AYAColors.border
    }
}

private struct CycleNumericInput: View {
    @Binding var text: String
    let placeholder: LocalizedStringKey
    let accessibilityLabel: LocalizedStringKey
    let accessibilityIdentifier: String

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField(placeholder, text: $text)
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textPrimary)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .submitLabel(.done)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(text)

            Spacer(minLength: 8)

            Text("cycle.unit.day")
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textSecondary)
        }
        .padding(.horizontal, AYASpacing.lg)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(AYAColors.surface, in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                .stroke(isFocused ? AYAColors.primary : AYAColors.border, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous))
        .onTapGesture { isFocused = true }
        .accessibilityIdentifier(accessibilityIdentifier)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("common.done") {
                    isFocused = false
                }
                .ayaTypography(.button)
            }
        }
    }
}

private struct CycleInputGuidance: View {
    let guidanceKey: LocalizedStringKey
    let validationKey: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.xs) {
            guidanceRow(
                text: guidanceKey,
                foreground: AYAColors.textTertiary
            )

            if let validationKey {
                guidanceRow(
                    text: validationKey,
                    foreground: AYAColors.error
                )
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .padding(.top, AYASpacing.sm)
    }

    private func guidanceRow(
        text: LocalizedStringKey,
        foreground: Color
    ) -> some View {
        HStack(alignment: .top, spacing: AYASpacing.sm) {
            HesiaIcon.info.view(size: 14)
                .foregroundStyle(foreground)
                .frame(width: 18, height: 18)

            Text(text)
                .ayaTypography(.metadata)
                .foregroundStyle(foreground)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Cycle Onboarding — Türkçe") {
    NavigationStack {
        CycleOnboardingView(completion: {})
            .environment(\.locale, Locale(identifier: "tr"))
    }
}

#Preview("Cycle Onboarding — English") {
    NavigationStack {
        CycleOnboardingView(completion: {})
            .environment(\.locale, Locale(identifier: "en"))
    }
}
