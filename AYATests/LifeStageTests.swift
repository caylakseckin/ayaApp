import XCTest
import StoreKitTest

@MainActor
final class PremiumExpirationTests: XCTestCase {
    func testMonthlyCancellationKeepsRemainingTimeThenExpires() async throws {
        try await verifyCancellationAndExpiration(productID: PremiumProductIdentifiers.monthly)
    }

    func testYearlyCancellationKeepsRemainingTimeThenExpires() async throws {
        try await verifyCancellationAndExpiration(productID: PremiumProductIdentifiers.yearly)
    }

    private func verifyCancellationAndExpiration(productID: String) async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "HESIA", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let transaction = try await session.buyProduct(identifier: productID)
        let store = PremiumStore(automaticallyStarts: false, allowsTestUnlock: false)
        await store.refreshEntitlements()
        XCTAssertTrue(store.hasPremiumAccess)
        try session.disableAutoRenewForTransaction(identifier: UInt(transaction.id))
        await store.refreshEntitlements()
        XCTAssertTrue(store.hasPremiumAccess, "Cancelling renewal must preserve paid time")
        try session.expireSubscription(productIdentifier: productID)
        await waitForRevocation(store)
        XCTAssertFalse(store.hasPremiumAccess, "Expired purchase must not survive through an old session record")
        XCTAssertFalse(store.canUsePremiumNow)
        let relaunchedStore = PremiumStore(automaticallyStarts: false, allowsTestUnlock: false)
        await relaunchedStore.refreshEntitlements()
        XCTAssertFalse(relaunchedStore.hasPremiumAccess)
    }

    func testRefundRemovesPreviouslyGrantedAccess() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "HESIA", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }
        let transaction = try await session.buyProduct(identifier: PremiumProductIdentifiers.yearly)
        let store = PremiumStore(automaticallyStarts: false, allowsTestUnlock: false)
        await store.refreshEntitlements()
        XCTAssertTrue(store.hasPremiumAccess)
        try session.refundTransaction(identifier: UInt(transaction.id))
        await waitForRevocation(store)
        XCTAssertFalse(store.hasPremiumAccess)
    }

    func testDeadlineStopsPlaybackAndPreventsReplayWithoutStoreResponse() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "HESIA", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.clearTransactions()
        defer { session.clearTransactions() }
        let store = PremiumStore(automaticallyStarts: false, allowsTestUnlock: false)
        store.applyEntitlements([PremiumEntitlementRecord(
            productID: PremiumProductIdentifiers.yearly, revocationDate: nil,
            expirationDate: Date().addingTimeInterval(1)
        )])
        let meditation = DailyMeditation(
            id: "motherhood-expiration-test", titleLocalizationKey: "", descriptionLocalizationKey: "",
            contextNameLocalizationKey: "", contextFormatLocalizationKey: "", contextValue: 0,
            durationMinutes: 1, voiceLocalizationKey: "", audioResourceName: "aya-demo-meditation-8m.m4a"
        )
        let player = MeditationPlayerViewModel(meditation: meditation, premiumStore: store)
        player.play()
        XCTAssertTrue(player.isPlaying)
        try await Task.sleep(for: .seconds(1.3))
        XCTAssertFalse(store.hasPremiumAccess)
        XCTAssertFalse(player.isPlaying)
        player.play()
        XCTAssertFalse(player.isPlaying)
        for stage in LifeStage.allCases where stage.isPremium {
            XCTAssertFalse(PremiumAccessPolicy.hasAccess(to: stage, entitlementsResolved: true, hasPremiumAccess: store.hasPremiumAccess))
        }
    }

    private func waitForRevocation(_ store: PremiumStore) async {
        // StoreKitTest mutations propagate asynchronously to StoreKit 2.
        for _ in 0..<30 {
            await store.refreshEntitlements()
            if !store.hasPremiumAccess { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
@testable import HESIA

final class LifeStageTests: XCTestCase {
    func testMotherhoodRemainsDefinedWhileFourStagesAreAvailable() {
        XCTAssertEqual(LifeStage.allCases.count, 5)
        XCTAssertEqual(
            LifeStage.availableCases,
            [.cycle, .pregnancy, .birthMoment, .postpartum]
        )
        XCTAssertFalse(LifeStage.motherhood03.isAvailable)
    }

    func testOnlyCycleIsFree() {
        let freeStages = LifeStage.allCases.filter { !$0.isPremium }
        XCTAssertEqual(freeStages, [.cycle])
    }

    func testEveryStageHasLocalizationKeys() {
        for stage in LifeStage.allCases {
            XCTAssertEqual(stage.localizationKeys.count, 4)
            XCTAssertTrue(stage.localizationKeys.allSatisfy { !$0.isEmpty })
        }
    }

    @MainActor
    func testViewModelDefaultsToCycle() {
        let viewModel = LifeStageSelectionViewModel()
        XCTAssertEqual(viewModel.selectedStage, .cycle)
    }

    @MainActor
    func testViewModelCanSelectAnotherStage() {
        let viewModel = LifeStageSelectionViewModel()
        viewModel.select(.postpartum)
        XCTAssertEqual(viewModel.selectedStage, .postpartum)
    }

    @MainActor
    func testViewModelCanStartWithPersistedSelection() {
        let viewModel = LifeStageSelectionViewModel(selectedStage: .motherhood03)
        XCTAssertEqual(viewModel.selectedStage, .motherhood03)
    }

    func testActiveStagePersistenceKeyIsStable() {
        XCTAssertEqual(LifeStagePersistenceKeys.activeStage, "life_stage.active")
    }

    func testCycleInfoProviderSupportsEveryPhase() {
        let contents = CyclePhase.allCases.map(CycleInfoProvider.content)
        XCTAssertEqual(Set(contents.map(\.id)).count, CyclePhase.allCases.count)
        XCTAssertTrue(contents.allSatisfy { !$0.sections.isEmpty })
    }

    func testEveryCyclePhaseHasAUniqueCalendarHelperLocalizationKey() {
        let keys = CyclePhase.allCases.map(\.calendarHelperLocalizationKey)

        XCTAssertEqual(Set(keys).count, CyclePhase.allCases.count)
        XCTAssertTrue(keys.allSatisfy { $0.hasPrefix("cycle.calendar.phase_helper.") })
    }

    func testMotherhoodInfoProviderMapsEveryRangeToContent() {
        let contents = MotherhoodAgeRange.allCases.map(MotherhoodInfoProvider.content)
        XCTAssertEqual(Set(contents.map(\.id)).count, MotherhoodAgeRange.allCases.count)
    }

    func testPremiumProductIdentifiersAreStableAndUnique() {
        XCTAssertEqual(PremiumProductIdentifiers.monthly, "com.hesia.meditation.premium.monthly")
        XCTAssertEqual(PremiumProductIdentifiers.yearly, "com.hesia.meditation.premium.yearly")
        XCTAssertEqual(PremiumProductIdentifiers.all.count, 2)
    }

    func testPremiumPlansMapToStoreKitProductIdentifiers() {
        XCTAssertEqual(PremiumPlan.yearly.productIdentifier, PremiumProductIdentifiers.yearly)
        XCTAssertEqual(PremiumPlan.monthly.productIdentifier, PremiumProductIdentifiers.monthly)
        XCTAssertEqual(PremiumPlan(productIdentifier: PremiumProductIdentifiers.yearly), .yearly)
        XCTAssertEqual(PremiumPlan(productIdentifier: PremiumProductIdentifiers.monthly), .monthly)
        XCTAssertNil(PremiumPlan(productIdentifier: "unknown.product"))
    }

    func testExpiredOrRevokedPurchaseDoesNotGrantAccess() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertFalse(
            PremiumAccessPolicy.isActiveEntitlement(
                productID: PremiumProductIdentifiers.monthly,
                revocationDate: nil,
                expirationDate: Date(timeIntervalSince1970: 999),
                now: now
            )
        )
        XCTAssertFalse(
            PremiumAccessPolicy.isActiveEntitlement(
                productID: PremiumProductIdentifiers.monthly,
                revocationDate: now,
                expirationDate: Date(timeIntervalSince1970: 2_000),
                now: now
            )
        )
    }

    func testUnknownProductDoesNotGrantPremiumAccess() {
        XCTAssertFalse(
            PremiumAccessPolicy.isActiveEntitlement(
                productID: "unknown.product",
                revocationDate: nil,
                expirationDate: nil
            )
        )
    }

    func testVerifiedSubscriptionSurvivesTemporarilyEmptyStoreRefresh() {
        let effectiveProductIDs = PremiumAccessPolicy.effectiveProductIDs(
            storeProductIDs: [],
            sessionEntitlements: [
                PremiumEntitlementRecord(
                    productID: PremiumProductIdentifiers.monthly,
                    revocationDate: nil,
                    expirationDate: Date.distantFuture
                )
            ]
        )

        XCTAssertEqual(effectiveProductIDs, [PremiumProductIdentifiers.monthly])
    }

    func testExpiredSessionPurchaseDoesNotSurviveStoreRefresh() {
        let now = Date(timeIntervalSince1970: 1_000)
        let effectiveProductIDs = PremiumAccessPolicy.effectiveProductIDs(
            storeProductIDs: [],
            sessionEntitlements: [
                PremiumEntitlementRecord(
                    productID: PremiumProductIdentifiers.monthly,
                    revocationDate: nil,
                    expirationDate: Date(timeIntervalSince1970: 999)
                )
            ],
            now: now
        )

        XCTAssertTrue(effectiveProductIDs.isEmpty)
    }

    func testFreeStageDoesNotRequirePremiumEntitlement() {
        XCTAssertTrue(
            PremiumAccessPolicy.hasAccess(
                to: .cycle,
                entitlementsResolved: true,
                hasPremiumAccess: false
            )
        )
    }

    func testPremiumStageLocksAfterEntitlementsResolveWithoutAccess() {
        XCTAssertFalse(
            PremiumAccessPolicy.hasAccess(
                to: .pregnancy,
                entitlementsResolved: true,
                hasPremiumAccess: false
            )
        )
        XCTAssertTrue(
            PremiumAccessPolicy.requiresThemeSelection(
                for: .pregnancy,
                entitlementsResolved: true,
                hasPremiumAccess: false
            )
        )
    }

    func testPremiumStageRemainsAvailableWhileAppleReportsEntitlement() {
        XCTAssertTrue(
            PremiumAccessPolicy.hasAccess(
                to: .postpartum,
                entitlementsResolved: true,
                hasPremiumAccess: true
            )
        )
        XCTAssertFalse(
            PremiumAccessPolicy.requiresThemeSelection(
                for: .motherhood03,
                entitlementsResolved: true,
                hasPremiumAccess: true
            )
        )
    }

    func testUnresolvedPremiumEntitlementWaitsInsteadOfRedirecting() {
        XCTAssertFalse(
            PremiumAccessPolicy.requiresThemeSelection(
                for: .pregnancy,
                entitlementsResolved: false,
                hasPremiumAccess: false
            )
        )
    }
}
