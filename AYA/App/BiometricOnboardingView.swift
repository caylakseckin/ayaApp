import SwiftUI

struct BiometricOnboardingView: View {
    let completion: (_ authenticated: Bool) -> Void

    @AppStorage(BiometricPreferenceKeys.isEnabled) private var isFaceIDEnabled = false
    @AppStorage("app.language") private var languageCode = AppLanguage.defaultExplicitLanguage.rawValue
    @State private var isAuthenticating = false
    @State private var showsAuthenticationError = false

    private let authenticationService = BiometricAuthenticationService()

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .defaultExplicitLanguage
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AYASpacing.xl) {
                Spacer(minLength: AYASpacing.xxxl)

                Image(systemName: "faceid")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(AYAColors.accent)
                    .frame(width: 112, height: 112)
                    .background(AYAColors.accentSoft, in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: AYASpacing.md) {
                    Text("biometric.onboarding.title")
                        .ayaTypography(.screenTitle)
                        .foregroundStyle(AYAColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text("biometric.onboarding.description")
                        .ayaTypography(.body)
                        .foregroundStyle(AYAColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: AYASpacing.lg) {
                    OnboardingBenefitRow(
                        icon: .lock,
                        titleKey: "biometric.onboarding.benefit.private.title",
                        descriptionKey: "biometric.onboarding.benefit.private.description"
                    )
                    OnboardingBenefitRow(
                        icon: .check,
                        titleKey: "biometric.onboarding.benefit.simple.title",
                        descriptionKey: "biometric.onboarding.benefit.simple.description"
                    )
                }
                .padding(AYASpacing.xl)
                .background(
                    AYAColors.surfaceElevated,
                    in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                        .stroke(AYAColors.separator, lineWidth: 1)
                }
                .ayaElevation(.card)

                Spacer(minLength: AYASpacing.xxl)
            }
            .hesiaScreenPadding()
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: AYASpacing.sm) {
                Button {
                    enableFaceID()
                } label: {
                    if isAuthenticating {
                        ProgressView()
                            .tint(AYAColors.onAccent)
                            .accessibilityLabel("biometric.authenticating")
                    } else {
                        Text("biometric.onboarding.enable")
                    }
                }
                .buttonStyle(.appPrimary)
                .disabled(isAuthenticating || !authenticationService.isFaceIDAvailable)
                .accessibilityIdentifier("biometric.onboarding.enable.button")

                OnboardingSecondaryButton(
                    titleKey: "biometric.onboarding.skip",
                    isEnabled: !isAuthenticating,
                    accessibilityIdentifier: "biometric.onboarding.skip.button"
                ) {
                    isFaceIDEnabled = false
                    completion(false)
                }

                if !authenticationService.isFaceIDAvailable {
                    Text("biometric.error.unavailable")
                        .ayaTypography(.metadata)
                        .foregroundStyle(AYAColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .hesiaBottomBar()
        }
        .alert("biometric.error.title", isPresented: $showsAuthenticationError) {
            Button("common.close", role: .cancel) {}
        } message: {
            Text("biometric.error.authentication_failed")
        }
    }


    private func enableFaceID() {
        guard authenticationService.isFaceIDAvailable else {
            showsAuthenticationError = true
            return
        }

        isAuthenticating = true
        Task {
            defer { isAuthenticating = false }

            do {
                let reason = language.localizedString(forKey: "biometric.authentication.reason")
                if try await authenticationService.authenticate(reason: reason) {
                    isFaceIDEnabled = true
                    completion(true)
                }
            } catch {
                showsAuthenticationError = true
            }
        }
    }
}

#Preview("Face ID — Türkçe") {
    BiometricOnboardingView { _ in }
        .environment(\.locale, Locale(identifier: "tr"))
}

#Preview("Face ID — English") {
    BiometricOnboardingView { _ in }
        .environment(\.locale, Locale(identifier: "en"))
}
