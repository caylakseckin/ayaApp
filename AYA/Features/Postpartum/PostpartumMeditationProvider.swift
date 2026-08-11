import Foundation

struct PostpartumMeditationProvider {
    func meditation(for calculation: PostpartumCalculation) -> DailyMeditation {
        DailyMeditation(
            id: "postpartum-\(calculation.stage.rawValue)",
            titleLocalizationKey: calculation.stage.meditationTitleLocalizationKey,
            descriptionLocalizationKey: calculation.stage.meditationDescriptionLocalizationKey,
            contextNameLocalizationKey: calculation.stage.titleLocalizationKey,
            contextFormatLocalizationKey: "postpartum.meditation.context_format",
            contextValue: calculation.currentDay,
            durationMinutes: 8,
            voiceLocalizationKey: "meditation.voice.yaren",
            audioResourceName: "aya-demo-meditation-8m.m4a"
        )
    }
}
