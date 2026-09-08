import Combine
import Foundation
import StoreKit

enum PremiumProductIdentifiers {
    static let monthly = "com.hesia.meditation.premium.monthly"
    static let yearly = "com.hesia.meditation.premium.yearly"

    static let all: Set<String> = [monthly, yearly]
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

struct PremiumSubscription: Equatable {
    let productID: String
    let renewalDate: Date?
    let willAutoRenew: Bool?
}

struct PremiumEntitlementRecord: Equatable {
    let productID: String
    let revocationDate: Date?
    let expirationDate: Date?
}

enum PremiumAccessPolicy {
    static func isActiveEntitlement(
        productID: String,
        revocationDate: Date?,
        expirationDate: Date?,
        now: Date = Date()
    ) -> Bool {
        guard PremiumProductIdentifiers.all.contains(productID) else { return false }
        guard revocationDate == nil else { return false }
        return expirationDate.map { $0 > now } ?? true
    }

    static func effectiveProductIDs(
        storeProductIDs: Set<String>,
        sessionEntitlements: [PremiumEntitlementRecord],
        now: Date = Date()
    ) -> Set<String> {
        let activeSessionProductIDs = sessionEntitlements.compactMap { entitlement in
            isActiveEntitlement(
                productID: entitlement.productID,
                revocationDate: entitlement.revocationDate,
                expirationDate: entitlement.expirationDate,
                now: now
            ) ? entitlement.productID : nil
        }
        return storeProductIDs.union(activeSessionProductIDs)
    }

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
    @Published private(set) var eligibleIntroductoryOfferPlans = Set<PremiumPlan>()
    @Published private(set) var hasPremiumAccess = false
    @Published private(set) var subscription: PremiumSubscription?
    @Published private(set) var hasResolvedEntitlements = false
    @Published private(set) var hasLoadedProducts = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false

    private var transactionUpdatesTask: Task<Void, Never>?
    private var entitlementExpirationTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var entitlementStateRevision = 0
    private var sessionEntitlements: [String: PremiumEntitlementRecord] = [:]

    /// UI-test override. The suite has always passed
    /// `-premium.isUnlockedForTesting YES`, but nothing read it — so whether a
    /// premium stage opened its Home screen or the paywall depended on leftover
    /// StoreKit state in the simulator, which made the tests flaky. DEBUG-only
    /// so it cannot affect a shipping build.
    static var isUnlockedForTesting: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "premium.isUnlockedForTesting")
        #else
        false
        #endif
    }

    private init() {
        transactionUpdatesTask = listenForTransactionUpdates()

        if Self.isUnlockedForTesting {
            hasPremiumAccess = true
            hasResolvedEntitlements = true
        }

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
        if let preparationTask {
            await preparationTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            async let productsTask: Void = self.loadProducts()
            async let entitlementsTask: Void = self.refreshEntitlements()
            _ = await (productsTask, entitlementsTask)
        }
        preparationTask = task
        await task.value
        preparationTask = nil
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
            eligibleIntroductoryOfferPlans = await eligibleIntroductoryOffers(in: products)
        } catch {
            products = [:]
            eligibleIntroductoryOfferPlans = []
            log("Unable to load products: \(error)")
        }
    }

    func refreshEntitlements(showLoadingState: Bool = false) async {
        let revisionAtStart = entitlementStateRevision
        let sessionEntitlementsAtStart = Array(sessionEntitlements.values)

        if showLoadingState {
            hasResolvedEntitlements = false
        }

        var entitledProductIDs = Set<String>()
        var subscriptionTransaction: StoreKit.Transaction?

        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try verified(result)
                if PremiumAccessPolicy.isActiveEntitlement(
                    productID: transaction.productID,
                    revocationDate: transaction.revocationDate,
                    expirationDate: transaction.expirationDate
                ) {
                    entitledProductIDs.insert(transaction.productID)
                    if PremiumProductIdentifiers.all.contains(transaction.productID) {
                        if let current = subscriptionTransaction {
                            let currentExpiration = current.expirationDate ?? .distantPast
                            let candidateExpiration = transaction.expirationDate ?? .distantPast
                            if candidateExpiration > currentExpiration {
                                subscriptionTransaction = transaction
                            }
                        } else {
                            subscriptionTransaction = transaction
                        }
                    }
                }
            } catch {
                log("Ignoring an unverified entitlement: \(error)")
            }
        }

        let effectiveProductIDs = PremiumAccessPolicy.effectiveProductIDs(
            storeProductIDs: entitledProductIDs,
            sessionEntitlements: sessionEntitlementsAtStart
        )
        let hasSessionSubscriptionAccess = !effectiveProductIDs.intersection(PremiumProductIdentifiers.all).isEmpty
            && subscriptionTransaction == nil
        let resolvedSubscription = if hasSessionSubscriptionAccess {
            subscription
        } else {
            await subscriptionDetails(for: subscriptionTransaction)
        }
        guard revisionAtStart == entitlementStateRevision else { return }

        sessionEntitlements = Dictionary(
            uniqueKeysWithValues: sessionEntitlementsAtStart.compactMap { entitlement in
                PremiumAccessPolicy.isActiveEntitlement(
                    productID: entitlement.productID,
                    revocationDate: entitlement.revocationDate,
                    expirationDate: entitlement.expirationDate
                ) ? (entitlement.productID, entitlement) : nil
            }
        )
        subscription = resolvedSubscription
        hasPremiumAccess = Self.isUnlockedForTesting || !effectiveProductIDs.isEmpty
        hasResolvedEntitlements = true
        scheduleEntitlementRefresh(at: subscription?.renewalDate)
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
                let grantsAccess = await grantPremiumAccess(for: transaction)
                await transaction.finish()
                return grantsAccess ? .purchased : .failed

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
                    let grantsAccess = await self.grantPremiumAccess(for: transaction)
                    await transaction.finish()
                    if !grantsAccess {
                        await self.refreshEntitlements()
                    }
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

    private func grantPremiumAccess(for transaction: StoreKit.Transaction) async -> Bool {
        let entitlement = PremiumEntitlementRecord(
            productID: transaction.productID,
            revocationDate: transaction.revocationDate,
            expirationDate: transaction.expirationDate
        )
        guard PremiumAccessPolicy.isActiveEntitlement(
            productID: entitlement.productID,
            revocationDate: entitlement.revocationDate,
            expirationDate: entitlement.expirationDate
        ) else {
            sessionEntitlements.removeValue(forKey: transaction.productID)
            entitlementStateRevision += 1
            return false
        }

        // Invalidate entitlement reads that began before this verified purchase.
        entitlementStateRevision += 1
        sessionEntitlements[transaction.productID] = entitlement

        let resolvedSubscription: PremiumSubscription?
        if PremiumProductIdentifiers.all.contains(transaction.productID) {
            resolvedSubscription = await subscriptionDetails(for: transaction)
        } else {
            resolvedSubscription = nil
        }

        // Also invalidate any refresh that began while subscription details loaded.
        entitlementStateRevision += 1
        hasPremiumAccess = true
        hasResolvedEntitlements = true

        if PremiumProductIdentifiers.all.contains(transaction.productID) {
            subscription = resolvedSubscription
            scheduleEntitlementRefresh(at: subscription?.renewalDate)
        }

        return true
    }

    private func subscriptionDetails(
        for transaction: StoreKit.Transaction?
    ) async -> PremiumSubscription? {
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

        return PremiumSubscription(
            productID: transaction.productID,
            renewalDate: renewalDate,
            willAutoRenew: willAutoRenew
        )
    }

    private func eligibleIntroductoryOffers(
        in products: [PremiumPlan: Product]
    ) async -> Set<PremiumPlan> {
        var eligiblePlans = Set<PremiumPlan>()

        for (plan, product) in products {
            guard
                let subscription = product.subscription,
                let offer = subscription.introductoryOffer,
                offer.paymentMode == .freeTrial,
                offer.period.unit == .week,
                offer.period.value == 2,
                await subscription.isEligibleForIntroOffer
            else { continue }

            eligiblePlans.insert(plan)
        }

        return eligiblePlans
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
