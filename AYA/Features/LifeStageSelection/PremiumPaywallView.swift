import SwiftUI

enum PremiumPlan: String, CaseIterable, Identifiable {
    case yearly
    case monthly

    var id: String { rawValue }

    var productIdentifier: String {
        switch self {
        case .yearly: PremiumProductIdentifiers.yearly
        case .monthly: PremiumProductIdentifiers.monthly
        }
    }

    init?(productIdentifier: String) {
        switch productIdentifier {
        case PremiumProductIdentifiers.yearly:
            self = .yearly
        case PremiumProductIdentifiers.monthly:
            self = .monthly
        default:
            return nil
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .yearly: "premium.plan.yearly.title"
        case .monthly: "premium.plan.monthly.title"
        }
    }

    var detailKey: LocalizedStringKey {
        switch self {
        case .yearly: "premium.plan.yearly.detail"
        case .monthly: "premium.plan.monthly.detail"
        }
    }
}

private enum PremiumPaywallAlert: String, Identifiable {
    case pending
    case purchaseFailed
    case restoreFailed
    case nothingToRestore

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .pending: "premium.alert.pending.title"
        case .purchaseFailed: "premium.alert.purchase_failed.title"
        case .restoreFailed: "premium.alert.restore_failed.title"
        case .nothingToRestore: "premium.alert.nothing_to_restore.title"
        }
    }

    var messageKey: LocalizedStringKey {
        switch self {
        case .pending: "premium.alert.pending.message"
        case .purchaseFailed: "premium.alert.purchase_failed.message"
        case .restoreFailed: "premium.alert.restore_failed.message"
        case .nothingToRestore: "premium.alert.nothing_to_restore.message"
        }
    }
}

struct PremiumPaywallView: View {
    let stage: LifeStage
    let onAccessGranted: () -> Void

    @ObservedObject private var premiumStore = PremiumStore.shared
    @State private var selectedPlan: PremiumPlan = .monthly
    @State private var activeAlert: PremiumPaywallAlert?
    @State private var didGrantAccess = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app.language") private var languageCode = AppLanguage.system.rawValue

    private let termsURL = URL(string: "https://hesia.app/hesia-legal-site/terms.html")!
    private let privacyURL = URL(string: "https://hesia.app/hesia-legal-site/privacy.html")!

    private var isWorking: Bool {
        premiumStore.isPurchasing || premiumStore.isRestoring
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AYASpacing.xl) {
                header
                benefits
                plans

                if premiumStore.hasLoadedProducts,
                   premiumStore.products.count < PremiumPlan.allCases.count {
                    productUnavailableNotice
                }
            }
            .hesiaScreenPadding()
            .padding(.top, AYASpacing.sm)
            .padding(.bottom, AYALayout.screenBottomPadding)
        }
        .scrollIndicators(.hidden)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        // Pinned rather than scrolling with the content: a close control that
        // disappears on a paywall reads as a dark pattern even when it isn't.
        .safeAreaInset(edge: .top, spacing: 0) {
            closeBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            purchaseArea
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .task {
            await premiumStore.prepare()
            grantAccessIfNeeded()
        }
        .onChange(of: premiumStore.hasPremiumAccess) { _, _ in
            grantAccessIfNeeded()
        }
        .alert(item: $activeAlert) { alert in
            Alert(
                title: Text(alert.titleKey),
                message: Text(alert.messageKey),
                dismissButton: .default(Text("premium.alert.ok"))
            )
        }
    }

    private var closeBar: some View {
        HStack {
            Spacer()
            Button(action: { dismiss() }) {
                HesiaIcon.close.view(size: HesiaIconSize.sm)
                    .foregroundStyle(AYAColors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(AYAColors.surfaceElevated, in: Circle())
                    .overlay { Circle().stroke(AYAColors.separator, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("common.close")
        }
        .hesiaScreenPadding()
        .padding(.vertical, AYASpacing.sm)
    }

    private var header: some View {
        VStack(spacing: AYASpacing.md) {
            Text("premium.title")
                .ayaTypography(.screenTitle)
                .foregroundStyle(AYAColors.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("premium.subtitle")
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: AYASpacing.md) {
            benefit("premium.benefit.all_stages")
            benefit("premium.benefit.daily_meditation")
            benefit("premium.benefit.switch_anytime")
        }
        .padding(AYASpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AYAColors.surfaceElevated, in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(AYAColors.border, lineWidth: 1)
        }
    }

    private func benefit(_ key: LocalizedStringKey) -> some View {
        HStack(spacing: AYASpacing.md) {
            HesiaSelectionIndicator(
                isSelected: true,
                selectedFill: AYAColors.accentSoft,
                selectedForeground: AYAColors.accent
            )
            Text(key)
                .ayaTypography(.body)
                .foregroundStyle(AYAColors.textPrimary)
        }
    }

    private var plans: some View {
        VStack(spacing: AYASpacing.md) {
            ForEach(PremiumPlan.allCases) { plan in
                planButton(plan)
            }
        }
    }

    private func planButton(_ plan: PremiumPlan) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            selectedPlan = plan
        } label: {
            HStack(spacing: AYASpacing.md) {
                HesiaSelectionIndicator(isSelected: isSelected)

                VStack(alignment: .leading, spacing: AYASpacing.xs) {
                    HStack(spacing: AYASpacing.sm) {
                        Text(plan.titleKey)
                            .ayaTypography(.sectionTitle)
                            .foregroundStyle(AYAColors.textPrimary)

                        if plan == .yearly {
                            // `.soft` rather than the warm `tertiary` fill: in
                            // dark mode tertiary resolves to a muddy brown and
                            // the plum label loses contrast against it.
                            HesiaBadge("premium.plan.best_value")
                        }
                    }

                    Text(detailKey(for: plan))
                        .ayaTypography(.metadata)
                        .foregroundStyle(AYAColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AYASpacing.sm)

                price(for: plan)
                    .ayaTypography(.price)
                    .foregroundStyle(AYAColors.emphasis)
            }
            .padding(.horizontal, AYASpacing.lg)
            .padding(.vertical, AYASpacing.md)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(isSelected ? AYAColors.accentSoft : AYAColors.surface, in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                    .stroke(isSelected ? AYAColors.accent : AYAColors.border, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(
            isWorking
                || (premiumStore.hasLoadedProducts && premiumStore.product(for: plan) == nil)
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func price(for plan: PremiumPlan) -> some View {
        if let product = premiumStore.product(for: plan) {
            Text(product.displayPrice)
        } else if premiumStore.isLoadingProducts || !premiumStore.hasLoadedProducts {
            ProgressView()
                .tint(AYAColors.accent)
                .accessibilityLabel("premium.loading")
        } else {
            Text("premium.plan.price_unavailable")
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textTertiary)
        }
    }

    private var productUnavailableNotice: some View {
        VStack(spacing: AYASpacing.sm) {
            Text("premium.product_unavailable")
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("premium.retry") {
                Task { await premiumStore.loadProducts() }
            }
            .ayaTypography(.button)
            .foregroundStyle(AYAColors.emphasis)
            .frame(minHeight: 44)
        }
    }

    private var purchaseArea: some View {
        VStack(spacing: AYASpacing.sm) {
            Button {
                Task { await purchaseSelectedPlan() }
            } label: {
                if premiumStore.isPurchasing {
                    ProgressView()
                        .tint(AYAColors.onAccent)
                        .accessibilityLabel("premium.loading")
                } else {
                    Text(purchaseButtonKey)
                }
            }
            .buttonStyle(.appPrimary)
            .disabled(
                isWorking
                    || premiumStore.isLoadingProducts
                    || premiumStore.product(for: selectedPlan) == nil
            )
            .accessibilityIdentifier("premium.purchase.button")

            if let subscriptionDisclosure {
                Text(verbatim: subscriptionDisclosure)
                    .ayaTypography(.metadata)
                    .foregroundStyle(AYAColors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            legalLinks

            Text("premium.payment_note")
                .ayaTypography(.metadata)
                .foregroundStyle(AYAColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .hesiaBottomBar()
    }

    private var legalLinks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AYASpacing.sm) {
                legalActions(includeSeparators: true)
            }

            VStack(spacing: 0) {
                legalActions(includeSeparators: false)
            }
        }
        .buttonStyle(.plain)
        .ayaTypography(.metadata)
        .foregroundStyle(AYAColors.textTertiary)
    }

    @ViewBuilder
    private func legalActions(includeSeparators: Bool) -> some View {
        Button("premium.restore") {
            Task { await restorePurchases() }
        }
        .disabled(isWorking)
        .frame(minHeight: 44)
        .contentShape(Rectangle())

        if includeSeparators {
            Text(verbatim: "•")
                .accessibilityHidden(true)
        }

        Link("premium.terms", destination: termsURL)
            .frame(minHeight: 44)
            .contentShape(Rectangle())

        if includeSeparators {
            Text(verbatim: "•")
                .accessibilityHidden(true)
        }

        Link("premium.privacy", destination: privacyURL)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    private func detailKey(for plan: PremiumPlan) -> LocalizedStringKey {
        if plan == .monthly,
           premiumStore.eligibleIntroductoryOfferPlans.contains(.monthly) {
            return "premium.plan.monthly.trial_detail"
        }
        return plan.detailKey
    }

    private var purchaseButtonKey: LocalizedStringKey {
        if selectedPlan == .monthly,
           premiumStore.eligibleIntroductoryOfferPlans.contains(.monthly) {
            return "premium.purchase.start_trial"
        }
        return "premium.purchase"
    }

    private var subscriptionDisclosure: String? {
        guard let product = premiumStore.product(for: selectedPlan) else { return nil }

        let key: String
        if selectedPlan == .monthly,
           premiumStore.eligibleIntroductoryOfferPlans.contains(.monthly) {
            key = "premium.subscription.monthly_trial_disclosure"
        } else {
            key = switch selectedPlan {
            case .monthly: "premium.subscription.monthly_disclosure"
            case .yearly: "premium.subscription.yearly_disclosure"
            }
        }

        let language = AppLanguage.resolved(from: languageCode)
        let format = language.localizedString(forKey: key)
        return String(format: format, locale: language.locale, product.displayPrice)
    }

    private func purchaseSelectedPlan() async {
        switch await premiumStore.purchase(selectedPlan) {
        case .purchased:
            grantAccessIfNeeded()
        case .pending:
            activeAlert = .pending
        case .cancelled:
            break
        case .unavailable, .failed:
            activeAlert = .purchaseFailed
        }
    }

    private func restorePurchases() async {
        switch await premiumStore.restorePurchases() {
        case .restored:
            grantAccessIfNeeded()
        case .nothingToRestore:
            activeAlert = .nothingToRestore
        case .failed:
            activeAlert = .restoreFailed
        }
    }

    private func grantAccessIfNeeded() {
        guard premiumStore.hasPremiumAccess, !didGrantAccess else { return }
        didGrantAccess = true
        onAccessGranted()
    }
}

#Preview("Premium Paywall — Türkçe") {
    PremiumPaywallView(stage: .pregnancy, onAccessGranted: {})
        .environment(\.locale, Locale(identifier: "tr"))
}

#Preview("Premium Paywall — English") {
    PremiumPaywallView(stage: .motherhood03, onAccessGranted: {})
        .environment(\.locale, Locale(identifier: "en"))
}
