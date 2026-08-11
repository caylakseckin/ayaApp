import SwiftUI

struct BiometricLockSettings: View {
    @AppStorage(BiometricPreferenceKeys.isEnabled) private var isEnabled = false
    @AppStorage("app.language") private var languageCode = AppLanguage.defaultExplicitLanguage.rawValue
    @State private var isAuthenticating = false
    @State private var showsAuthenticationError = false

    private let authenticationService = BiometricAuthenticationService()

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .defaultExplicitLanguage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.sm) {
            Text("settings.security.section")
                .font(AYATypography.ui(size: 13, weight: .medium))
                .foregroundStyle(AYAColors.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, AYASpacing.xs)

            Toggle(isOn: faceIDBinding) {
                HStack(spacing: AYASpacing.md) {
                    Image(systemName: "faceid")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(AYAColors.accent)
                        .frame(width: 22)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AYASpacing.xxs) {
                        Text("settings.security.face_id.title")
                            .font(AYATypography.ui(size: 15, weight: .medium))
                            .foregroundStyle(AYAColors.textPrimary)

                        Text("settings.security.face_id.description")
                            .font(AYATypography.ui(size: 12))
                            .foregroundStyle(AYAColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .tint(AYAColors.accent)
            .disabled(isAuthenticating)
            .padding(.horizontal, AYASpacing.lg)
            .padding(.vertical, AYASpacing.md)
            .frame(minHeight: 64)
            .background(
                AYAColors.cardSurface,
                in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                    .stroke(AYAColors.divider, lineWidth: 1)
            }
            .accessibilityIdentifier("settings.face_id.toggle")
        }
        .alert("biometric.error.title", isPresented: $showsAuthenticationError) {
            Button("common.close", role: .cancel) {}
        } message: {
            Text(
                authenticationService.isFaceIDAvailable
                    ? "biometric.error.authentication_failed"
                    : "biometric.error.unavailable"
            )
        }
    }

    private var faceIDBinding: Binding<Bool> {
        Binding(
            get: { isEnabled },
            set: { requestedValue in
                if requestedValue {
                    enableFaceID()
                } else {
                    isEnabled = false
                }
            }
        )
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
                    isEnabled = true
                }
            } catch {
                showsAuthenticationError = true
            }
        }
    }
}
