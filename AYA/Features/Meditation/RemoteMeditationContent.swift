import Foundation

struct RemoteMeditationAudioSource: Equatable {
    static let supportedCycleDays = 1...35

    let cycleDay: Int
    let fallbackResourceName: String

    var directoryURL: URL {
        let dayDirectory = String(format: "day_%02d", cycleDay)
        return URL(string: "https://hesia.app/content/menstrual_cycle/\(dayDirectory)/")!
    }

    var metadataURL: URL {
        directoryURL.appendingPathComponent("metadata.json")
    }
}

struct RemoteMeditationMetadata: Decodable, Equatable {
    let id: String
    let day: Int
    let audio: [String: String]
    let title: [String: String]
    let description: [String: String]
    let durationMinutes: Int
    let narrator: String

    enum CodingKeys: String, CodingKey {
        case id
        case day
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
    let audioURL: URL
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
        let audioURL = try await loadAudio(
            metadata: metadata,
            source: source,
            language: language,
            session: session
        )
        return LoadedRemoteMeditation(metadata: metadata, audioURL: audioURL)
    }

    static func loadAudio(
        metadata: RemoteMeditationMetadata,
        source: RemoteMeditationAudioSource,
        language: AppLanguage,
        session: URLSession = .shared
    ) async throws -> URL {
        guard let audioFileName = metadata.audioFileName(for: language) else {
            throw LoadingError.missingLocalizedAudio
        }

        let audioURL = source.directoryURL.appendingPathComponent(audioFileName)
        if let cachedURL = cachedAudioURL(
            source: source,
            language: language,
            fileName: audioFileName
        ), FileManager.default.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }

        let (temporaryURL, audioResponse) = try await session.download(from: audioURL)
        try validate(audioResponse)

        guard let destinationURL = cachedAudioURL(
            source: source,
            language: language,
            fileName: audioFileName
        ) else {
            return temporaryURL
        }

        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? fileManager.removeItem(at: destinationURL)
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)

        return destinationURL
    }

    static func loadMetadata(
        source: RemoteMeditationAudioSource,
        session: URLSession = .shared
    ) async throws -> RemoteMeditationMetadata {
        let (metadataData, metadataResponse) = try await session.data(from: source.metadataURL)
        try validate(metadataResponse)

        let metadata = try JSONDecoder().decode(RemoteMeditationMetadata.self, from: metadataData)
        guard metadata.day == source.cycleDay else { throw LoadingError.invalidResponse }
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

    private static func cachedAudioURL(
        source: RemoteMeditationAudioSource,
        language: AppLanguage,
        fileName: String
    ) -> URL? {
        guard let cachesDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else { return nil }

        let cacheDirectory = cachesDirectory.appendingPathComponent(
            "HESIA/Meditations",
            isDirectory: true
        )
        let cacheName = "cycle-\(source.cycleDay)-\(language.contentLanguageCode)-\(fileName)"
        return cacheDirectory.appendingPathComponent(cacheName)
    }
}

private extension AppLanguage {
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
