import SwiftUI
import StoreKit

/// Circular entry point into the settings drawer, showing the user's initial.
struct AYAProfileButton: View {
    let initial: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AYAColors.emphasis)

                Text(initial)
                    .ayaTypography(.settingsRowTitle)
                    .bold()
                    .foregroundStyle(AYAColors.onAccent)
            }
            .frame(width: 44, height: 44)
            .overlay {
                Circle().stroke(AYAColors.onAccent.opacity(0.65), lineWidth: 1)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .frame(width: 44, height: 44)
        .accessibilityIdentifier("settings.button")
        .accessibilityLabel("settings.title")
    }
}

struct AYASettingsOverlay: View {
    @Binding var languageCode: String
    @Binding var userName: String
    let activeStage: LifeStage?
    let close: () -> Void
    let showThemes: () -> Void
    var editCycle: (() -> Void)? = nil
    var pregnancyWeek: Int? = nil
    var editPregnancy: (() -> Void)? = nil
    var editPostpartum: (() -> Void)? = nil
    var motherhoodRange: MotherhoodAgeRange? = nil
    var editMotherhood: (() -> Void)? = nil
    var presentation: SettingsPanelPresentation = .standard

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Tap-outside-to-dismiss. Modelled as a Button rather than a
                // bare tap gesture so VoiceOver announces and can activate it.
                Button(action: close) {
                    AYAColors.overlay
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.close")

                SettingsPanel(
                    languageCode: $languageCode,
                    userName: $userName,
                    activeStage: activeStage,
                    close: close,
                    showThemes: showThemes,
                    editCycle: editCycle,
                    pregnancyWeek: pregnancyWeek,
                    editPregnancy: editPregnancy,
                    editPostpartum: editPostpartum,
                    motherhoodRange: motherhoodRange,
                    editMotherhood: editMotherhood,
                    topSafeAreaInset: geometry.safeAreaInsets.top,
                    bottomSafeAreaInset: geometry.safeAreaInsets.bottom,
                    presentation: presentation
                )
                .frame(width: min(336, geometry.size.width * 0.88))
                .frame(maxHeight: .infinity)
                .transition(.move(edge: .trailing))
            }
        }
        .ignoresSafeArea()
        // Keeps VoiceOver inside the drawer instead of letting it wander onto
        // the Home screen still rendered behind the scrim.
        .accessibilityAddTraits(.isModal)
    }
}

enum SettingsPanelPresentation {
    case standard
    case tutorialPreview
}

struct SettingsPanel: View {
    @Binding var languageCode: String
    @Binding var userName: String
    let activeStage: LifeStage?
    let close: () -> Void
    let showThemes: () -> Void
    let editCycle: (() -> Void)?
    let pregnancyWeek: Int?
    let editPregnancy: (() -> Void)?
    let editPostpartum: (() -> Void)?
    let motherhoodRange: MotherhoodAgeRange?
    let editMotherhood: (() -> Void)?
    let topSafeAreaInset: CGFloat
    let bottomSafeAreaInset: CGFloat
    var presentation: SettingsPanelPresentation = .standard

    @State private var isLanguageExpanded = false
    @State private var isTutorialPresented = false
    @State private var isManageSubscriptionsPresented = false
    @ObservedObject private var premiumStore = PremiumStore.shared
    // `AppAppearance` is String-backed, so @AppStorage can bind the enum
    // directly — no hand-rolled Binding(get:set:) bridge needed. Same
    // underlying "app.appearance" key that HESIAApp reads.
    @AppStorage("app.appearance") private var appearance = AppAppearance.system
    @FocusState private var isNameFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: AYASpacing.xl) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: AYASpacing.xl) {
                    if presentation == .tutorialPreview {
                        tutorialPreviewSections
                    } else {
                        standardSections
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, AYASpacing.lg)
        .padding(.top, max(topSafeAreaInset + AYASpacing.lg, 72))
        .padding(.bottom, max(bottomSafeAreaInset + AYASpacing.lg, AYASpacing.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AYAColors.backgroundPrimary)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: AYARadius.hero,
                bottomLeadingRadius: AYARadius.hero
            )
        )
        .ayaElevation(.panel)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $isTutorialPresented) {
            HESIATutorialView(context: .replayFromSettings) {
                isTutorialPresented = false
            }
        }
        .manageSubscriptionsSheet(isPresented: $isManageSubscriptionsPresented)
        .task {
            await premiumStore.refreshEntitlements()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("settings.title")
                .ayaTypography(.screenTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: close) {
                HesiaIcon.close.view(size: HesiaIconSize.sm)
                    .foregroundStyle(AYAColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(AYAColors.surfaceElevated, in: Circle())
                    .overlay { Circle().stroke(AYAColors.separator, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.close.button")
            .accessibilityLabel("common.close")
        }
    }

    // MARK: - Section composition

    @ViewBuilder
    private var tutorialPreviewSections: some View {
        themesGroup
        profileSection
        if HESIAFeatureFlags.supportsMultipleLanguages {
            languageSection
        }
        supportSection
    }

    @ViewBuilder
    private var standardSections: some View {
        // Themes, the tutorial and the active-stage editor are all "go
        // somewhere" rows, so they share one group the way iOS Settings groups
        // its navigation rows — three separate cards with 24 pt gaps between
        // them read as three unrelated sections.
        SettingsGroup {
            SettingsNavigationRow(
                icon: SettingsRowIcon(.themes),
                titleKey: "settings.themes",
                action: showThemes
            )
            .accessibilityIdentifier("settings.themes.button")

            SettingsRowSeparator()

            SettingsNavigationRow(
                icon: SettingsRowIcon(.info),
                titleKey: "settings.how_hesia_works",
                action: { isTutorialPresented = true }
            )
            .accessibilityIdentifier("settings.how_hesia_works.button")

            stageRow
        }

        if premiumStore.hasPremiumAccess {
            premiumSection
        }

        profileSection

        if HESIAFeatureFlags.supportsMultipleLanguages {
            languageSection
        }

        appearanceSection
        BiometricLockSettings()
        OfflineMeditationSettings()
        MeditationReminderSettings(presentation: .settings)
        supportSection
    }

    private var themesGroup: some View {
        SettingsGroup {
            SettingsNavigationRow(
                icon: SettingsRowIcon(.themes),
                titleKey: "settings.themes",
                action: showThemes
            )
            .accessibilityIdentifier("settings.themes.button")
        }
    }

    // MARK: - Active-stage settings

    /// Editor for whichever life stage is currently active. Exactly one of
    /// these matches at a time; the rest of the drawer is stage-agnostic.
    @ViewBuilder
    private var stageRow: some View {
        if activeStage == .cycle, let editCycle {
            SettingsRowSeparator()
            SettingsNavigationRow(
                icon: SettingsRowIcon(.calendar),
                titleKey: "cycle.settings.title",
                value: SettingsRowValue("cycle.settings.edit"),
                action: editCycle
            )
            .accessibilityIdentifier("settings.cycle.button")
        }

        if activeStage == .pregnancy, let pregnancyWeek, let editPregnancy {
            SettingsRowSeparator()
            SettingsNavigationRow(
                icon: SettingsRowIcon(.calendar),
                titleKey: "pregnancy.settings.title",
                value: SettingsRowValue(verbatim: pregnancyWeekText(pregnancyWeek)),
                action: editPregnancy
            )
            .accessibilityIdentifier("settings.pregnancy.button")
        }

        if activeStage == .postpartum, let editPostpartum {
            SettingsRowSeparator()
            SettingsNavigationRow(
                icon: SettingsRowIcon(.calendar),
                titleKey: "settings.postpartum.update_birth_date",
                action: editPostpartum
            )
            .accessibilityIdentifier("settings.postpartum.button")
        }

        if activeStage == .motherhood03, let motherhoodRange, let editMotherhood {
            SettingsRowSeparator()
            SettingsNavigationRow(
                icon: SettingsRowIcon(symbol: "figure.and.child.holdinghands"),
                titleKey: "settings.motherhood.age_range",
                value: SettingsRowValue(
                    LocalizedStringKey(motherhoodRange.titleLocalizationKey)
                ),
                action: editMotherhood
            )
            .accessibilityIdentifier("settings.motherhood.button")
        }
    }

    // MARK: - Premium

    private var premiumSection: some View {
        SettingsGroup("settings.premium.section") {
            SettingsStatusRow(
                icon: SettingsRowIcon(.lock),
                titleKey: "settings.premium.title",
                value: SettingsRowValue(verbatim: premiumStatusText),
                accessory: .checkmark
            )

            if premiumStore.subscription != nil {
                SettingsRowSeparator()

                SettingsNavigationRow(
                    icon: SettingsRowIcon(.externalLink),
                    titleKey: "settings.premium.manage",
                    action: { isManageSubscriptionsPresented = true }
                )
                .accessibilityIdentifier("settings.premium.manage.button")
            }
        }
    }

    private var premiumStatusText: String {
        guard
            let subscription = premiumStore.subscription,
            let renewalDate = subscription.renewalDate
        else {
            return localizedString("settings.premium.subscription.active")
        }

        let language = AppLanguage(rawValue: languageCode) ?? .system
        let date = renewalDate.formatted(
            Date.FormatStyle(date: .long, time: .omitted).locale(language.locale)
        )
        let key = subscription.willAutoRenew == false
            ? "settings.premium.subscription.expires"
            : "settings.premium.subscription.renews"
        return String(
            format: language.localizedString(forKey: key),
            locale: language.locale,
            date
        )
    }

    // MARK: - Profile

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: AYASpacing.sm) {
            SettingsSectionLabel("settings.profile.section")

            VStack(alignment: .leading, spacing: AYASpacing.xs) {
                Text("settings.profile.name")
                    .ayaTypography(.settingsRowValue)
                    .foregroundStyle(AYAColors.textSecondary)

                TextField("welcome.name.placeholder", text: $userName)
                    .ayaTypography(.settingsRowTitle)
                    .foregroundStyle(AYAColors.textPrimary)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .focused($isNameFocused)
                    .onSubmit {
                        userName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
                        isNameFocused = false
                    }
                    .frame(minHeight: 32)
                    .accessibilityIdentifier("settings.name.field")
            }
            .padding(.horizontal, AYASpacing.lg)
            .padding(.vertical, AYASpacing.md)
            .frame(minHeight: SettingsRowMetrics.stackedMinHeight)
            .background(
                AYAColors.surfaceElevated,
                in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                    .stroke(AYAColors.separator, lineWidth: 1)
            }
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        SettingsGroup {
            SettingsNavigationRow(
                icon: SettingsRowIcon(.globe),
                titleKey: "settings.language",
                accessory: .disclosure(isExpanded: isLanguageExpanded),
                action: {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        isLanguageExpanded.toggle()
                    }
                }
            )
            .accessibilityIdentifier("settings.language.button")

            if isLanguageExpanded {
                SettingsRowSeparator()

                ForEach(AppLanguage.selectableCases) { language in
                    Button {
                        languageCode = language.rawValue
                    } label: {
                        HStack(spacing: AYASpacing.md) {
                            HesiaSelectionIndicator(
                                isSelected: languageCode == language.rawValue
                            )
                            Text(verbatim: language.nativeTitle)
                                .ayaTypography(.settingsRowValue)
                                .foregroundStyle(AYAColors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, AYASpacing.lg)
                        .frame(minHeight: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        languageCode == language.rawValue ? .isSelected : []
                    )
                    .accessibilityIdentifier("settings.language.\(language.rawValue)")
                }
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: AYASpacing.sm) {
            SettingsSectionLabel("settings.appearance.section")

            Picker("settings.appearance.section", selection: $appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.titleKey).tag(appearance)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.appearance.picker")
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        SettingsGroup("settings.support.section") {
            SettingsLinkRow(
                icon: SettingsRowIcon(.info),
                titleKey: "settings.support.help",
                url: SupportLink.help
            )
            SettingsRowSeparator()
            SettingsLinkRow(
                icon: SettingsRowIcon(.lock),
                titleKey: "settings.support.privacy",
                url: SupportLink.privacy
            )
            SettingsRowSeparator()
            SettingsLinkRow(
                icon: SettingsRowIcon(.document),
                titleKey: "settings.support.terms",
                url: SupportLink.terms
            )
        }
    }

    // MARK: - Helpers

    private func localizedString(_ key: String) -> String {
        let language = AppLanguage(rawValue: languageCode) ?? .system
        return language.localizedString(forKey: key)
    }

    private func pregnancyWeekText(_ week: Int) -> String {
        let language = AppLanguage(rawValue: languageCode) ?? .system
        return String(
            format: language.localizedString(forKey: "pregnancy.week.value"),
            locale: language.locale,
            week
        )
    }
}

/// Canonical HESIA legal / support destinations, so no view force-unwraps a
/// URL string inline.
enum SupportLink {
    static let help = URL(string: "https://hesia.app/hesia-legal-site/support.html")!
    static let privacy = URL(string: "https://hesia.app/hesia-legal-site/privacy.html")!
    static let terms = URL(string: "https://hesia.app/hesia-legal-site/terms.html")!
}
