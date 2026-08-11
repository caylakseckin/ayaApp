import Foundation

struct CycleCalculation: Equatable, Sendable {
    let currentCycleDay: Int
    let currentPhase: CyclePhase
    let phaseDay: Int
    let cycleProgress: Double
}

struct CycleCalculator: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func calculate(profile: CycleProfile, on date: Date = Date()) -> CycleCalculation {
        let startDate = calendar.startOfDay(for: profile.lastPeriodStartDate)
        let targetDate = calendar.startOfDay(for: date)
        let elapsedDays = calendar.dateComponents(
            [.day],
            from: startDate,
            to: targetDate
        ).day ?? 0
        // Dates before the stored start are projected backwards using the same
        // average. This is an estimated wellness view, not a clinical prediction.
        let zeroBasedCycleDay = (
            (elapsedDays % profile.averageCycleLength) + profile.averageCycleLength
        ) % profile.averageCycleLength
        let cycleDay = zeroBasedCycleDay + 1
        let phaseResult = phase(
            for: cycleDay,
            cycleLength: profile.averageCycleLength,
            periodDuration: profile.averagePeriodDuration
        )

        return CycleCalculation(
            currentCycleDay: cycleDay,
            currentPhase: phaseResult.phase,
            phaseDay: phaseResult.day,
            cycleProgress: Double(cycleDay) / Double(profile.averageCycleLength)
        )
    }

    func surroundingDays(currentDay: Int, cycleLength: Int, radius: Int = 5) -> [Int] {
        guard cycleLength > 0, radius >= 0 else { return [] }
        return (-radius...radius).map { offset in
            let zeroBasedDay = (currentDay - 1 + offset) % cycleLength
            return (zeroBasedDay + cycleLength) % cycleLength + 1
        }
    }

    private func phase(
        for cycleDay: Int,
        cycleLength: Int,
        periodDuration: Int
    ) -> (phase: CyclePhase, day: Int) {
        let normalizedPeriodDuration = min(max(1, periodDuration), cycleLength)

        if cycleDay <= normalizedPeriodDuration {
            return (.menstrual, cycleDay)
        }

        // This is a deterministic wellness-personalization estimate, not a
        // clinical ovulation prediction. The estimate is centered near
        // cycleLength - 14 and kept after the entered period duration.
        let estimatedOvulationDay = min(
            cycleLength,
            max(normalizedPeriodDuration + 1, cycleLength - 14)
        )
        let ovulatoryStart = min(
            cycleLength,
            max(normalizedPeriodDuration + 1, estimatedOvulationDay - 1)
        )
        let ovulatoryEnd = min(cycleLength, max(ovulatoryStart, estimatedOvulationDay + 1))

        if cycleDay < ovulatoryStart {
            return (.follicular, cycleDay - normalizedPeriodDuration)
        }

        if cycleDay <= ovulatoryEnd {
            return (.ovulatory, cycleDay - ovulatoryStart + 1)
        }

        return (.luteal, cycleDay - ovulatoryEnd)
    }
}
