import Foundation

struct CycleProfile: Equatable, Sendable {
    let lastPeriodStartDate: Date
    let averageCycleLength: Int
    let averagePeriodDuration: Int

    init?(
        lastPeriodStartDate: Date,
        averageCycleLength: Int,
        averagePeriodDuration: Int,
        calendar: Calendar = .current
    ) {
        guard
            (15...60).contains(averageCycleLength),
            (1...15).contains(averagePeriodDuration),
            averagePeriodDuration <= averageCycleLength
        else { return nil }

        self.lastPeriodStartDate = calendar.startOfDay(for: lastPeriodStartDate)
        self.averageCycleLength = averageCycleLength
        self.averagePeriodDuration = averagePeriodDuration
    }
}

struct CyclePeriodHistoryMutation: Identifiable, Equatable {
    let id = UUID()
    fileprivate let previousLastPeriodTimestamp: Double?
    fileprivate let previousHistoryTimestamps: [Double]?
}

enum CyclePeriodHistoryStore {
    private static let maximumStoredStarts = 24

    static func migrateLegacyStartDate(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        guard timestamps(defaults: defaults).isEmpty,
              defaults.object(forKey: CyclePersistenceKeys.lastPeriodStartDate) != nil
        else { return }

        let legacyDate = Date(
            timeIntervalSince1970: defaults.double(forKey: CyclePersistenceKeys.lastPeriodStartDate)
        )
        defaults.set(
            [calendar.startOfDay(for: legacyDate).timeIntervalSince1970],
            forKey: CyclePersistenceKeys.periodStartHistory
        )
    }

    static func dates(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) -> [Date] {
        timestamps(defaults: defaults)
            .map { calendar.startOfDay(for: Date(timeIntervalSince1970: $0)) }
            .sorted()
    }

    static func setCurrentStart(
        _ date: Date,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        let normalizedDate = calendar.startOfDay(for: date)
        guard normalizedDate <= calendar.startOfDay(for: now) else { return }

        var updatedDates = dates(defaults: defaults, calendar: calendar)
        if defaults.object(forKey: CyclePersistenceKeys.lastPeriodStartDate) != nil {
            let previousCurrent = Date(
                timeIntervalSince1970: defaults.double(
                    forKey: CyclePersistenceKeys.lastPeriodStartDate
                )
            )
            updatedDates.removeAll { calendar.isDate($0, inSameDayAs: previousCurrent) }
        }
        updatedDates.removeAll { calendar.isDate($0, inSameDayAs: normalizedDate) }
        updatedDates.append(normalizedDate)
        updatedDates.sort()
        updatedDates = Array(updatedDates.suffix(maximumStoredStarts))

        defaults.set(
            updatedDates.map(\.timeIntervalSince1970),
            forKey: CyclePersistenceKeys.periodStartHistory
        )
        defaults.set(
            normalizedDate.timeIntervalSince1970,
            forKey: CyclePersistenceKeys.lastPeriodStartDate
        )
    }

    @discardableResult
    static func record(
        _ date: Date,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> CyclePeriodHistoryMutation? {
        let normalizedDate = calendar.startOfDay(for: date)
        guard normalizedDate <= calendar.startOfDay(for: now) else { return nil }

        let previousHistory = rawTimestamps(defaults: defaults)
        let previousLastPeriodTimestamp = defaults.object(
            forKey: CyclePersistenceKeys.lastPeriodStartDate
        ).map { _ in defaults.double(forKey: CyclePersistenceKeys.lastPeriodStartDate) }

        var updatedDates = dates(defaults: defaults, calendar: calendar)
        guard !updatedDates.contains(where: { calendar.isDate($0, inSameDayAs: normalizedDate) }) else {
            return nil
        }

        updatedDates.append(normalizedDate)
        updatedDates.sort()
        updatedDates = Array(updatedDates.suffix(maximumStoredStarts))
        defaults.set(
            updatedDates.map(\.timeIntervalSince1970),
            forKey: CyclePersistenceKeys.periodStartHistory
        )

        if let currentTimestamp = previousLastPeriodTimestamp {
            let currentDate = calendar.startOfDay(for: Date(timeIntervalSince1970: currentTimestamp))
            if normalizedDate > currentDate {
                defaults.set(
                    normalizedDate.timeIntervalSince1970,
                    forKey: CyclePersistenceKeys.lastPeriodStartDate
                )
            }
        } else {
            defaults.set(
                normalizedDate.timeIntervalSince1970,
                forKey: CyclePersistenceKeys.lastPeriodStartDate
            )
        }

        return CyclePeriodHistoryMutation(
            previousLastPeriodTimestamp: previousLastPeriodTimestamp,
            previousHistoryTimestamps: previousHistory
        )
    }

    static func restore(
        _ mutation: CyclePeriodHistoryMutation,
        defaults: UserDefaults = .standard
    ) {
        if let previousHistoryTimestamps = mutation.previousHistoryTimestamps {
            defaults.set(
                previousHistoryTimestamps,
                forKey: CyclePersistenceKeys.periodStartHistory
            )
        } else {
            defaults.removeObject(forKey: CyclePersistenceKeys.periodStartHistory)
        }

        if let previousLastPeriodTimestamp = mutation.previousLastPeriodTimestamp {
            defaults.set(
                previousLastPeriodTimestamp,
                forKey: CyclePersistenceKeys.lastPeriodStartDate
            )
        } else {
            defaults.removeObject(forKey: CyclePersistenceKeys.lastPeriodStartDate)
        }
    }

    private static func timestamps(defaults: UserDefaults) -> [Double] {
        rawTimestamps(defaults: defaults) ?? []
    }

    private static func rawTimestamps(defaults: UserDefaults) -> [Double]? {
        guard let values = defaults.array(forKey: CyclePersistenceKeys.periodStartHistory) else {
            return nil
        }
        return values.compactMap { ($0 as? NSNumber)?.doubleValue }
    }
}
