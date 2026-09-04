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
        SettingsGroup("settings.security.section") {
            SettingsToggleRow(
                icon: SettingsRowIcon(symbol: "faceid"),
                titleKey: "settings.security.face_id.title",
                value: SettingsRowValue("settings.security.face_id.description"),
                isOn: faceIDBinding,
                isEnabled: !isAuthenticating
            )
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
