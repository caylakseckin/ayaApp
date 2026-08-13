import Foundation

struct PregnancyContentProvider {
    func meditation(for calculation: PregnancyCalculation) -> DailyMeditation {
        let fallbackResourceName = "aya-demo-meditation-9m.m4a"
        let remoteAudioSource = RemoteMeditationAudioSource.supportedPregnancyWeeks
            .contains(calculation.currentWeek)
            ? RemoteMeditationAudioSource(
                pregnancyWeek: calculation.currentWeek,
                fallbackResourceName: fallbackResourceName
            )
            : nil

        return DailyMeditation(
            id: "pregnancy-week-\(calculation.currentWeek)",
            titleLocalizationKey: "pregnancy.meditation.\(calculation.trimester.rawValue).title",
            descriptionLocalizationKey: "pregnancy.meditation.\(calculation.trimester.rawValue).description",
            contextNameLocalizationKey: calculation.trimester.nameLocalizationKey,
            contextFormatLocalizationKey: "pregnancy.meditation.context_format",
            contextValue: calculation.currentWeek,
            durationMinutes: 9,
            voiceLocalizationKey: "meditation.voice.yaren",
            audioResourceName: fallbackResourceName,
            remoteAudioSource: remoteAudioSource
        )
    }
}
