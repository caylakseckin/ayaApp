import Foundation

struct PregnancyContentProvider {
    func meditation(for calculation: PregnancyCalculation) -> DailyMeditation {
        DailyMeditation(
            id: "pregnancy-trimester-\(calculation.trimester.rawValue)",
            titleLocalizationKey: "pregnancy.meditation.\(calculation.trimester.rawValue).title",
            descriptionLocalizationKey: "pregnancy.meditation.\(calculation.trimester.rawValue).description",
            contextNameLocalizationKey: calculation.trimester.nameLocalizationKey,
            contextFormatLocalizationKey: "pregnancy.meditation.context_format",
            contextValue: calculation.currentWeek,
            durationMinutes: 9,
            voiceLocalizationKey: "meditation.voice.yaren",
            audioResourceName: "aya-demo-meditation-9m.m4a"
        )
    }
}
