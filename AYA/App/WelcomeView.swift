import SwiftUI

struct WelcomeView: View {
    let completion: () -> Void

    @AppStorage("app.language") private var languageCode = AppLanguage.defaultExplicitLanguage.rawValue
    @AppStorage("user.name") private var storedName = ""
    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: 104)
                    .accessibilityHidden(true)

                brand
                    .padding(.bottom, 24)

                form

                Spacer(minLength: 96)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
            .frame(minHeight: UIScreen.main.bounds.height - 44)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .background(background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            continueButton
                .frame(maxWidth: 512)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(AYAColors.backgroundPrimary.opacity(0.96))
        }
        .onAppear {
            name = storedName
            languageCode = AppLanguage.resolved(from: languageCode).rawValue
        }
    }

    private var background: some View {
        AYAColors.backgroundPrimary
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private var brand: some View {
        ZStack {
            Image("HESIA_enso_background_asset")
                .resizable()
                .scaledToFit()
                .frame(width: 310)
                .opacity(0.36)
                .offset(y: -20)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("welcome.brand")
                    .font(AYATypography.editorial(size: 62, weight: .semibold))
                    .foregroundStyle(AYAColors.emphasis)
                    .tracking(4)

                Text("welcome.title")
                    .ayaTypography(.screenTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("welcome.subtitle")
                    .ayaTypography(.body)
                    .foregroundStyle(AYAColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .offset(y: 18)
        }
        .frame(height: 250)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("welcome.name.prompt")
                    .ayaTypography(.body)
                    .foregroundStyle(AYAColors.textPrimary)

                TextField("welcome.name.placeholder", text: $name)
                    .ayaTypography(.body)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background(AYAColors.surface, in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                            .stroke(isNameFocused ? AYAColors.accent : AYAColors.separator, lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous))
                    .simultaneousGesture(
                        TapGesture().onEnded { isNameFocused = true }
                    )
                    .accessibilityIdentifier("welcome.name.field")
            }

            if HESIAFeatureFlags.supportsMultipleLanguages {
                VStack(alignment: .leading, spacing: 10) {
                    Text("welcome.language.prompt")
                        .ayaTypography(.body)
                        .foregroundStyle(AYAColors.textPrimary)

                    HStack(spacing: 10) {
                        languageButton(.turkish)
                        languageButton(.english)
                    }
                }
            }

            MeditationReminderSettings(presentation: .welcome)
        }
        .padding(18)
        .background(AYAColors.surface, in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(AYAColors.separator, lineWidth: 1)
        }
        .ayaElevation(.card)
    }

    private func languageButton(_ language: AppLanguage) -> some View {
        let isSelected = languageCode == language.rawValue

        return Button {
            languageCode = language.rawValue
        } label: {
            HStack(spacing: 8) {
                HesiaSelectionIndicator(
                    isSelected: isSelected,
                    selectedFill: AYAColors.surface,
                    selectedForeground: AYAColors.primary,
                    unselectedStroke: AYAColors.primary
                )
                Text(verbatim: language.nativeTitle)
                    .lineLimit(1)
            }
            .ayaTypography(.body)
            .foregroundStyle(isSelected ? AYAColors.onAccent : AYAColors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(isSelected ? AYAColors.accent : AYAColors.surface, in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                    .stroke(isSelected ? AYAColors.accent : AYAColors.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier("welcome.language.\(language.rawValue)")
    }

    private var continueButton: some View {
        Button {
            storedName = normalizedName
            completion()
        } label: {
            Text("welcome.continue")
        }
        .buttonStyle(.appPrimary)
        .disabled(normalizedName.isEmpty)
        .accessibilityIdentifier("welcome.continue.button")
    }
}

#Preview("Welcome — Türkçe") {
    WelcomeView(completion: {})
        .environment(\.locale, Locale(identifier: "tr"))
}

#Preview("Welcome — English") {
    WelcomeView(completion: {})
        .environment(\.locale, Locale(identifier: "en"))
}
