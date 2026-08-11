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
