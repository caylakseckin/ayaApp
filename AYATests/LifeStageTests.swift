import XCTest
@testable import HESIA

final class LifeStageTests: XCTestCase {
    func testFourLifeStagesAreDefined() {
        XCTAssertEqual(LifeStage.allCases.count, 4)
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
        XCTAssertEqual(PremiumProductIdentifiers.lifetime, "com.ayameditation.app.premium.lifetime")
        XCTAssertEqual(PremiumProductIdentifiers.monthly, "com.ayameditation.app.premium.monthly")
        XCTAssertEqual(PremiumProductIdentifiers.all.count, 2)
    }

    func testPremiumPlansMapToStoreKitProductIdentifiers() {
        XCTAssertEqual(PremiumPlan.lifetime.productIdentifier, PremiumProductIdentifiers.lifetime)
        XCTAssertEqual(PremiumPlan.monthly.productIdentifier, PremiumProductIdentifiers.monthly)
        XCTAssertEqual(PremiumPlan(productIdentifier: PremiumProductIdentifiers.lifetime), .lifetime)
        XCTAssertEqual(PremiumPlan(productIdentifier: PremiumProductIdentifiers.monthly), .monthly)
        XCTAssertNil(PremiumPlan(productIdentifier: "unknown.product"))
    }
}
