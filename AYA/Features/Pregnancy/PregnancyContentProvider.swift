import Foundation

struct PregnancyContentProvider {
    func meditation(for calculation: PregnancyCalculation) -> DailyMeditation {
        meditation(forWeek: calculation.currentWeek)
    }

    func meditation(forWeek week: Int) -> DailyMeditation {
        let trimester = PregnancyTrimester(week: week)
        let fallbackResourceName = "aya-demo-meditation-9m.m4a"
        let remoteAudioSource = RemoteMeditationAudioSource.supportedPregnancyWeeks
            .contains(week)
            ? RemoteMeditationAudioSource(
                pregnancyWeek: week,
                fallbackResourceName: fallbackResourceName
            )
            : nil

        return DailyMeditation(
            id: "pregnancy-week-\(week)",
            titleLocalizationKey: "pregnancy.meditation.\(trimester.rawValue).title",
            descriptionLocalizationKey: "pregnancy.meditation.\(trimester.rawValue).description",
            contextNameLocalizationKey: trimester.nameLocalizationKey,
            contextFormatLocalizationKey: "pregnancy.meditation.metadata",
            contextValue: week,
            durationMinutes: 9,
            voiceLocalizationKey: "meditation.voice.yaren",
            audioResourceName: fallbackResourceName,
            remoteAudioSource: remoteAudioSource
        )
    }
}
