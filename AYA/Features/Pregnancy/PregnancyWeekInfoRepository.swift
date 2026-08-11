import Foundation

struct PregnancyWeekInfoCatalog: Decodable, Sendable {
    let schemaVersion: Int
    let contentVersion: String
    let disclaimer: LocalizedPregnancyWeekString
    let sectionTitles: LocalizedPregnancyWeekSectionTitles
    let weeks: [PregnancyWeekInfo]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case contentVersion = "content_version"
        case disclaimer
        case sectionTitles = "section_titles"
        case weeks
    }
}

struct PregnancyWeekInfo: Decodable, Sendable {
    let week: Int
    let tr: LocalizedPregnancyWeekInfo
    let en: LocalizedPregnancyWeekInfo
}

struct LocalizedPregnancyWeekInfo: Decodable, Sendable {
    let baby: String
    let body: String
    let experience: String
}

struct LocalizedPregnancyWeekString: Decodable, Sendable {
    let tr: String
    let en: String
}

struct LocalizedPregnancyWeekSectionTitles: Decodable, Sendable {
    let tr: PregnancyWeekSectionTitles
    let en: PregnancyWeekSectionTitles
}

struct PregnancyWeekSectionTitles: Decodable, Sendable {
    let baby: String
    let body: String
    let experience: String
}

struct PregnancyWeekInfoContent: Identifiable, Sendable {
    let week: Int
    let babyTitle: String
    let baby: String
    let bodyTitle: String
    let body: String
    let experienceTitle: String
    let experience: String
    let disclaimer: String

    var id: Int { week }
}

struct PregnancyWeekInfoRepository: Sendable {
    static let shared = PregnancyWeekInfoRepository()

    private static let resourceName = "hesia_pregnancy_week_info_01_40"
    private let catalog: PregnancyWeekInfoCatalog?
    private let weeksByNumber: [Int: PregnancyWeekInfo]

    init(bundle: Bundle = .main) {
        do {
            let url = try Self.resourceURL(in: bundle)
            let data = try Data(contentsOf: url)
            let decodedCatalog = try JSONDecoder().decode(PregnancyWeekInfoCatalog.self, from: data)
            catalog = decodedCatalog
            weeksByNumber = Dictionary(
                decodedCatalog.weeks.map { ($0.week, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        } catch {
            catalog = nil
            weeksByNumber = [:]
#if DEBUG
            print("PregnancyWeekInfoRepository: failed to load catalog: \(error)")
#endif
        }
    }

    init(data: Data) throws {
        let decodedCatalog = try JSONDecoder().decode(PregnancyWeekInfoCatalog.self, from: data)
        catalog = decodedCatalog
        weeksByNumber = Dictionary(
            decodedCatalog.weeks.map { ($0.week, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    init(catalog: PregnancyWeekInfoCatalog) {
        self.catalog = catalog
        weeksByNumber = Dictionary(
            catalog.weeks.map { ($0.week, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var weekCount: Int {
        catalog?.weeks.count ?? 0
    }

    func sourceInfo(for week: Int) -> PregnancyWeekInfo? {
        weeksByNumber[week]
    }

    func info(for week: Int, language: AppLanguage) -> PregnancyWeekInfoContent? {
        guard (1...40).contains(week), let catalog, let weekInfo = weeksByNumber[week] else {
            return nil
        }

        let resolvedLanguage = language == .system ? AppLanguage.defaultExplicitLanguage : language
        let localizedInfo: LocalizedPregnancyWeekInfo
        let sectionTitles: PregnancyWeekSectionTitles
        let disclaimer: String

        switch resolvedLanguage {
        case .turkish:
            localizedInfo = weekInfo.tr
            sectionTitles = catalog.sectionTitles.tr
            disclaimer = catalog.disclaimer.tr
        case .english, .system:
            localizedInfo = weekInfo.en
            sectionTitles = catalog.sectionTitles.en
            disclaimer = catalog.disclaimer.en
        }

        return PregnancyWeekInfoContent(
            week: week,
            babyTitle: sectionTitles.baby,
            baby: localizedInfo.baby,
            bodyTitle: sectionTitles.body,
            body: localizedInfo.body,
            experienceTitle: sectionTitles.experience,
            experience: localizedInfo.experience,
            disclaimer: disclaimer
        )
    }

    private static func resourceURL(in bundle: Bundle) throws -> URL {
        if let url = bundle.url(forResource: resourceName, withExtension: "json") {
            return url
        }
        if let url = bundle.url(forResource: resourceName, withExtension: "json", subdirectory: "Content") {
            return url
        }
        throw CocoaError(.fileNoSuchFile)
    }
}
