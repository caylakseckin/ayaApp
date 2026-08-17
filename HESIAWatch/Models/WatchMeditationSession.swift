import Foundation

struct WatchMeditationSession: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let stageKey: String
    let detailText: String?
    let week: Int
    let duration: TimeInterval
    let narrator: String?
    var syncedAt: Date? = nil

    init(
        id: String,
        title: String,
        stageKey: String,
        detailText: String? = nil,
        week: Int,
        duration: TimeInterval,
        narrator: String?,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.stageKey = stageKey
        self.detailText = detailText
        self.week = week
        self.duration = duration
        self.narrator = narrator
        self.syncedAt = syncedAt
    }

    var durationMinutes: Int {
        max(1, Int(duration / 60))
    }

    var displayWeek: Int {
        min(max(week, 4), 42)
    }

}

enum WatchPlaybackAction: String, Codable, Hashable, Sendable {
    case play
    case pause
    case seek
}

struct WatchPlaybackCommand: Codable, Hashable, Sendable {
    let sessionID: String
    let action: WatchPlaybackAction
    let position: TimeInterval
}

struct WatchPlaybackState: Codable, Hashable, Sendable {
    let sessionID: String
    let isPlaying: Bool
    let position: TimeInterval
    let duration: TimeInterval
}

enum WatchMeditationSharedStore {
    static let appGroupIdentifier = "group.com.ayameditation.app.watch"
    static let sessionKey = "watch.todayMeditation.session"

    static func load(defaults: UserDefaults? = nil) -> WatchMeditationSession? {
        let defaults = defaults ?? UserDefaults(suiteName: appGroupIdentifier)
        guard let data = defaults?.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(WatchMeditationSession.self, from: data)
    }

    @discardableResult
    static func save(
        _ session: WatchMeditationSession,
        defaults: UserDefaults? = nil
    ) -> Bool {
        let defaults = defaults ?? UserDefaults(suiteName: appGroupIdentifier)
        guard let data = try? JSONEncoder().encode(session) else { return false }
        defaults?.set(data, forKey: sessionKey)
        return true
    }

    static func clear(defaults: UserDefaults? = nil) {
        let defaults = defaults ?? UserDefaults(suiteName: appGroupIdentifier)
        defaults?.removeObject(forKey: sessionKey)
    }
}

enum HESIAWatchConfiguration {
    /// Keep both localizations complete while the initial product release is Turkish-only.
    static let supportsMultipleLanguages = false

    static var locale: Locale {
        supportsMultipleLanguages ? .autoupdatingCurrent : Locale(identifier: "tr")
    }

    static func localizedString(forKey key: String) -> String {
        let languageCode = supportsMultipleLanguages
            ? (locale.language.languageCode?.identifier ?? "tr")
            : "tr"
        guard
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
