import SwiftUI

enum BiometricAutomaticUnlockPolicy {
    static func shouldAttempt(
        isLocked: Bool,
        isAuthenticating: Bool,
        hasAttempted: Bool
    ) -> Bool {
        isLocked && !isAuthenticating && !hasAttempted
    }
}

@MainActor
final class BiometricLockViewModel: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published private(set) var isAuthenticating = false
    @Published private(set) var authenticationFailed = false

    private let authenticationService = BiometricAuthenticationService()
    private var hasAttemptedAutomaticUnlock = false

    init(isEnabled: Bool, initiallyUnlocked: Bool) {
        isLocked = isEnabled && !initiallyUnlocked
    }

    func lock() {
        guard !isAuthenticating, !isLocked else { return }
        isLocked = true
        authenticationFailed = false
        hasAttemptedAutomaticUnlock = false
    }

    func disableLock() {
        isLocked = false
        authenticationFailed = false
        hasAttemptedAutomaticUnlock = false
    }

    func unlock(reason: String, automatically: Bool) async {
        guard isLocked, !isAuthenticating else { return }
        if automatically {
            guard BiometricAutomaticUnlockPolicy.shouldAttempt(
                isLocked: isLocked,
                isAuthenticating: isAuthenticating,
                hasAttempted: hasAttemptedAutomaticUnlock
            ) else { return }
            hasAttemptedAutomaticUnlock = true
        }

        isAuthenticating = true
        authenticationFailed = false
        defer { isAuthenticating = false }

        do {
            let authenticated = try await authenticationService.authenticate(
                reason: reason,
                allowDevicePasscode: true
            )
            if authenticated {
                isLocked = false
            } else {
                authenticationFailed = true
            }
        } catch {
            authenticationFailed = true
        }
    }
}

private struct BiometricLockViewModelEnvironmentKey: EnvironmentKey {
    static let defaultValue: BiometricLockViewModel? = nil
}

extension EnvironmentValues {
    var biometricLockViewModel: BiometricLockViewModel? {
        get { self[BiometricLockViewModelEnvironmentKey.self] }
        set { self[BiometricLockViewModelEnvironmentKey.self] = newValue }
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
        BiometricProtectedContent {
            content
        }
        .environment(\.biometricLockViewModel, viewModel)
        .task(id: isFaceIDEnabled) {
            if isFaceIDEnabled {
                await unlock(automatically: true)
            } else {
                viewModel.disableLock()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard isFaceIDEnabled else { return }

            if newPhase == .inactive || newPhase == .background {
                viewModel.lock()
            } else if newPhase == .active {
                Task { await unlock(automatically: true) }
            }
        }
    }

    private func unlock(automatically: Bool) async {
        let reason = language.localizedString(forKey: "biometric.authentication.reason")
        await viewModel.unlock(reason: reason, automatically: automatically)
    }
}

struct BiometricProtectedContent<Content: View>: View {
    @AppStorage(BiometricPreferenceKeys.isEnabled) private var isFaceIDEnabled = false
    @Environment(\.biometricLockViewModel) private var viewModel

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if let viewModel {
            BiometricProtectedObservedContent(
                isEnabled: isFaceIDEnabled,
                viewModel: viewModel,
                content: content
            )
        } else {
            content
        }
    }
}

private struct BiometricProtectedObservedContent<Content: View>: View {
    let isEnabled: Bool
    @ObservedObject var viewModel: BiometricLockViewModel
    let content: Content

    private var isLocked: Bool {
        isEnabled && viewModel.isLocked
    }

    var body: some View {
        ZStack {
            content
                .opacity(isLocked ? 0 : 1)
                .allowsHitTesting(!isLocked)
                .accessibilityHidden(isLocked)

            if isLocked {
                BiometricLockScreen(viewModel: viewModel)
            }
        }
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
    }
}

private struct BiometricLockScreen: View {
    @AppStorage("app.language") private var languageCode = AppLanguage.defaultExplicitLanguage.rawValue
    @ObservedObject var viewModel: BiometricLockViewModel

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .defaultExplicitLanguage
    }

    var body: some View {
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
        .hesiaScreenPadding()
        .padding(.vertical, AYASpacing.xxxl)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityAddTraits(.isModal)
    }

    private func unlock() async {
        let reason = language.localizedString(forKey: "biometric.authentication.reason")
        await viewModel.unlock(reason: reason, automatically: false)
    }
}
