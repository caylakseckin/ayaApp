import Foundation

struct PostpartumMeditationProvider {
    func meditation(for calculation: PostpartumCalculation) -> DailyMeditation {
        meditation(forDay: calculation.currentDay)
    }

    func meditation(forDay day: Int) -> DailyMeditation {
        let stage = PostpartumStage(day: day)
        let remoteAudioSource = RemoteMeditationAudioSource.supportedPostpartumDays
            .contains(day)
            ? RemoteMeditationAudioSource(
                postpartumDay: day,
                fallbackResourceName: "aya-demo-meditation-8m.m4a"
            )
            : nil

        return DailyMeditation(
            id: "postpartum-day-\(day)",
            titleLocalizationKey: stage.meditationTitleLocalizationKey,
            descriptionLocalizationKey: stage.meditationDescriptionLocalizationKey,
            contextNameLocalizationKey: PostpartumRecoveryStage(stage: stage).titleLocalizationKey,
            contextFormatLocalizationKey: "postpartum.meditation.metadata",
            contextValue: day,
            durationMinutes: 8,
            voiceLocalizationKey: "meditation.voice.yaren",
            audioResourceName: "aya-demo-meditation-8m.m4a",
            remoteAudioSource: remoteAudioSource
        )
    }
}
