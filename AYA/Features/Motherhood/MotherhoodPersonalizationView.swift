import SwiftUI

struct MotherhoodPersonalizationView: View {
    let returnToThemes: (() -> Void)?
    let completion: () -> Void

    @StateObject private var viewModel: MotherhoodPersonalizationViewModel
    @State private var draftRange: MotherhoodAgeRange = .toddler
    @State private var isPickerPresented = false

    init(
        returnToThemes: (() -> Void)? = nil,
        completion: @escaping () -> Void
    ) {
        self.returnToThemes = returnToThemes
        self.completion = completion
        _viewModel = StateObject(wrappedValue: MotherhoodPersonalizationViewModel())
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    introduction.padding(.top, AYASpacing.xl)
                    question.padding(.top, AYASpacing.xxl)

                    Spacer(minLength: AYASpacing.xxl)

                    OnboardingPrivacyNotice(
                        descriptionKey: "motherhood.personalization.privacy.description"
                    )
                }
                .hesiaScreenPadding()
                .padding(.top, 8)
                .padding(.bottom, AYASpacing.xl)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: AYASpacing.xs) {
                primaryAction
                if let returnToThemes {
                    OnboardingReturnToThemesButton(
                        accessibilityIdentifier: "motherhood.personalization.return_to_themes",
                        action: returnToThemes
                    )
                }
            }
            .hesiaBottomBar()
        }
        .sheet(isPresented: $isPickerPresented) { pickerSheet }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

            Spacer()

            SingleStepProgressIndicator(
                accessibilityLabelKey: "motherhood.personalization.progress"
            )
            .frame(width: 118)

            Spacer()

            Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("motherhood.personalization.title")
                .ayaTypography(.screenTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("motherhood.personalization.subtitle")
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("motherhood.personalization.question")
                .ayaTypography(.sectionTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("motherhood.personalization.helper")
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)

            Button {
                draftRange = viewModel.selectedRange
                isPickerPresented = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "figure.and.child.holdinghands")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AYAColors.primary)
                        .frame(width: 24)

                    Text(LocalizedStringKey(viewModel.selectedRange.titleLocalizationKey))
                        .ayaTypography(.body)
                        .foregroundStyle(AYAColors.textPrimary)

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
            .padding(.top, 18)
            .accessibilityLabel("motherhood.personalization.question")
            .accessibilityValue(LocalizedStringKey(viewModel.selectedRange.titleLocalizationKey))
            .accessibilityIdentifier("motherhood.personalization.range.field")
        }
    }

    private var primaryAction: some View {
        Button {
            viewModel.save()
            completion()
        } label: {
            HStack {
                Text("motherhood.personalization.continue")
                Spacer()
                HesiaIcon.arrowRight.view(size: 15)
            }
            .padding(.horizontal, AYASpacing.lg)
        }
        .buttonStyle(.appPrimary)
        .accessibilityIdentifier("motherhood.personalization.continue")
    }

    private var pickerSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("motherhood.personalization.picker.title")
                .ayaTypography(.screenTitle)
                .foregroundStyle(AYAColors.textPrimary)

            Picker("motherhood.personalization.question", selection: $draftRange) {
                ForEach(MotherhoodAgeRange.allCases) { range in
                    Text(LocalizedStringKey(range.titleLocalizationKey)).tag(range)
                }
            }
            .pickerStyle(.wheel)
            .tint(AYAColors.primary)

            Button {
                viewModel.selectedRange = draftRange
                isPickerPresented = false
            } label: {
                Text("motherhood.personalization.picker.confirm")
            }
            .buttonStyle(.appPrimary)
        }
        .padding(22)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

}

#Preview("Motherhood Personalization — Türkçe") {
    NavigationStack {
        MotherhoodPersonalizationView(completion: {})
            .environment(\.locale, Locale(identifier: "tr"))
    }
}

#Preview("Motherhood Personalization — English") {
    NavigationStack {
        MotherhoodPersonalizationView(completion: {})
            .environment(\.locale, Locale(identifier: "en"))
    }
}
