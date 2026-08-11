import XCTest
@testable import HESIA

final class PregnancyWeekInfoRepositoryTests: XCTestCase {
    func testBundledCatalogDecodesFortyWeeks() {
        XCTAssertEqual(PregnancyWeekInfoRepository.shared.weekCount, 40)
    }

    func testCatalogContainsWeekOne() {
        XCTAssertNotNil(PregnancyWeekInfoRepository.shared.sourceInfo(for: 1))
        XCTAssertNotNil(PregnancyWeekInfoRepository.shared.info(for: 1, language: .turkish))
    }

    func testCatalogContainsWeekEighteen() {
        XCTAssertNotNil(PregnancyWeekInfoRepository.shared.sourceInfo(for: 18))
        XCTAssertNotNil(PregnancyWeekInfoRepository.shared.info(for: 18, language: .english))
    }

    func testCatalogContainsWeekForty() {
        XCTAssertNotNil(PregnancyWeekInfoRepository.shared.sourceInfo(for: 40))
        XCTAssertNotNil(PregnancyWeekInfoRepository.shared.info(for: 40, language: .turkish))
    }

    func testTurkishContentIsSelectedFromCatalog() throws {
        let repository = PregnancyWeekInfoRepository.shared
        let source = try XCTUnwrap(repository.sourceInfo(for: 18))
        let content = try XCTUnwrap(repository.info(for: 18, language: .turkish))

        XCTAssertEqual(content.baby, source.tr.baby)
        XCTAssertEqual(content.body, source.tr.body)
        XCTAssertEqual(content.experience, source.tr.experience)
    }

    func testEnglishContentIsSelectedFromCatalog() throws {
        let repository = PregnancyWeekInfoRepository.shared
        let source = try XCTUnwrap(repository.sourceInfo(for: 18))
        let content = try XCTUnwrap(repository.info(for: 18, language: .english))

        XCTAssertEqual(content.baby, source.en.baby)
        XCTAssertEqual(content.body, source.en.body)
        XCTAssertEqual(content.experience, source.en.experience)
    }

    func testInvalidWeeksReturnNilWithoutCrashing() {
        let repository = PregnancyWeekInfoRepository.shared

        XCTAssertNil(repository.info(for: 0, language: .turkish))
        XCTAssertNil(repository.info(for: 41, language: .english))
    }

    func testMissingCatalogDataIsHandledSafely() {
        let emptyCatalog = PregnancyWeekInfoCatalog(
            schemaVersion: 1,
            contentVersion: "test",
            disclaimer: .init(tr: "", en: ""),
            sectionTitles: .init(
                tr: .init(baby: "", body: "", experience: ""),
                en: .init(baby: "", body: "", experience: "")
            ),
            weeks: []
        )
        let repository = PregnancyWeekInfoRepository(catalog: emptyCatalog)

        XCTAssertEqual(repository.weekCount, 0)
        XCTAssertNil(repository.info(for: 18, language: .turkish))
    }
}
