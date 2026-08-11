import XCTest
@testable import HESIA

final class MotherhoodTests: XCTestCase {
    func testAllFourAgeRangesAreDefinedInOrder() {
        XCTAssertEqual(
            MotherhoodAgeRange.allCases,
            [.infant, .toddler, .preschool, .schoolAge]
        )
    }

    func testAgeRangeProgressMapsAcrossFourStages() {
        XCTAssertEqual(MotherhoodAgeRange.infant.progress, 0.25)
        XCTAssertEqual(MotherhoodAgeRange.toddler.progress, 0.5)
        XCTAssertEqual(MotherhoodAgeRange.preschool.progress, 0.75)
        XCTAssertEqual(MotherhoodAgeRange.schoolAge.progress, 1)
    }

    func testStorePersistsSelectionWithoutAffectingOtherStages() {
        let defaults = makeDefaults()
        defer { clear(defaults) }
        let store = MotherhoodStore(defaults: defaults)

        store.save(.toddler)

        XCTAssertEqual(store.selectedRange, .toddler)
        XCTAssertTrue(defaults.bool(forKey: MotherhoodPersistenceKeys.onboardingCompleted))
        XCTAssertNil(defaults.object(forKey: PregnancyPersistenceKeys.referenceWeek))
        XCTAssertNil(defaults.object(forKey: CyclePersistenceKeys.averageLength))
    }

    func testEachRangeProvidesSemanticContentKeysAndMeditation() {
        let provider = MotherhoodMeditationProvider()

        for range in MotherhoodAgeRange.allCases {
            XCTAssertFalse(range.titleLocalizationKey.isEmpty)
            XCTAssertFalse(range.detailSubtitleLocalizationKey.isEmpty)
            XCTAssertFalse(range.insightTitleLocalizationKey.isEmpty)
            XCTAssertFalse(range.insightBodyLocalizationKey.isEmpty)
            XCTAssertFalse(range.journeyTitleLocalizationKey.isEmpty)
            XCTAssertFalse(range.journeyDescriptionLocalizationKey.isEmpty)
            XCTAssertFalse(range.journeyFocusLocalizationKey.isEmpty)
            XCTAssertFalse(range.journeySummaryDescriptionLocalizationKey.isEmpty)

            let meditation = provider.meditation(for: range)
            XCTAssertEqual(meditation.durationMinutes, 8)
            XCTAssertEqual(meditation.contextNameLocalizationKey, range.meditationContextLocalizationKey)
            XCTAssertNotNil(meditation.audioResourceName)
        }
    }

    func testJourneyContentKeysAreUniqueAcrossRanges() {
        XCTAssertEqual(
            Set(MotherhoodAgeRange.allCases.map(\.journeyTitleLocalizationKey)).count,
            MotherhoodAgeRange.allCases.count
        )
        XCTAssertEqual(
            Set(MotherhoodAgeRange.allCases.map(\.journeyDescriptionLocalizationKey)).count,
            MotherhoodAgeRange.allCases.count
        )
        XCTAssertEqual(
            Set(MotherhoodAgeRange.allCases.map(\.journeyFocusLocalizationKey)).count,
            MotherhoodAgeRange.allCases.count
        )
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "MotherhoodTests.\(UUID().uuidString)")!
    }

    private func clear(_ defaults: UserDefaults) {
        defaults.removeObject(forKey: MotherhoodPersistenceKeys.ageRange)
        defaults.removeObject(forKey: MotherhoodPersistenceKeys.onboardingCompleted)
    }
}
