import Foundation
import SwiftUI

enum OfflineMeditationPreferenceKeys {
    static let isEnabled = "offlineMeditations.isEnabled"
}

enum OfflineMeditationPackagePlanner {
    static let maximumStoredDays = 3

    static func cycleDays(currentDay: Int, cycleLength: Int) -> [Int] {
        guard cycleLength > 0 else { return [] }

        return (0..<maximumStoredDays).map { offset in
            ((max(currentDay, 1) - 1 + offset) % cycleLength) + 1
        }
    }

    static func pregnancyWeeks(currentWeek: Int) -> [Int] {
        RemoteMeditationAudioSource.supportedPregnancyWeeks.contains(currentWeek)
            ? [currentWeek]
            : []
    }

    static func postpartumDays(currentDay: Int) -> [Int] {
        guard RemoteMeditationAudioSource.supportedPostpartumDays.contains(currentDay) else {
            return []
        }
        let finalDay = min(
            currentDay + maximumStoredDays - 1,
            RemoteMeditationAudioSource.supportedPostpartumDays.upperBound
        )
        return Array(currentDay...finalDay)
    }
}

enum OfflineMeditationDownloadState: Equatable {
    case idle
    case downloading
    case ready(Int)
    case partial(Int)
    case failed
}

@MainActor
final class OfflineMeditationManager: ObservableObject {
    static let shared = OfflineMeditationManager()

    @Published private(set) var state: OfflineMeditationDownloadState = .idle
    private var syncTask: Task<Void, Never>?

    private init() {
        OfflineMeditationStore.removeLegacyAutomaticCache()
    }

    func syncCyclePackage(currentDay: Int, cycleLength: Int, language: AppLanguage) {
        let days = OfflineMeditationPackagePlanner.cycleDays(
            currentDay: currentDay,
            cycleLength: cycleLength
        )
        let supportedDays = days.filter(RemoteMeditationAudioSource.supportedCycleDays.contains)
        guard !supportedDays.isEmpty else {
            state = .idle
            return
        }

        syncTask?.cancel()
        state = .downloading
        syncTask = Task { [weak self] in
            let result = await OfflineMeditationStore.shared.syncCyclePackage(
                days: supportedDays,
                language: language
            )
            guard !Task.isCancelled else { return }

            if result.availableCount == result.requestedCount {
                self?.state = .ready(result.availableCount)
            } else if result.availableCount > 0 {
                self?.state = .partial(result.availableCount)
            } else {
                self?.state = .failed
            }
        }
    }

    func syncPregnancyPackage(week: Int, language: AppLanguage) {
        guard let week = OfflineMeditationPackagePlanner.pregnancyWeeks(currentWeek: week).first else {
            state = .idle
            return
        }

        syncTask?.cancel()
        state = .downloading
        syncTask = Task { [weak self] in
            let result = await OfflineMeditationStore.shared.syncPregnancyPackage(
                week: week,
                language: language
            )
            guard !Task.isCancelled else { return }

            if result.availableCount == result.requestedCount {
                self?.state = .ready(result.availableCount)
            } else {
                self?.state = .failed
            }
        }
    }

    func syncPostpartumPackage(currentDay: Int, language: AppLanguage) {
        let days = OfflineMeditationPackagePlanner.postpartumDays(currentDay: currentDay)
        guard !days.isEmpty else {
            state = .idle
            return
        }

        syncTask?.cancel()
        state = .downloading
        syncTask = Task { [weak self] in
            let result = await OfflineMeditationStore.shared.syncPostpartumPackage(
                days: days,
                language: language
            )
            guard !Task.isCancelled else { return }

            if result.availableCount == result.requestedCount {
                self?.state = .ready(result.availableCount)
            } else if result.availableCount > 0 {
                self?.state = .partial(result.availableCount)
            } else {
                self?.state = .failed
            }
        }
    }

    func syncBirthPackage(practices: [String], language: AppLanguage) {
        guard !practices.isEmpty else {
            state = .idle
            return
        }

        syncTask?.cancel()
        state = .downloading
        syncTask = Task { [weak self] in
            let result = await OfflineMeditationStore.shared.syncBirthPackage(
                practices: practices,
                language: language
            )
            guard !Task.isCancelled else { return }

            if result.availableCount == result.requestedCount {
                self?.state = .ready(result.availableCount)
            } else if result.availableCount > 0 {
                self?.state = .partial(result.availableCount)
            } else {
                self?.state = .failed
            }
        }
    }

    func removeDownloads() {
        syncTask?.cancel()
        syncTask = nil
        state = .idle
        Task {
            await OfflineMeditationStore.shared.removeAll()
        }
    }
}

actor OfflineMeditationStore {
    static let shared = OfflineMeditationStore()

    struct SyncResult: Equatable {
        let availableCount: Int
        let requestedCount: Int
    }

    private struct Entry: Codable, Hashable {
        let cycleDay: Int?
        let pregnancyWeek: Int?
        let postpartumDay: Int?
        let birthPractice: String?
        let languageCode: String
        let audioFileName: String
        let storedFileName: String

        var key: String {
            if let cycleDay {
                return "cycle-\(cycleDay)-\(languageCode)-\(audioFileName)"
            }
            if let pregnancyWeek {
                return "pregnancy-\(pregnancyWeek)-\(languageCode)-\(audioFileName)"
            }
            if let postpartumDay {
                return "postpartum-\(postpartumDay)-\(languageCode)-\(audioFileName)"
            }
            if let birthPractice {
                return "birth-\(birthPractice)-\(languageCode)-\(audioFileName)"
            }
            return "invalid-\(languageCode)-\(audioFileName)"
        }
    }

    private let fileManager: FileManager
    private let session: URLSession
    private let directoryURL: URL
    private let manifestURL: URL

    init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.session = session

        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let resolvedDirectory = directoryURL ?? applicationSupport
            .appendingPathComponent("HESIA/OfflineMeditations", isDirectory: true)
        self.directoryURL = resolvedDirectory
        manifestURL = resolvedDirectory.appendingPathComponent("manifest.json")
    }

    func audioURL(
        source: RemoteMeditationAudioSource,
        language: AppLanguage,
        fileName: String
    ) -> URL? {
        let languageCode = languageCode(for: language)
        let key: String
        switch source.context {
        case let .cycle(day):
            key = cycleEntryKey(
                day: day,
                languageCode: languageCode,
                audioFileName: fileName
            )
        case let .pregnancy(week):
            key = pregnancyEntryKey(
                week: week,
                languageCode: languageCode,
                audioFileName: fileName
            )
        case let .birth(practice):
            key = birthEntryKey(
                practice: practice,
                languageCode: languageCode,
                audioFileName: fileName
            )
        case let .postpartum(day):
            key = postpartumEntryKey(
                day: day,
                languageCode: languageCode,
                audioFileName: fileName
            )
        }
        guard let entry = loadManifest().first(where: { $0.key == key }) else { return nil }
        let url = directoryURL.appendingPathComponent(entry.storedFileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func syncCyclePackage(days: [Int], language: AppLanguage) async -> SyncResult {
        let uniqueDays = Array(Set(days)).sorted { lhs, rhs in
            (days.firstIndex(of: lhs) ?? 0) < (days.firstIndex(of: rhs) ?? 0)
        }.prefix(OfflineMeditationPackagePlanner.maximumStoredDays)
        let requestedDays = Array(uniqueDays)
        guard !requestedDays.isEmpty else { return SyncResult(availableCount: 0, requestedCount: 0) }

        try? prepareDirectory()
        var manifest = loadManifest()
        var desiredKeys = Set<String>()
        var availableKeys = Set<String>()

        for day in requestedDays {
            guard !Task.isCancelled else { break }
            let source = RemoteMeditationAudioSource(
                cycleDay: day,
                fallbackResourceName: "aya-demo-meditation-8m.m4a"
            )

            do {
                let metadata = try await RemoteMeditationContentLoader.loadMetadata(
                    source: source,
                    session: session
                )
                guard let audioFileName = metadata.audioFileName(for: language) else { continue }
                let languageCode = languageCode(for: language)
                let key = cycleEntryKey(
                    day: day,
                    languageCode: languageCode,
                    audioFileName: audioFileName
                )
                desiredKeys.insert(key)

                if let existing = manifest.first(where: { $0.key == key }) {
                    let existingURL = directoryURL.appendingPathComponent(existing.storedFileName)
                    if fileManager.fileExists(atPath: existingURL.path) {
                        availableKeys.insert(key)
                        continue
                    }
                }

                let remoteURL = source.directoryURL.appendingPathComponent(audioFileName)
                let (temporaryURL, response) = try await session.download(from: remoteURL)
                try validate(response)

                let storedFileName = "cycle-\(day)-\(languageCode)-\(UUID().uuidString).\((audioFileName as NSString).pathExtension)"
                let destinationURL = directoryURL.appendingPathComponent(storedFileName)
                try fileManager.moveItem(at: temporaryURL, to: destinationURL)

                let entry = Entry(
                    cycleDay: day,
                    pregnancyWeek: nil,
                    postpartumDay: nil,
                    birthPractice: nil,
                    languageCode: languageCode,
                    audioFileName: audioFileName,
                    storedFileName: storedFileName
                )
                manifest.removeAll { $0.key == key }
                manifest.append(entry)
                availableKeys.insert(key)
                saveManifest(manifest)
            } catch {
                // Missing/404 audio is expected while future daily content is being published.
                continue
            }
        }

        // Keep the previous package until today's replacement is safely available.
        if let currentDay = requestedDays.first {
            let currentIsAvailable = manifest.contains { entry in
                entry.cycleDay == currentDay
                    && entry.languageCode == languageCode(for: language)
                    && availableKeys.contains(entry.key)
            }
            if currentIsAvailable {
                let obsoleteEntries = manifest.filter {
                    $0.cycleDay != nil && !desiredKeys.contains($0.key)
                }
                obsoleteEntries.forEach { entry in
                    try? fileManager.removeItem(
                        at: directoryURL.appendingPathComponent(entry.storedFileName)
                    )
                }
                manifest.removeAll { $0.cycleDay != nil && !desiredKeys.contains($0.key) }
                saveManifest(manifest)
            }
        }

        return SyncResult(
            availableCount: availableKeys.count,
            requestedCount: requestedDays.count
        )
    }

    func syncPregnancyPackage(week: Int, language: AppLanguage) async -> SyncResult {
        guard RemoteMeditationAudioSource.supportedPregnancyWeeks.contains(week) else {
            return SyncResult(availableCount: 0, requestedCount: 0)
        }

        let source = RemoteMeditationAudioSource(
            pregnancyWeek: week,
            fallbackResourceName: "aya-demo-meditation-9m.m4a"
        )
        try? prepareDirectory()
        var manifest = loadManifest()

        do {
            let metadata = try await RemoteMeditationContentLoader.loadMetadata(
                source: source,
                session: session
            )
            guard let audioFileName = metadata.audioFileName(for: language) else {
                return SyncResult(availableCount: 0, requestedCount: 1)
            }

            let languageCode = languageCode(for: language)
            let key = pregnancyEntryKey(
                week: week,
                languageCode: languageCode,
                audioFileName: audioFileName
            )

            if let existing = manifest.first(where: { $0.key == key }) {
                let existingURL = directoryURL.appendingPathComponent(existing.storedFileName)
                if fileManager.fileExists(atPath: existingURL.path) {
                    removeObsoletePregnancyEntries(keeping: key, from: &manifest)
                    return SyncResult(availableCount: 1, requestedCount: 1)
                }
            }

            let remoteURL = source.directoryURL.appendingPathComponent(audioFileName)
            let (temporaryURL, response) = try await session.download(from: remoteURL)
            try validate(response)

            let storedFileName = "pregnancy-\(week)-\(languageCode)-\(UUID().uuidString).\((audioFileName as NSString).pathExtension)"
            let destinationURL = directoryURL.appendingPathComponent(storedFileName)
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)

            manifest.removeAll { $0.key == key }
            manifest.append(
                Entry(
                    cycleDay: nil,
                    pregnancyWeek: week,
                    postpartumDay: nil,
                    birthPractice: nil,
                    languageCode: languageCode,
                    audioFileName: audioFileName,
                    storedFileName: storedFileName
                )
            )
            saveManifest(manifest)
            removeObsoletePregnancyEntries(keeping: key, from: &manifest)
            return SyncResult(availableCount: 1, requestedCount: 1)
        } catch {
            return SyncResult(availableCount: 0, requestedCount: 1)
        }
    }

    func syncBirthPackage(practices: [String], language: AppLanguage) async -> SyncResult {
        let requestedPractices = Array(Set(practices)).sorted { lhs, rhs in
            (practices.firstIndex(of: lhs) ?? 0) < (practices.firstIndex(of: rhs) ?? 0)
        }
        guard !requestedPractices.isEmpty else {
            return SyncResult(availableCount: 0, requestedCount: 0)
        }

        try? prepareDirectory()
        var manifest = loadManifest()
        var availableKeys = Set<String>()

        for practice in requestedPractices {
            guard !Task.isCancelled else { break }
            let source = RemoteMeditationAudioSource(birthPractice: practice)

            do {
                let metadata = try await RemoteMeditationContentLoader.loadMetadata(
                    source: source,
                    session: session
                )
                guard let audioFileName = metadata.audioFileName(for: language) else { continue }
                let languageCode = languageCode(for: language)
                let key = birthEntryKey(
                    practice: practice,
                    languageCode: languageCode,
                    audioFileName: audioFileName
                )
                if let existing = manifest.first(where: { $0.key == key }) {
                    let existingURL = directoryURL.appendingPathComponent(existing.storedFileName)
                    if fileManager.fileExists(atPath: existingURL.path) {
                        availableKeys.insert(key)
                        continue
                    }
                }

                let remoteURL = source.directoryURL.appendingPathComponent(audioFileName)
                let (temporaryURL, response) = try await session.download(from: remoteURL)
                try validate(response)

                let fileExtension = (audioFileName as NSString).pathExtension
                let storedFileName = "birth-\(practice)-\(languageCode)-\(UUID().uuidString).\(fileExtension)"
                let destinationURL = directoryURL.appendingPathComponent(storedFileName)
                try fileManager.moveItem(at: temporaryURL, to: destinationURL)

                let obsoletePracticeEntries = manifest.filter {
                    $0.birthPractice == practice && $0.key != key
                }
                obsoletePracticeEntries.forEach { entry in
                    try? fileManager.removeItem(
                        at: directoryURL.appendingPathComponent(entry.storedFileName)
                    )
                }
                manifest.removeAll { $0.birthPractice == practice && $0.key != key }
                manifest.removeAll { $0.key == key }
                manifest.append(
                    Entry(
                        cycleDay: nil,
                        pregnancyWeek: nil,
                        postpartumDay: nil,
                        birthPractice: practice,
                        languageCode: languageCode,
                        audioFileName: audioFileName,
                        storedFileName: storedFileName
                    )
                )
                availableKeys.insert(key)
                saveManifest(manifest)
            } catch {
                // Birth practices may be published independently; keep any completed downloads.
                continue
            }
        }

        let requestedPracticeSet = Set(requestedPractices)
        let obsoleteEntries = manifest.filter {
            guard let practice = $0.birthPractice else { return false }
            return !requestedPracticeSet.contains(practice)
        }
        obsoleteEntries.forEach { entry in
            try? fileManager.removeItem(at: directoryURL.appendingPathComponent(entry.storedFileName))
        }
        manifest.removeAll {
            guard let practice = $0.birthPractice else { return false }
            return !requestedPracticeSet.contains(practice)
        }
        saveManifest(manifest)

        return SyncResult(
            availableCount: availableKeys.count,
            requestedCount: requestedPractices.count
        )
    }

    func syncPostpartumPackage(days: [Int], language: AppLanguage) async -> SyncResult {
        let requestedDays = Array(
            days
                .filter(RemoteMeditationAudioSource.supportedPostpartumDays.contains)
                .prefix(OfflineMeditationPackagePlanner.maximumStoredDays)
        )
        guard !requestedDays.isEmpty else {
            return SyncResult(availableCount: 0, requestedCount: 0)
        }

        try? prepareDirectory()
        var manifest = loadManifest()
        var desiredKeys = Set<String>()
        var availableKeys = Set<String>()

        for day in requestedDays {
            guard !Task.isCancelled else { break }
            let source = RemoteMeditationAudioSource(
                postpartumDay: day,
                fallbackResourceName: "aya-demo-meditation-8m.m4a"
            )

            do {
                let metadata = try await RemoteMeditationContentLoader.loadMetadata(
                    source: source,
                    session: session
                )
                guard let audioFileName = metadata.audioFileName(for: language) else { continue }
                let languageCode = languageCode(for: language)
                let key = postpartumEntryKey(
                    day: day,
                    languageCode: languageCode,
                    audioFileName: audioFileName
                )
                desiredKeys.insert(key)

                if let existing = manifest.first(where: { $0.key == key }) {
                    let existingURL = directoryURL.appendingPathComponent(existing.storedFileName)
                    if fileManager.fileExists(atPath: existingURL.path) {
                        availableKeys.insert(key)
                        continue
                    }
                }

                let remoteURL = source.directoryURL.appendingPathComponent(audioFileName)
                let (temporaryURL, response) = try await session.download(from: remoteURL)
                try validate(response)

                let fileExtension = (audioFileName as NSString).pathExtension
                let storedFileName = "postpartum-\(day)-\(languageCode)-\(UUID().uuidString).\(fileExtension)"
                let destinationURL = directoryURL.appendingPathComponent(storedFileName)
                try fileManager.moveItem(at: temporaryURL, to: destinationURL)

                manifest.removeAll { $0.key == key }
                manifest.append(
                    Entry(
                        cycleDay: nil,
                        pregnancyWeek: nil,
                        postpartumDay: day,
                        birthPractice: nil,
                        languageCode: languageCode,
                        audioFileName: audioFileName,
                        storedFileName: storedFileName
                    )
                )
                availableKeys.insert(key)
                saveManifest(manifest)
            } catch {
                // Missing daily content is expected while future postpartum days are published.
                continue
            }
        }

        if let currentDay = requestedDays.first {
            let currentIsAvailable = manifest.contains { entry in
                entry.postpartumDay == currentDay
                    && entry.languageCode == languageCode(for: language)
                    && availableKeys.contains(entry.key)
            }
            if currentIsAvailable {
                let obsoleteEntries = manifest.filter {
                    $0.postpartumDay != nil && !desiredKeys.contains($0.key)
                }
                obsoleteEntries.forEach { entry in
                    try? fileManager.removeItem(
                        at: directoryURL.appendingPathComponent(entry.storedFileName)
                    )
                }
                manifest.removeAll {
                    $0.postpartumDay != nil && !desiredKeys.contains($0.key)
                }
                saveManifest(manifest)
            }
        }

        return SyncResult(
            availableCount: availableKeys.count,
            requestedCount: requestedDays.count
        )
    }

    func removeAll() {
        try? fileManager.removeItem(at: directoryURL)
    }

    nonisolated static func removeLegacyAutomaticCache(fileManager: FileManager = .default) {
        guard let cachesDirectory = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else { return }
        try? fileManager.removeItem(
            at: cachesDirectory.appendingPathComponent("HESIA/Meditations", isDirectory: true)
        )
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDirectoryURL = directoryURL
        try? mutableDirectoryURL.setResourceValues(values)
    }

    private func loadManifest() -> [Entry] {
        guard
            let data = try? Data(contentsOf: manifestURL),
            let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries
    }

    private func saveManifest(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }

    private func removeObsoletePregnancyEntries(keeping key: String, from manifest: inout [Entry]) {
        let obsoleteEntries = manifest.filter {
            $0.pregnancyWeek != nil && $0.key != key
        }
        obsoleteEntries.forEach { entry in
            try? fileManager.removeItem(at: directoryURL.appendingPathComponent(entry.storedFileName))
        }
        manifest.removeAll { $0.pregnancyWeek != nil && $0.key != key }
        saveManifest(manifest)
    }

    private func cycleEntryKey(day: Int, languageCode: String, audioFileName: String) -> String {
        "cycle-\(day)-\(languageCode)-\(audioFileName)"
    }

    private func pregnancyEntryKey(week: Int, languageCode: String, audioFileName: String) -> String {
        "pregnancy-\(week)-\(languageCode)-\(audioFileName)"
    }

    private func postpartumEntryKey(day: Int, languageCode: String, audioFileName: String) -> String {
        "postpartum-\(day)-\(languageCode)-\(audioFileName)"
    }

    private func birthEntryKey(
        practice: String,
        languageCode: String,
        audioFileName: String
    ) -> String {
        "birth-\(practice)-\(languageCode)-\(audioFileName)"
    }

    private func languageCode(for language: AppLanguage) -> String {
        switch language {
        case .turkish: "tr"
        case .english: "en"
        case .system: languageCode(for: .defaultExplicitLanguage)
        }
    }

    private func validate(_ response: URLResponse) throws {
        guard
            let response = response as? HTTPURLResponse,
            (200..<300).contains(response.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
    }
}

struct OfflineMeditationSettings: View {
    @AppStorage(OfflineMeditationPreferenceKeys.isEnabled) private var isEnabled = false
    @ObservedObject private var manager = OfflineMeditationManager.shared

    var body: some View {
        SettingsGroup("settings.offline.section") {
            SettingsToggleRow(
                icon: SettingsRowIcon(.headphones),
                titleKey: "settings.offline.title",
                value: SettingsRowValue(statusKey),
                isOn: $isEnabled
            )
            .accessibilityIdentifier("settings.offline.toggle")
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled {
                manager.removeDownloads()
            }
        }
    }

    private var statusKey: LocalizedStringKey {
        guard isEnabled else { return "settings.offline.description" }
        switch manager.state {
        case .idle:
            return "settings.offline.enabled"
        case .downloading:
            return "settings.offline.downloading"
        case .ready:
            return "settings.offline.ready"
        case .partial:
            return "settings.offline.partial"
        case .failed:
            return "settings.offline.failed"
        }
    }
}
