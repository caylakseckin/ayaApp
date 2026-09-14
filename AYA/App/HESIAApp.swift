import SwiftUI

enum HESIAFeatureFlags {
    /// Keep English resources and code paths complete while the first release is Turkish-only.
    /// Set to `true` to restore language selection throughout the app.
    static let supportsMultipleLanguages = false
    /// Keep the completed Motherhood experience available in code while it is hidden at launch.
    static let supportsMotherhood = false
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }

    static var selectableCases: [AppLanguage] {
        HESIAFeatureFlags.supportsMultipleLanguages
            ? [.turkish, .english]
            : [.turkish]
    }

    static var defaultExplicitLanguage: AppLanguage {
        guard HESIAFeatureFlags.supportsMultipleLanguages else { return .turkish }
        return Locale.preferredLanguages.first?.hasPrefix("tr") == true ? .turkish : .english
    }

    static func resolved(from rawValue: String?) -> AppLanguage {
        guard HESIAFeatureFlags.supportsMultipleLanguages else { return .turkish }
        guard let language = rawValue.flatMap(AppLanguage.init(rawValue:)) else {
            return defaultExplicitLanguage
        }
        return language == .system ? defaultExplicitLanguage : language
    }

    var locale: Locale {
        switch self {
        case .system: AppLanguage.defaultExplicitLanguage.locale
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
            localizationCode = AppLanguage.defaultExplicitLanguage.rawValue
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
    @AppStorage(LifeStagePersistenceKeys.activeStage) private var activeStageRawValue = ""
    @Environment(\.scenePhase) private var scenePhase

    private var selectedLocale: Locale {
        AppLanguage.resolved(from: languageCode).locale
    }

    private var selectedAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRawValue) ?? .system
    }

    init() {
        WatchCompanionSync.shared.activate()
        let defaults = UserDefaults.standard
        if !HESIAFeatureFlags.supportsMultipleLanguages {
            defaults.set(AppLanguage.turkish.rawValue, forKey: "app.language")
        } else if defaults.string(forKey: "app.language") == nil
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
                .task {
                    await synchronizeWatchPractice()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    premiumStore.enforceExpiration()
                    Task {
                        await premiumStore.refreshEntitlements()
                        await synchronizeWatchPractice()
                    }
                }
                .onChange(of: activeStageRawValue) { _, _ in
                    Task {
                        await synchronizeWatchPractice()
                    }
                }
                .onChange(of: premiumStore.hasPremiumAccess) { _, allowed in
                    if !allowed { WatchCompanionSync.shared.invalidatePremiumAccess() }
                }
        }
    }

    @MainActor
    private func synchronizeWatchPractice() async {
        await WatchCompanionSync.shared.synchronizeCurrentPracticeIfEntitled()
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
            AYAColors.backgroundPrimary.ignoresSafeArea()

            Group {
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
            .frame(maxWidth: AYALayout.readableContentMaxWidth, maxHeight: .infinity)
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
    @StateObject private var watchPlaybackCoordinator = WatchPlaybackCoordinator.shared
    @EnvironmentObject private var premiumStore: PremiumStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var activeStage: LifeStage? {
        guard let stage = LifeStage(rawValue: activeStageRawValue), stage.isAvailable else {
            return nil
        }
        return stage
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
        .fullScreenCover(isPresented: $watchPlaybackCoordinator.isPlayerPresented) {
            if let playbackSession = watchPlaybackCoordinator.playbackSession {
                HESIAMeditationTransitionContainer {
                    MeditationPlayerView(
                        meditation: playbackSession.meditation,
                        playbackViewModel: playbackSession.viewModel,
                        stopsPlaybackOnDismiss: false
                    )
                    .tint(AYAColors.primary)
                }
            }
        }
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
                } else if stage == .birthMoment {
                    BirthMomentDestinationView(showThemes: showThemes)
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
