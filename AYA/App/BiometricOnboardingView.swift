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
                    benefitRow(
                        icon: .lock,
                        title: "biometric.onboarding.benefit.private.title",
                        description: "biometric.onboarding.benefit.private.description"
                    )
                    benefitRow(
                        icon: .check,
                        title: "biometric.onboarding.benefit.simple.title",
                        description: "biometric.onboarding.benefit.simple.description"
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
            .padding(.horizontal, AYASpacing.xl)
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

                Button {
                    isFaceIDEnabled = false
                    completion(false)
                } label: {
                    Text("biometric.onboarding.skip")
                        .font(AYATypography.ui(size: 15, weight: .medium))
                        .foregroundStyle(AYAColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating)
                .accessibilityIdentifier("biometric.onboarding.skip.button")

                if !authenticationService.isFaceIDAvailable {
                    Text("biometric.error.unavailable")
                        .font(AYATypography.ui(size: 12))
                        .foregroundStyle(AYAColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 512)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AYASpacing.xl)
            .padding(.top, AYASpacing.sm)
            .padding(.bottom, AYASpacing.md)
            .background(AYAColors.backgroundPrimary.opacity(0.96))
        }
        .alert("biometric.error.title", isPresented: $showsAuthenticationError) {
            Button("common.close", role: .cancel) {}
        } message: {
            Text("biometric.error.authentication_failed")
        }
    }

    private func benefitRow(
        icon: HesiaIcon,
        title: LocalizedStringKey,
        description: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .top, spacing: AYASpacing.md) {
            icon.view(size: 19)
                .foregroundStyle(AYAColors.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: AYASpacing.xs) {
                Text(title)
                    .font(AYATypography.ui(size: 15, weight: .medium))
                    .foregroundStyle(AYAColors.textPrimary)

                Text(description)
                    .font(AYATypography.ui(size: 13))
                    .foregroundStyle(AYAColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
