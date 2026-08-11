import Foundation

struct MotherhoodMeditationProvider {
    func meditation(for range: MotherhoodAgeRange) -> DailyMeditation {
        DailyMeditation(
            id: "motherhood-\(range.rawValue)",
            titleLocalizationKey: range.meditationTitleLocalizationKey,
            descriptionLocalizationKey: range.meditationDescriptionLocalizationKey,
            contextNameLocalizationKey: range.meditationContextLocalizationKey,
            contextFormatLocalizationKey: "meditation.context.name_only",
            contextValue: 0,
            durationMinutes: 8,
            voiceLocalizationKey: "motherhood.meditation.voice",
            audioResourceName: "aya-demo-meditation-8m.m4a"
        )
    }
}
