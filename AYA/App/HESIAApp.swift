import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }

    static var selectableCases: [AppLanguage] {
        [.turkish, .english]
    }

    static var defaultExplicitLanguage: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("tr") == true ? .turkish : .english
    }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .turkish: Locale(identifier: "tr")
        case .english: Locale(identifier: "en")
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "settings.language.system"
        case .turkish: "settings.language.turkish"
        case .english: "settings.language.english"
        }
    }

    func localizedString(forKey key: String) -> String {
        localizationBundle.localizedString(forKey: key, value: key, table: nil)
    }

    var nativeTitle: String {
        switch self {
        case .turkish:
            AppLanguage.turkish.localizedString(forKey: "settings.language.turkish")
        case .english:
            AppLanguage.english.localizedString(forKey: "settings.language.english")
        case .system:
            AppLanguage.defaultExplicitLanguage.nativeTitle
        }
    }

    private var localizationBundle: Bundle {
        let localizationCode: String

        switch self {
        case .turkish:
            localizationCode = "tr"
        case .english:
            localizationCode = "en"
        case .system:
            localizationCode = Locale.preferredLanguages.first?.hasPrefix("tr") == true ? "tr" : "en"
        }

        guard
            let path = Bundle.main.path(forResource: localizationCode, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .main
        }

        return bundle
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "settings.appearance.system"
        case .light: "settings.appearance.light"
        case .dark: "settings.appearance.dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system: "iphone"
        case .light: "sun.max"
        case .dark: "moon.stars"
        }
    }
}

@main
struct HESIAApp: App {
    @UIApplicationDelegateAdaptor(HESIANotificationDelegate.self) private var notificationDelegate
    @StateObject private var premiumStore = PremiumStore.shared
    @AppStorage("app.language") private var languageCode = AppLanguage.defaultExplicitLanguage.rawValue
    @AppStorage("app.appearance") private var appearanceRawValue = AppAppearance.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    private var selectedLocale: Locale {
        AppLanguage(rawValue: languageCode)?.locale ?? .autoupdatingCurrent
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "app.language") == nil
            || defaults.string(forKey: "app.language") == AppLanguage.system.rawValue {
            defaults.set(AppLanguage.defaultExplicitLanguage.rawValue, forKey: "app.language")
        }
    }

    var body: some Scene {
        WindowGroup {
            HESIALaunchRootView()
                .environmentObject(premiumStore)
                .environment(\.locale, selectedLocale)
                .tint(AYAColors.primary)
                .preferredColorScheme(selectedAppearance.colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await premiumStore.refreshEntitlements(showLoadingState: true)
                    }
                }
        }
    }
}

private struct HESIALaunchRootView: View {
    @AppStorage(HESIAOnboardingPersistenceKeys.completed) private var hasCompletedOnboarding = false
    @AppStorage(HESIAOnboardingPersistenceKeys.welcomeCompleted) private var hasCompletedWelcome = false
    @AppStorage(HESIAOnboardingPersistenceKeys.tutorialCompleted) private var hasCompletedTutorial = false
    @AppStorage(HESIAOnboardingPersistenceKeys.offlineSetupCompleted) private var hasCompletedOfflineSetup = false
    @State private var authenticatedDuringOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let routeResolver = HESIAOnboardingRouteResolver()

    private var route: HESIAOnboardingRoute {
        routeResolver.route(
            hasCompletedOnboarding: hasCompletedOnboarding,
            hasCompletedWelcome: hasCompletedWelcome,
            hasCompletedTutorial: hasCompletedTutorial,
            hasCompletedOfflineSetup: hasCompletedOfflineSetup
        )
    }

    var body: some View {
        ZStack {
            switch route {
            case .app:
                BiometricLockContainer(initiallyUnlocked: authenticatedDuringOnboarding) {
                    AuthenticatedRootView()
                }
                .hesiaScreenTransition(reduceMotion: reduceMotion)

            case .biometric:
                BiometricOnboardingView { authenticated in
                    authenticatedDuringOnboarding = authenticated
                    hasCompletedOnboarding = true
                }
                .hesiaScreenTransition(reduceMotion: reduceMotion)

            case .offline:
                OfflineMeditationOnboardingView {
                    hasCompletedOfflineSetup = true
                }
                .hesiaScreenTransition(reduceMotion: reduceMotion)

            case .tutorial:
                HESIATutorialView(context: .firstLaunch) {
                    hasCompletedTutorial = true
                }
                .hesiaScreenTransition(reduceMotion: reduceMotion)

            case .welcome:
                WelcomeView {
                    hasCompletedWelcome = true
                }
                .hesiaScreenTransition(reduceMotion: reduceMotion)
            }
        }
        .hesiaScreenAnimation(
            reduceMotion: reduceMotion,
            value: route
        )
    }
}

private struct AuthenticatedRootView: View {
    @AppStorage(LifeStagePersistenceKeys.activeStage) private var activeStageRawValue = ""
    @State private var isChoosingTheme = false
    @EnvironmentObject private var premiumStore: PremiumStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var activeStage: LifeStage? {
        LifeStage(rawValue: activeStageRawValue)
    }

    private var showsThemeSelection: Bool {
        isChoosingTheme
            || PremiumAccessPolicy.requiresThemeSelection(
                for: activeStage,
                entitlementsResolved: premiumStore.hasResolvedEntitlements,
                hasPremiumAccess: premiumStore.hasPremiumAccess
            )
    }

    private var themeSelectionInitialStage: LifeStage {
        guard let activeStage else { return .cycle }
        return PremiumAccessPolicy.hasAccess(
            to: activeStage,
            entitlementsResolved: premiumStore.hasResolvedEntitlements,
            hasPremiumAccess: premiumStore.hasPremiumAccess
        ) ? activeStage : .cycle
    }

    private var routeAnimationValue: String {
        showsThemeSelection ? "themes" : activeStageRawValue
    }

    var body: some View {
        ZStack {
            if activeStage?.isPremium == true, !premiumStore.hasResolvedEntitlements {
                ProgressView()
                    .tint(AYAColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AYAColors.backgroundPrimary.ignoresSafeArea())
                    .accessibilityLabel("premium.loading")
                    .hesiaScreenTransition(reduceMotion: reduceMotion)
            } else if showsThemeSelection {
                LifeStageSelectionView(initialSelection: themeSelectionInitialStage) { stage in
                    activeStageRawValue = stage.rawValue
                    isChoosingTheme = false
                }
                .hesiaScreenTransition(reduceMotion: reduceMotion)
            } else if let activeStage {
                ActiveLifeStageView(stage: activeStage) {
                    isChoosingTheme = true
                }
                .hesiaScreenTransition(reduceMotion: reduceMotion)
            }
        }
        .hesiaScreenAnimation(
            reduceMotion: reduceMotion,
            value: routeAnimationValue
        )
    }
}

private struct ActiveLifeStageView: View {
    let stage: LifeStage
    let showThemes: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if stage == .cycle {
                    CycleDestinationView(showThemes: showThemes)
                } else if stage == .pregnancy {
                    PregnancyDestinationView(showThemes: showThemes)
                } else if stage == .postpartum {
                    PostpartumDestinationView(showThemes: showThemes)
                } else if stage == .motherhood03 {
                    MotherhoodDestinationView(showThemes: showThemes)
                } else {
                    LifeStagePlaceholderView(stage: stage, showThemesAction: showThemes)
                }
            }
            .hesiaRootEdgeBack(action: showThemes)
        }
    }
}
