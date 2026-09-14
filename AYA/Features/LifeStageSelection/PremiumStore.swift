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
    private let allowsTestUnlock: Bool

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

    init(automaticallyStarts: Bool = true, allowsTestUnlock: Bool = true) {
        self.allowsTestUnlock = allowsTestUnlock
        guard automaticallyStarts else { return }
        transactionUpdatesTask = listenForTransactionUpdates()

        if allowsTestUnlock && Self.isUnlockedForTesting {
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

    /// Also used synchronously before playback and on foreground entry.
    var canUsePremiumNow: Bool {
        (allowsTestUnlock && Self.isUnlockedForTesting) ||
            sessionEntitlements.values.contains {
                PremiumAccessPolicy.isActiveEntitlement(
                    productID: $0.productID, revocationDate: $0.revocationDate,
                    expirationDate: $0.expirationDate
                )
            }
    }

    func enforceExpiration() {
        let allowed = canUsePremiumNow
        if hasPremiumAccess != allowed { hasPremiumAccess = allowed }
    }

    func refreshEntitlements(showLoadingState: Bool = false) async {
        enforceExpiration()
        entitlementStateRevision += 1
        let revision = entitlementStateRevision
        if showLoadingState { hasResolvedEntitlements = false }

        var records: [String: PremiumEntitlementRecord] = [:]
        var latestTransaction: StoreKit.Transaction?
        for await result in StoreKit.Transaction.currentEntitlements {
            guard let transaction = try? verified(result),
                  PremiumProductIdentifiers.all.contains(transaction.productID),
                  transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
            var expiration = transaction.expirationDate
            // Apple-authorized billing grace is an entitlement, not a free extension.
            if let status = await transaction.subscriptionStatus,
               status.state == .inGracePeriod,
               case .verified(let renewal) = status.renewalInfo {
                expiration = renewal.gracePeriodExpirationDate ?? expiration
            }
            records[transaction.productID] = PremiumEntitlementRecord(
                productID: transaction.productID, revocationDate: transaction.revocationDate,
                expirationDate: expiration
            )
            if latestTransaction == nil ||
                (transaction.expirationDate ?? .distantPast) > (latestTransaction?.expirationDate ?? .distantPast) {
                latestTransaction = transaction
            }
        }
        guard revision == entitlementStateRevision else { return }
        // A complete verified StoreKit snapshot is authoritative. Old session
        // purchases must not resurrect an expired or refunded entitlement.
        applyEntitlements(Array(records.values))
        let details = await subscriptionDetails(for: latestTransaction)
        guard revision == entitlementStateRevision else { return }
        enforceExpiration()
        subscription = canUsePremiumNow ? details : nil
    }

    func applyEntitlements(_ records: [PremiumEntitlementRecord]) {
        sessionEntitlements = Dictionary(uniqueKeysWithValues: records
            .filter { PremiumAccessPolicy.isActiveEntitlement(
                productID: $0.productID, revocationDate: $0.revocationDate,
                expirationDate: $0.expirationDate
            ) }
            .map { ($0.productID, $0) })
        enforceExpiration()
        hasResolvedEntitlements = true
        if !hasPremiumAccess { subscription = nil }
        scheduleEntitlementRefresh(at: sessionEntitlements.values.compactMap(\.expirationDate).max())
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
        entitlementStateRevision += 1
        let revision = entitlementStateRevision
        guard !transaction.isUpgraded,
              PremiumAccessPolicy.isActiveEntitlement(
                productID: transaction.productID, revocationDate: transaction.revocationDate,
                expirationDate: transaction.expirationDate
              ) else {
            sessionEntitlements.removeValue(forKey: transaction.productID)
            applyEntitlements(Array(sessionEntitlements.values))
            return false
        }
        sessionEntitlements[transaction.productID] = PremiumEntitlementRecord(
            productID: transaction.productID, revocationDate: transaction.revocationDate,
            expirationDate: transaction.expirationDate
        )
        applyEntitlements(Array(sessionEntitlements.values))
        let details = await subscriptionDetails(for: transaction)
        guard revision == entitlementStateRevision else { return canUsePremiumNow }
        enforceExpiration()
        subscription = canUsePremiumNow ? details : nil
        return canUsePremiumNow
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

        let delay = max(date.timeIntervalSinceNow, 0)
        entitlementExpirationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }

            guard let self else { return }
            self.enforceExpiration()
            await self.refreshEntitlements()
        }
    }

    private func log(_ message: String) {
#if DEBUG
        print("[PremiumStore] \(message)")
#endif
    }
}
