import SwiftUI

@MainActor
private final class BiometricLockViewModel: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published private(set) var isAuthenticating = false
    @Published private(set) var authenticationFailed = false

    private let authenticationService = BiometricAuthenticationService()

    init(isEnabled: Bool, initiallyUnlocked: Bool) {
        isLocked = isEnabled && !initiallyUnlocked
    }

    func lock() {
        guard !isAuthenticating else { return }
        isLocked = true
        authenticationFailed = false
    }

    func disableLock() {
        isLocked = false
        authenticationFailed = false
    }

    func unlock(reason: String) async {
        guard isLocked, !isAuthenticating else { return }

        isAuthenticating = true
        authenticationFailed = false
        defer { isAuthenticating = false }

        do {
            if try await authenticationService.authenticate(
                reason: reason,
                allowDevicePasscode: true
            ) {
                isLocked = false
            }
        } catch {
            authenticationFailed = true
        }
    }
}

struct BiometricLockContainer<Content: View>: View {
    @AppStorage(BiometricPreferenceKeys.isEnabled) private var isFaceIDEnabled = false
    @AppStorage("app.language") private var languageCode = AppLanguage.defaultExplicitLanguage.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: BiometricLockViewModel

    private let content: Content

    init(
        initiallyUnlocked: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        let isEnabled = UserDefaults.standard.bool(forKey: BiometricPreferenceKeys.isEnabled)
        _viewModel = StateObject(
            wrappedValue: BiometricLockViewModel(
                isEnabled: isEnabled,
                initiallyUnlocked: initiallyUnlocked
            )
        )
        self.content = content()
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .defaultExplicitLanguage
    }

    var body: some View {
        ZStack {
            content
                .opacity(isFaceIDEnabled && viewModel.isLocked ? 0 : 1)
                .allowsHitTesting(!isFaceIDEnabled || !viewModel.isLocked)
                .accessibilityHidden(isFaceIDEnabled && viewModel.isLocked)

            if isFaceIDEnabled && viewModel.isLocked {
                lockScreen
            }
        }
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .task(id: isFaceIDEnabled) {
            if isFaceIDEnabled {
                await unlock()
            } else {
                viewModel.disableLock()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard isFaceIDEnabled else { return }

            if newPhase == .background {
                viewModel.lock()
            } else if newPhase == .active {
                Task { await unlock() }
            }
        }
    }

    private var lockScreen: some View {
        VStack(spacing: AYASpacing.xl) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AYAColors.accent)
                .frame(width: 104, height: 104)
                .background(AYAColors.accentSoft, in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: AYASpacing.sm) {
                Text("biometric.lock.title")
                    .ayaTypography(.screenTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(
                    viewModel.authenticationFailed
                        ? "biometric.error.authentication_failed"
                        : "biometric.lock.description"
                )
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await unlock() }
            } label: {
                if viewModel.isAuthenticating {
                    ProgressView()
                        .tint(AYAColors.onAccent)
                        .accessibilityLabel("biometric.authenticating")
                } else {
                    Text("biometric.lock.unlock")
                }
            }
            .buttonStyle(.appPrimary)
            .disabled(viewModel.isAuthenticating)
            .accessibilityIdentifier("biometric.lock.unlock.button")

            Spacer()
        }
        .padding(.horizontal, AYASpacing.xl)
        .padding(.vertical, AYASpacing.xxxl)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func unlock() async {
        let reason = language.localizedString(forKey: "biometric.authentication.reason")
        await viewModel.unlock(reason: reason)
    }
}
