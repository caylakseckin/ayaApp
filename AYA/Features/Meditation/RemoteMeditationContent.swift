import Foundation

struct RemoteMeditationAudioSource: Equatable {
    static let supportedCycleDays = 1...35
    static let supportedPregnancyWeeks = 1...42

    enum Context: Equatable {
        case cycle(day: Int)
        case pregnancy(week: Int)
    }

    let context: Context
    let fallbackResourceName: String

    init(cycleDay: Int, fallbackResourceName: String) {
        context = .cycle(day: cycleDay)
        self.fallbackResourceName = fallbackResourceName
    }

    init(pregnancyWeek: Int, fallbackResourceName: String) {
        context = .pregnancy(week: pregnancyWeek)
        self.fallbackResourceName = fallbackResourceName
    }

    var cycleDay: Int? {
        guard case let .cycle(day) = context else { return nil }
        return day
    }

    var pregnancyWeek: Int? {
        guard case let .pregnancy(week) = context else { return nil }
        return week
    }

    var directoryURL: URL {
        switch context {
        case let .cycle(day):
            let directory = String(format: "day_%02d", day)
            return URL(string: "https://hesia.app/content/menstrual_cycle/\(directory)/")!
        case let .pregnancy(week):
            let directory = String(format: "week_%02d", week)
            return URL(string: "https://hesia.app/content/pregnancy/\(directory)/")!
        }
    }

    var metadataURL: URL {
        directoryURL.appendingPathComponent("metadata.json")
    }
}

struct RemoteMeditationMetadata: Decodable, Equatable {
    let id: String
    let day: Int?
    let week: Int?
    let audio: [String: String]
    let title: [String: String]
    let description: [String: String]
    let durationMinutes: Int
    let narrator: String

    enum CodingKeys: String, CodingKey {
        case id
        case day
        case week
        case audio
        case title
        case description
        case durationMinutes = "duration_minutes"
        case narrator
    }

    func audioFileName(for language: AppLanguage) -> String? {
        audio[language.contentLanguageCode]
    }

    func localizedTitle(for language: AppLanguage) -> String? {
        title[language.contentLanguageCode]
    }

    func localizedDescription(for language: AppLanguage) -> String? {
        description[language.contentLanguageCode]
    }
}

struct LoadedRemoteMeditation {
    let metadata: RemoteMeditationMetadata
    let audioFile: LoadedRemoteAudioFile
}

struct LoadedRemoteAudioFile {
    enum Storage {
        case offline
        case temporary
    }

    let url: URL
    let storage: Storage
}

enum RemoteMeditationContentLoader {
    enum LoadingError: Error {
        case invalidResponse
        case missingLocalizedAudio
    }

    static func load(
        source: RemoteMeditationAudioSource,
        language: AppLanguage,
        session: URLSession = .shared
    ) async throws -> LoadedRemoteMeditation {
        let metadata = try await loadMetadata(source: source, session: session)
        let audioFile = try await loadAudio(
            metadata: metadata,
            source: source,
            language: language,
            session: session
        )
        return LoadedRemoteMeditation(metadata: metadata, audioFile: audioFile)
    }

    static func loadAudio(
        metadata: RemoteMeditationMetadata,
        source: RemoteMeditationAudioSource,
        language: AppLanguage,
        session: URLSession = .shared
    ) async throws -> LoadedRemoteAudioFile {
        guard let audioFileName = metadata.audioFileName(for: language) else {
            throw LoadingError.missingLocalizedAudio
        }

        if let offlineURL = await OfflineMeditationStore.shared.audioURL(
            source: source,
            language: language,
            fileName: audioFileName
        ) {
            return LoadedRemoteAudioFile(url: offlineURL, storage: .offline)
        }

        let audioURL = source.directoryURL.appendingPathComponent(audioFileName)
        let (temporaryURL, audioResponse) = try await session.download(from: audioURL)
        try validate(audioResponse)

        let fileManager = FileManager.default
        let playbackDirectory = fileManager.temporaryDirectory.appendingPathComponent(
            "HESIA/Playback",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: playbackDirectory,
            withIntermediateDirectories: true
        )
        let fileExtension = (audioFileName as NSString).pathExtension
        let destinationURL = playbackDirectory.appendingPathComponent(
            "\(UUID().uuidString).\(fileExtension)"
        )
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)

        return LoadedRemoteAudioFile(url: destinationURL, storage: .temporary)
    }

    static func loadMetadata(
        source: RemoteMeditationAudioSource,
        session: URLSession = .shared
    ) async throws -> RemoteMeditationMetadata {
        let (metadataData, metadataResponse) = try await session.data(from: source.metadataURL)
        try validate(metadataResponse)

        let metadata = try JSONDecoder().decode(RemoteMeditationMetadata.self, from: metadataData)
        let hasMatchingContext = switch source.context {
        case let .cycle(day):
            metadata.day == day
        case let .pregnancy(week):
            metadata.week == week
        }
        guard hasMatchingContext else { throw LoadingError.invalidResponse }
        return metadata
    }

    private static func validate(_ response: URLResponse) throws {
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            throw LoadingError.invalidResponse
        }
    }

}

extension AppLanguage {
    var contentLanguageCode: String {
        switch self {
        case .turkish:
            "tr"
        case .english:
            "en"
        case .system:
            AppLanguage.defaultExplicitLanguage.contentLanguageCode
        }
    }
}
