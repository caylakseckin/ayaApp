import Combine
import Foundation
import StoreKit

enum PremiumProductIdentifiers {
    static let lifetime = "com.ayameditation.app.premium.lifetime"
    static let monthly = "com.ayameditation.app.premium.monthly"

    static let all: Set<String> = [lifetime, monthly]
}

enum PremiumPurchaseOutcome: Equatable {
    case purchased
    case pending
    case cancelled
    case unavailable
    case failed
}

enum PremiumRestoreOutcome: Equatable {
    case restored
    case nothingToRestore
    case failed
}

struct PremiumMonthlySubscription: Equatable {
    let renewalDate: Date?
    let willAutoRenew: Bool?
}

enum PremiumAccessPolicy {
    static func hasAccess(
        to stage: LifeStage,
        entitlementsResolved: Bool,
        hasPremiumAccess: Bool
    ) -> Bool {
        !stage.isPremium || (entitlementsResolved && hasPremiumAccess)
    }

    static func requiresThemeSelection(
        for activeStage: LifeStage?,
        entitlementsResolved: Bool,
        hasPremiumAccess: Bool
    ) -> Bool {
        guard let activeStage else { return true }
        guard activeStage.isPremium else { return false }
        return entitlementsResolved && !hasPremiumAccess
    }
}

@MainActor
final class PremiumStore: ObservableObject {
    static let shared = PremiumStore()

    @Published private(set) var products: [PremiumPlan: Product] = [:]
    @Published private(set) var hasPremiumAccess = false
    @Published private(set) var hasLifetimeAccess = false
    @Published private(set) var monthlySubscription: PremiumMonthlySubscription?
    @Published private(set) var hasResolvedEntitlements = false
    @Published private(set) var hasLoadedProducts = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false

    private var transactionUpdatesTask: Task<Void, Never>?
    private var entitlementExpirationTask: Task<Void, Never>?

    private init() {
        transactionUpdatesTask = listenForTransactionUpdates()

        Task {
            await prepare()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
        entitlementExpirationTask?.cancel()
    }

    func product(for plan: PremiumPlan) -> Product? {
        products[plan]
    }

    func prepare() async {
        async let productsTask: Void = loadProducts()
        async let entitlementsTask: Void = refreshEntitlements()
        _ = await (productsTask, entitlementsTask)
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer {
            isLoadingProducts = false
            hasLoadedProducts = true
        }

        do {
            let fetchedProducts = try await Product.products(for: PremiumProductIdentifiers.all)
            products = Dictionary(
                uniqueKeysWithValues: fetchedProducts.compactMap { product in
                    guard let plan = PremiumPlan(productIdentifier: product.id) else { return nil }
                    return (plan, product)
                }
            )
        } catch {
            products = [:]
            log("Unable to load products: \(error)")
        }
    }

    func refreshEntitlements(showLoadingState: Bool = false) async {
        if showLoadingState {
            hasResolvedEntitlements = false
        }

        var entitledProductIDs = Set<String>()
        var monthlyTransaction: StoreKit.Transaction?

        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try verified(result)
                guard transaction.revocationDate == nil else { continue }
                if PremiumProductIdentifiers.all.contains(transaction.productID) {
                    entitledProductIDs.insert(transaction.productID)
                    if transaction.productID == PremiumProductIdentifiers.monthly {
                        monthlyTransaction = transaction
                    }
                }
            } catch {
                log("Ignoring an unverified entitlement: \(error)")
            }
        }

        hasLifetimeAccess = entitledProductIDs.contains(PremiumProductIdentifiers.lifetime)
        monthlySubscription = await subscriptionDetails(for: monthlyTransaction)
        hasPremiumAccess = !entitledProductIDs.isEmpty
        hasResolvedEntitlements = true
        scheduleEntitlementRefresh(at: monthlySubscription?.renewalDate)
    }

    func purchase(_ plan: PremiumPlan) async -> PremiumPurchaseOutcome {
        if products[plan] == nil {
            await loadProducts()
        }

        guard let product = products[plan] else {
            return .unavailable
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            switch try await product.purchase() {
            case .success(let result):
                let transaction = try verified(result)
                guard PremiumProductIdentifiers.all.contains(transaction.productID) else {
                    return .failed
                }
                await transaction.finish()
                await refreshEntitlements()
                return hasPremiumAccess ? .purchased : .failed

            case .pending:
                return .pending

            case .userCancelled:
                return .cancelled

            @unknown default:
                return .failed
            }
        } catch {
            log("Purchase failed for \(plan.productIdentifier): \(error)")
            return .failed
        }
    }

    func restorePurchases() async -> PremiumRestoreOutcome {
        guard !isRestoring else { return .failed }
        isRestoring = true
        defer { isRestoring = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return hasPremiumAccess ? .restored : .nothingToRestore
        } catch {
            log("Restore purchases failed: \(error)")
            return .failed
        }
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }

                do {
                    let transaction = try self.verified(result)
                    guard PremiumProductIdentifiers.all.contains(transaction.productID) else { continue }
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    self.log("Ignoring an unverified transaction update: \(error)")
                }
            }
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }

    private func subscriptionDetails(
        for transaction: StoreKit.Transaction?
    ) async -> PremiumMonthlySubscription? {
        guard let transaction else { return nil }

        var renewalDate = transaction.expirationDate
        var willAutoRenew: Bool?

        if
            let status = await transaction.subscriptionStatus,
            case .verified(let renewalInfo) = status.renewalInfo
        {
            renewalDate = renewalInfo.renewalDate ?? renewalDate
            willAutoRenew = renewalInfo.willAutoRenew
        }

        return PremiumMonthlySubscription(
            renewalDate: renewalDate,
            willAutoRenew: willAutoRenew
        )
    }

    private func scheduleEntitlementRefresh(at date: Date?) {
        entitlementExpirationTask?.cancel()
        entitlementExpirationTask = nil

        guard let date, date > Date() else { return }

        let delay = date.timeIntervalSinceNow + 2
        entitlementExpirationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }

            guard let self else { return }
            await self.refreshEntitlements()
        }
    }

    private func log(_ message: String) {
#if DEBUG
        print("[PremiumStore] \(message)")
#endif
    }
}
