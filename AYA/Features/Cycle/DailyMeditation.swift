import SwiftUI

struct DailyMeditation: Identifiable {
    let id: String
    let titleLocalizationKey: String
    let descriptionLocalizationKey: String
    let contextNameLocalizationKey: String
    let contextFormatLocalizationKey: String
    let contextValue: Int
    let durationMinutes: Int
    let voiceLocalizationKey: String
    let audioResourceName: String?
    let remoteAudioSource: RemoteMeditationAudioSource?

    var titleKey: LocalizedStringKey { LocalizedStringKey(titleLocalizationKey) }
    var descriptionKey: LocalizedStringKey { LocalizedStringKey(descriptionLocalizationKey) }
    var voiceKey: LocalizedStringKey { LocalizedStringKey(voiceLocalizationKey) }

    func localizedContext(language: AppLanguage, locale: Locale) -> String {
        let format = language.localizedString(forKey: contextFormatLocalizationKey)
        return String(
            format: format,
            locale: locale,
            language.localizedString(forKey: contextNameLocalizationKey),
            contextValue
        )
    }

    init(
        id: String,
        titleLocalizationKey: String,
        descriptionLocalizationKey: String,
        contextNameLocalizationKey: String,
        contextFormatLocalizationKey: String,
        contextValue: Int,
        durationMinutes: Int,
        voiceLocalizationKey: String,
        audioResourceName: String?,
        remoteAudioSource: RemoteMeditationAudioSource? = nil
    ) {
        self.id = id
        self.titleLocalizationKey = titleLocalizationKey
        self.descriptionLocalizationKey = descriptionLocalizationKey
        self.contextNameLocalizationKey = contextNameLocalizationKey
        self.contextFormatLocalizationKey = contextFormatLocalizationKey
        self.contextValue = contextValue
        self.durationMinutes = durationMinutes
        self.voiceLocalizationKey = voiceLocalizationKey
        self.audioResourceName = audioResourceName
        self.remoteAudioSource = remoteAudioSource
    }

    init(
        id: String,
        titleLocalizationKey: String,
        descriptionLocalizationKey: String,
        phase: CyclePhase,
        phaseDay: Int,
        durationMinutes: Int,
        voiceLocalizationKey: String,
        audioResourceName: String?,
        remoteAudioSource: RemoteMeditationAudioSource? = nil
    ) {
        self.init(
            id: id,
            titleLocalizationKey: titleLocalizationKey,
            descriptionLocalizationKey: descriptionLocalizationKey,
            contextNameLocalizationKey: phase.meditationContextNameLocalizationKey,
            contextFormatLocalizationKey: "cycle.phase.day_format",
            contextValue: phaseDay,
            durationMinutes: durationMinutes,
            voiceLocalizationKey: voiceLocalizationKey,
            audioResourceName: audioResourceName,
            remoteAudioSource: remoteAudioSource
        )
    }
}

struct DailyMeditationProvider {
    func meditation(
        for phase: CyclePhase,
        phaseDay: Int,
        cycleDay: Int? = nil
    ) -> DailyMeditation {
        let content: (title: String, description: String, duration: Int, audio: String)

        switch phase {
        case .menstrual:
            content = (
                "meditation.daily.menstrual.title",
                "meditation.daily.menstrual.description",
                7,
                "aya-demo-meditation-7m.m4a"
            )
        case .follicular:
            content = (
                "meditation.daily.follicular.title",
                "meditation.daily.follicular.description",
                8,
                "aya-demo-meditation-8m.m4a"
            )
        case .ovulatory:
            content = (
                "meditation.daily.ovulatory.title",
                "meditation.daily.ovulatory.description",
                9,
                "aya-demo-meditation-9m.m4a"
            )
        case .luteal:
            content = (
                "meditation.daily.luteal.title",
                "meditation.daily.luteal.description",
                8,
                "aya-demo-meditation-8m.m4a"
            )
        }

        let remoteAudioSource = cycleDay.flatMap { day -> RemoteMeditationAudioSource? in
            guard RemoteMeditationAudioSource.supportedCycleDays.contains(day) else { return nil }
            return RemoteMeditationAudioSource(
                cycleDay: day,
                fallbackResourceName: content.audio
            )
        }

        return DailyMeditation(
            id: "daily-\(phase.rawValue)-\(cycleDay ?? phaseDay)",
            titleLocalizationKey: content.title,
            descriptionLocalizationKey: content.description,
            phase: phase,
            phaseDay: phaseDay,
            durationMinutes: content.duration,
            voiceLocalizationKey: "meditation.voice.yaren",
            audioResourceName: content.audio,
            remoteAudioSource: remoteAudioSource
        )
    }
}
