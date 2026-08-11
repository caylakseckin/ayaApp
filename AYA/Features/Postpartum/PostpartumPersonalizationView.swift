import SwiftUI

struct PostpartumPersonalizationView: View {
    let mode: PostpartumPersonalizationMode
    let returnToThemes: (() -> Void)?
    let completion: () -> Void

    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue
    @StateObject private var viewModel: PostpartumPersonalizationViewModel
    @State private var draftDate: Date
    @State private var isDatePickerPresented = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(
        mode: PostpartumPersonalizationMode = .initial,
        returnToThemes: (() -> Void)? = nil,
        completion: @escaping () -> Void
    ) {
        self.mode = mode
        self.returnToThemes = returnToThemes
        self.completion = completion
        let model = PostpartumPersonalizationViewModel(mode: mode)
        _viewModel = StateObject(wrappedValue: model)
        _draftDate = State(initialValue: model.birthDate)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    introduction.padding(.top, 22)
                    question.padding(.top, 38)

                    Spacer(minLength: 34)

                    if mode == .initial {
                        OnboardingPrivacyNotice(
                            descriptionKey: "postpartum.personalization.privacy.description"
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 86)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                primaryAction
                if mode == .initial, let returnToThemes {
                    OnboardingReturnToThemesButton(
                        accessibilityIdentifier: "postpartum.personalization.return_to_themes",
                        action: returnToThemes
                    )
                }
            }
            .background(AYAColors.backgroundPrimary.opacity(0.98))
        }
        .sheet(isPresented: $isDatePickerPresented) { datePickerSheet }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if mode == .edit {
                Button(action: goBack) {
                    HesiaIcon.caretLeft.view(size: 17)
                        .foregroundStyle(AYAColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AYAColors.surface, in: Circle())
                        .overlay { Circle().stroke(AYAColors.divider, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("postpartum.personalization.back")
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }

            Spacer()

            SingleStepProgressIndicator(
                accessibilityLabelKey: "postpartum.personalization.progress"
            )
            .frame(width: 118)

            Spacer()

            Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("postpartum.personalization.title")
                .ayaTypography(.screenTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("postpartum.personalization.subtitle")
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("postpartum.birth.question")
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("postpartum.birth.helper")
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)

            dateInput.padding(.top, 18)

            Text("postpartum.birth.update_hint")
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textSecondary)
                .padding(.top, 12)
        }
    }

    private var dateInput: some View {
        Button {
            draftDate = viewModel.birthDate
            isDatePickerPresented = true
        } label: {
            HStack(spacing: 12) {
                HesiaIcon.calendar.view(size: 18)
                    .foregroundStyle(AYAColors.primary)
                    .frame(width: 22)

                Text(verbatim: formattedBirthDate)
                    .ayaTypography(.body)
                    .foregroundStyle(AYAColors.textPrimary)

                Spacer(minLength: 8)

                HesiaIcon.caretDown.view(size: 13)
                    .foregroundStyle(AYAColors.textSecondary)
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
        .accessibilityLabel("postpartum.birth.question")
        .accessibilityValue(formattedBirthDate)
        .accessibilityIdentifier("postpartum.birth_date.field")
    }

    private var primaryAction: some View {
        Button {
            if viewModel.save() { completion() }
        } label: {
            HStack {
                Text(primaryActionKey)
                Spacer()
                HesiaIcon.arrowRight.view(size: 15)
            }
            .padding(.horizontal, 18)
        }
        .buttonStyle(.appPrimary)
        .disabled(!viewModel.isValid)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .accessibilityIdentifier("postpartum.personalization.primary_action")
    }

    private var datePickerSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("postpartum.birth.question")
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)

            DatePicker(
                "postpartum.birth.question",
                selection: $draftDate,
                in: ...viewModel.latestAllowedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(AYAColors.primary)

            Button {
                viewModel.selectBirthDate(draftDate)
                isDatePickerPresented = false
            } label: {
                Text("postpartum.birth.confirm")
            }
            .buttonStyle(.appPrimary)
        }
        .padding(22)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var formattedBirthDate: String {
        viewModel.birthDate.formatted(
            .dateTime.day().month(.wide).year().locale(selectedLanguage.locale)
        )
    }

    private var selectedLanguage: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .system
    }

    private var primaryActionKey: LocalizedStringKey {
        mode == .edit
            ? "postpartum.personalization.update"
            : "postpartum.personalization.continue"
    }

    private func goBack() {
        if mode == .edit {
            dismiss()
        } else if let returnToThemes {
            returnToThemes()
        } else {
            dismiss()
        }
    }
}

#Preview("Postpartum Personalization — Türkçe") {
    NavigationStack {
        PostpartumPersonalizationView(completion: {})
            .environment(\.locale, Locale(identifier: "tr"))
    }
}
