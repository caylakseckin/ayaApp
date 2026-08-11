import SwiftUI

struct PregnancySetupView: View {
    let returnToThemes: (() -> Void)?
    let completion: () -> Void

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @StateObject private var viewModel: PregnancySetupViewModel
    @State private var isPickerPresented = false
    @State private var draftWeek = 18
    @Environment(\.locale) private var locale

    init(
        returnToThemes: (() -> Void)? = nil,
        completion: @escaping () -> Void
    ) {
        self.returnToThemes = returnToThemes
        self.completion = completion
        _viewModel = StateObject(wrappedValue: PregnancySetupViewModel())
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    titleBlock
                        .padding(.top, 22)
                    question
                        .padding(.top, 38)

                    Spacer(minLength: 34)

                    OnboardingPrivacyNotice(
                        descriptionKey: "pregnancy.setup.privacy.description"
                    )
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 92)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                primaryAction
                if let returnToThemes {
                    OnboardingReturnToThemesButton(
                        accessibilityIdentifier: "pregnancy.setup.return_to_themes",
                        action: returnToThemes
                    )
                }
            }
            .background(AYAColors.backgroundPrimary.opacity(0.98))
        }
        .sheet(isPresented: $isPickerPresented) { pickerSheet }
    }

    private var topBar: some View {
        HStack(spacing: 18) {
            Color.clear
                .frame(width: 46, height: 46)
                .accessibilityHidden(true)

            SingleStepProgressIndicator(accessibilityLabelKey: "pregnancy.setup.progress")
                .frame(maxWidth: .infinity)

            Color.clear
                .frame(width: 46, height: 46)
                .accessibilityHidden(true)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("pregnancy.setup.title")
                .ayaTypography(.screenTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("pregnancy.setup.subtitle")
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("pregnancy.setup.question")
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("pregnancy.setup.helper")
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .padding(.top, 7)

            Button {
                draftWeek = viewModel.selectedWeek ?? 18
                isPickerPresented = true
            } label: {
                HStack(spacing: 12) {
                    HesiaIcon.calendar.view(size: 18)
                        .foregroundStyle(AYAColors.primary)
                        .frame(width: 24)

                    Text(verbatim: weekFieldText)
                        .ayaTypography(.body)
                        .foregroundStyle(
                            viewModel.selectedWeek == nil
                                ? AYAColors.textSecondary
                                : AYAColors.textPrimary
                        )

                    Spacer(minLength: 8)

                    HesiaIcon.caretDown.view(size: 13)
                        .foregroundStyle(AYAColors.primary)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(AYAColors.surface, in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                        .stroke(AYAColors.border, lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .accessibilityLabel("pregnancy.setup.question")
            .accessibilityValue(weekFieldText)
            .accessibilityIdentifier("pregnancy.setup.week.field")
        }
    }

    private var primaryAction: some View {
        Button {
            if viewModel.save() { completion() }
        } label: {
            HStack {
                Text("pregnancy.setup.continue")
                Spacer()
                HesiaIcon.arrowRight.view(size: 15)
            }
            .padding(.horizontal, 20)
        }
        .buttonStyle(.appPrimary)
        .disabled(!viewModel.canContinue)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .accessibilityIdentifier("pregnancy.setup.continue")
    }

    private var pickerSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("pregnancy.setup.picker.title")
                .ayaTypography(.screenTitle)
                .foregroundStyle(AYAColors.textPrimary)

            Picker("pregnancy.setup.question", selection: $draftWeek) {
                ForEach(1...42, id: \.self) { week in
                    Text(verbatim: formattedWeek(week)).tag(week)
                }
            }
            .pickerStyle(.wheel)
            .tint(AYAColors.primary)
            .frame(maxWidth: .infinity)

            Button {
                viewModel.selectedWeek = draftWeek
                isPickerPresented = false
            } label: {
                Text("pregnancy.setup.picker.confirm")
            }
            .buttonStyle(.appPrimary)
        }
        .padding(22)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var weekFieldText: String {
        guard let selectedWeek = viewModel.selectedWeek else {
            return selectedLanguage.localizedString(forKey: "pregnancy.setup.week.placeholder")
        }
        return formattedWeek(selectedWeek)
    }

    private func formattedWeek(_ week: Int) -> String {
        let format = selectedLanguage.localizedString(forKey: "pregnancy.week.value")
        return String(format: format, locale: locale, week)
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }
}

struct SingleStepProgressIndicator: View {
    let accessibilityLabelKey: LocalizedStringKey

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(AYAColors.primary)
                .frame(width: 9, height: 9)
            Rectangle()
                .fill(AYAColors.divider)
                .frame(height: 1)
        }
        .frame(maxWidth: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelKey)
    }
}

#Preview("Pregnancy Setup — Türkçe") {
    NavigationStack {
        PregnancySetupView(completion: {})
            .environment(\.locale, Locale(identifier: "tr"))
    }
}

#Preview("Pregnancy Setup — English") {
    NavigationStack {
        PregnancySetupView(completion: {})
            .environment(\.locale, Locale(identifier: "en"))
    }
}
