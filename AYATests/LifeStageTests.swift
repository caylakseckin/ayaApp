import XCTest
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
        XCTAssertEqual(PremiumProductIdentifiers.monthly, "com.ayameditation.app.premium.monthly")
        XCTAssertEqual(PremiumProductIdentifiers.yearly, "com.ayameditation.app.premium.yearly")
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
