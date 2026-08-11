import SwiftUI

enum PremiumPlan: String, CaseIterable, Identifiable {
    case lifetime
    case monthly

    var id: String { rawValue }

    var productIdentifier: String {
        switch self {
        case .lifetime: PremiumProductIdentifiers.lifetime
        case .monthly: PremiumProductIdentifiers.monthly
        }
    }

    init?(productIdentifier: String) {
        switch productIdentifier {
        case PremiumProductIdentifiers.lifetime:
            self = .lifetime
        case PremiumProductIdentifiers.monthly:
            self = .monthly
        default:
            return nil
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .lifetime: "premium.plan.lifetime.title"
        case .monthly: "premium.plan.monthly.title"
        }
    }

    var fallbackPriceKey: LocalizedStringKey {
        switch self {
        case .lifetime: "premium.plan.lifetime.price"
        case .monthly: "premium.plan.monthly.price"
        }
    }

    var detailKey: LocalizedStringKey {
        switch self {
        case .lifetime: "premium.plan.lifetime.detail"
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
    @State private var selectedPlan: PremiumPlan = .lifetime
    @State private var activeAlert: PremiumPaywallAlert?
    @State private var didGrantAccess = false
    @Environment(\.dismiss) private var dismiss

    private let termsURL = URL(string: "https://hesia.app/hesia-legal-site/terms.html")!
    private let privacyURL = URL(string: "https://hesia.app/hesia-legal-site/privacy.html")!

    private var isWorking: Bool {
        premiumStore.isPurchasing || premiumStore.isRestoring
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                benefits
                plans

                if premiumStore.hasLoadedProducts, premiumStore.products.isEmpty {
                    productUnavailableNotice
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 168)
        }
        .scrollIndicators(.hidden)
        .background(AYAColors.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
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

    private var header: some View {
        VStack(spacing: 13) {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    HesiaIcon.close.view(size: 14)
                        .foregroundStyle(AYAColors.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(AYAColors.surface, in: Circle())
                        .overlay { Circle().stroke(AYAColors.border, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.close")
            }

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
        VStack(alignment: .leading, spacing: 13) {
            benefit("premium.benefit.all_stages")
            benefit("premium.benefit.daily_meditation")
            benefit("premium.benefit.switch_anytime")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AYAColors.surface, in: RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AYARadius.card, style: .continuous)
                .stroke(AYAColors.border, lineWidth: 1)
        }
    }

    private func benefit(_ key: LocalizedStringKey) -> some View {
        HStack(spacing: 11) {
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
        VStack(spacing: 12) {
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
            HStack(spacing: 14) {
                HesiaSelectionIndicator(isSelected: isSelected)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(plan.titleKey)
                            .ayaTypography(.sectionTitle)
                            .foregroundStyle(AYAColors.textPrimary)

                        if plan == .lifetime {
                            Text("premium.plan.best_value")
                                .font(AYATypography.ui(size: 10, weight: .semibold))
                                .foregroundStyle(AYAColors.emphasis)
                                .padding(.horizontal, 8)
                                .frame(minHeight: 23)
                                .background(AYAColors.tertiary.opacity(0.72), in: Capsule())
                        }
                    }

                    Text(plan.detailKey)
                        .ayaTypography(.metadata)
                        .foregroundStyle(AYAColors.textSecondary)
                }

                Spacer(minLength: 10)

                price(for: plan)
                    .font(AYATypography.ui(size: 17, weight: .semibold))
                    .foregroundStyle(AYAColors.emphasis)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(isSelected ? AYAColors.accentSoft : AYAColors.surface, in: RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AYARadius.control, style: .continuous)
                    .stroke(isSelected ? AYAColors.accent : AYAColors.border, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func price(for plan: PremiumPlan) -> some View {
        if let product = premiumStore.product(for: plan) {
            Text(product.displayPrice)
        } else {
            Text(plan.fallbackPriceKey)
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
            .foregroundStyle(AYAColors.accent)
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
                    Text("premium.purchase")
                }
            }
            .buttonStyle(.appPrimary)
            .disabled(isWorking || premiumStore.isLoadingProducts)
            .accessibilityIdentifier("premium.purchase.button")

            if selectedPlan == .monthly {
                Text("premium.subscription.disclosure")
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
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(AYAColors.backgroundPrimary.opacity(0.98))
    }

    private var legalLinks: some View {
        HStack(spacing: AYASpacing.sm) {
            Button("premium.restore") {
                Task { await restorePurchases() }
            }
            .disabled(isWorking)

            Text(verbatim: "•")
                .accessibilityHidden(true)

            Link("premium.terms", destination: termsURL)

            Text(verbatim: "•")
                .accessibilityHidden(true)

            Link("premium.privacy", destination: privacyURL)
        }
        .buttonStyle(.plain)
        .ayaTypography(.metadata)
        .foregroundStyle(AYAColors.textTertiary)
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
