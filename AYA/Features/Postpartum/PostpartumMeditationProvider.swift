import Foundation

struct PostpartumMeditationProvider {
    func meditation(for calculation: PostpartumCalculation) -> DailyMeditation {
        let remoteAudioSource = RemoteMeditationAudioSource.supportedPostpartumDays
            .contains(calculation.currentDay)
            ? RemoteMeditationAudioSource(
                postpartumDay: calculation.currentDay,
                fallbackResourceName: "aya-demo-meditation-8m.m4a"
            )
            : nil

        return DailyMeditation(
            id: "postpartum-day-\(calculation.currentDay)",
            titleLocalizationKey: calculation.stage.meditationTitleLocalizationKey,
            descriptionLocalizationKey: calculation.stage.meditationDescriptionLocalizationKey,
            contextNameLocalizationKey: calculation.stage.titleLocalizationKey,
            contextFormatLocalizationKey: "postpartum.meditation.context_format",
            contextValue: calculation.currentDay,
            durationMinutes: 8,
            voiceLocalizationKey: "meditation.voice.yaren",
            audioResourceName: "aya-demo-meditation-8m.m4a",
            remoteAudioSource: remoteAudioSource
        )
    }
}
