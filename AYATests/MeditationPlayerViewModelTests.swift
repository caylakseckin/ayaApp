import SwiftUI
import XCTest
@testable import HESIA

final class MeditationPlayerViewModelTests: XCTestCase {
    func testPlayerDismissalRequiresDeliberateDownwardDrag() {
        XCTAssertFalse(
            MeditationPlayerDismissalPolicy.shouldDismiss(
                translationWidth: 8,
                translationHeight: 175,
                predictedTranslationHeight: 190,
                viewportHeight: 852
            )
        )
        XCTAssertTrue(
            MeditationPlayerDismissalPolicy.shouldDismiss(
                translationWidth: 12,
                translationHeight: 210,
                predictedTranslationHeight: 225,
                viewportHeight: 852
            )
        )
        XCTAssertTrue(
            MeditationPlayerDismissalPolicy.shouldDismiss(
                translationWidth: 10,
                translationHeight: 115,
                predictedTranslationHeight: 320,
                viewportHeight: 852
            )
        )
    }

    func testPlayerDismissalRejectsHorizontalAndUpwardDrags() {
        XCTAssertFalse(
            MeditationPlayerDismissalPolicy.shouldDismiss(
                translationWidth: 190,
                translationHeight: 160,
                predictedTranslationHeight: 220,
                viewportHeight: 852
            )
        )
        XCTAssertFalse(
            MeditationPlayerDismissalPolicy.shouldDismiss(
                translationWidth: 0,
                translationHeight: -180,
                predictedTranslationHeight: -240,
                viewportHeight: 852
            )
        )
    }

    @MainActor
    func testPlayerStartsPausedAtBeginning() {
        let viewModel = MeditationPlayerViewModel(meditation: meditation)

        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(viewModel.currentTime, 0)
        XCTAssertEqual(viewModel.duration, 480)
        XCTAssertFalse(viewModel.playbackEnded)
    }

    @MainActor
    func testSeekingAndSkippingClampToDuration() {
        let viewModel = MeditationPlayerViewModel(meditation: meditation)

        viewModel.seek(to: 478)
        viewModel.skipForward()

        XCTAssertEqual(viewModel.currentTime, 480)
        XCTAssertTrue(viewModel.playbackEnded)
        XCTAssertFalse(viewModel.isPlaying)

        viewModel.skipBackward()

        XCTAssertEqual(viewModel.currentTime, 475)
        XCTAssertFalse(viewModel.playbackEnded)
    }

    @MainActor
    func testBothPlaybackControlsCanShareToggleState() {
        let viewModel = MeditationPlayerViewModel(meditation: meditation)

        viewModel.togglePlayback()
        XCTAssertTrue(viewModel.isPlaying)

        viewModel.togglePlayback()
        XCTAssertFalse(viewModel.isPlaying)
    }

    @MainActor
    func testStopResetsPlayback() {
        let viewModel = MeditationPlayerViewModel(meditation: meditation)
        viewModel.seek(to: 133)
        viewModel.play()

        viewModel.stop()

        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(viewModel.currentTime, 0)
        XCTAssertFalse(viewModel.playbackEnded)
    }

    func testClockFormatting() {
        XCTAssertEqual(MeditationTimeFormatter.clock(0), "00:00")
        XCTAssertEqual(MeditationTimeFormatter.clock(133), "02:13")
        XCTAssertEqual(MeditationTimeFormatter.clock(480), "08:00")
    }

    func testCycleMeditationUsesRemoteContentForSupportedDays() {
        let meditation = DailyMeditationProvider().meditation(
            for: .menstrual,
            phaseDay: 1,
            cycleDay: 1
        )

        XCTAssertEqual(meditation.remoteAudioSource?.cycleDay, 1)
        XCTAssertEqual(
            meditation.remoteAudioSource?.metadataURL.absoluteString,
            "https://hesia.app/content/menstrual_cycle/day_01/metadata.json"
        )
    }

    func testCycleMeditationFallsBackLocallyOutsideRemoteDayRange() {
        let meditation = DailyMeditationProvider().meditation(
            for: .luteal,
            phaseDay: 1,
            cycleDay: 36
        )

        XCTAssertNil(meditation.remoteAudioSource)
        XCTAssertNotNil(meditation.audioResourceName)
    }

    func testPregnancyMeditationUsesWeeklyRemoteContent() {
        let calculation = PregnancyCalculation(
            currentWeek: 18,
            trimester: .second,
            progress: 0.45
        )

        let meditation = PregnancyContentProvider().meditation(for: calculation)

        XCTAssertEqual(meditation.id, "pregnancy-week-18")
        XCTAssertEqual(meditation.remoteAudioSource?.pregnancyWeek, 18)
        XCTAssertEqual(
            meditation.remoteAudioSource?.metadataURL.absoluteString,
            "https://hesia.app/content/pregnancy/week_18/metadata.json"
        )
        XCTAssertNotNil(meditation.audioResourceName)
    }

    func testPregnancyMetadataDecodesWeekSchema() throws {
        let data = Data(
            #"{"id":"pregnancy_week_18","week":18,"audio":{"tr":"tr.mp3","en":"en.mp3"},"title":{"tr":"Başlık","en":"Title"},"description":{"tr":"Açıklama","en":"Description"},"duration_minutes":5,"narrator":"Yaren"}"#.utf8
        )

        let metadata = try JSONDecoder().decode(RemoteMeditationMetadata.self, from: data)

        XCTAssertEqual(metadata.week, 18)
        XCTAssertNil(metadata.day)
        XCTAssertEqual(metadata.audioFileName(for: .turkish), "tr.mp3")
        XCTAssertEqual(metadata.localizedTitle(for: .english), "Title")
    }

    func testBirthMeditationUsesPracticeRemoteContent() {
        let source = RemoteMeditationAudioSource(birthPractice: "flower_breath")

        XCTAssertEqual(source.birthPractice, "flower_breath")
        XCTAssertNil(source.fallbackResourceName)
        XCTAssertEqual(
            source.metadataURL.absoluteString,
            "https://hesia.app/content/birth/flower_breath/metadata.json"
        )
    }

    func testBirthMetadataDecodesPracticeSchema() throws {
        let data = Data(
            #"{"id":"birth_flower_breath","practice":"flower_breath","audio":{"tr":"birth_flower_breath_tr.m4a","en":""},"title":{"tr":"Çiçek Nefesi","en":"Flower Breath"},"description":{"tr":"Açıklama","en":"Description"},"duration_minutes":5,"narrator":"Yaren"}"#.utf8
        )

        let metadata = try JSONDecoder().decode(RemoteMeditationMetadata.self, from: data)

        XCTAssertEqual(metadata.practice, "flower_breath")
        XCTAssertEqual(metadata.audioFileName(for: .turkish), "birth_flower_breath_tr.m4a")
        XCTAssertNil(metadata.audioFileName(for: .english))
    }

    func testPostpartumMeditationUsesDailyRemoteContent() {
        let calculation = PostpartumCalculation(
            currentDay: 18,
            stage: .earlyPostpartum,
            progress: 0.2
        )

        let meditation = PostpartumMeditationProvider().meditation(for: calculation)

        XCTAssertEqual(meditation.id, "postpartum-day-18")
        XCTAssertEqual(meditation.remoteAudioSource?.postpartumDay, 18)
        XCTAssertEqual(
            meditation.remoteAudioSource?.metadataURL.absoluteString,
            "https://hesia.app/content/postpartum/day_18/metadata.json"
        )
        XCTAssertNotNil(meditation.audioResourceName)
    }

    func testPostpartumMeditationFallsBackLocallyAfterDayNinety() {
        let calculation = PostpartumCalculation(
            currentDay: 91,
            stage: .newRhythm,
            progress: 1
        )

        let meditation = PostpartumMeditationProvider().meditation(for: calculation)

        XCTAssertNil(meditation.remoteAudioSource)
        XCTAssertNotNil(meditation.audioResourceName)
    }

    func testWatchMeditationStoreClearsCachedPractice() throws {
        let suiteName = "WatchMeditationSharedStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let session = WatchMeditationSession(
            id: "pregnancy-week-4",
            title: "Biraz Daha Yavaş",
            stageKey: "watch.stage.pregnancy",
            week: 4,
            duration: 240,
            narrator: "Yaren",
            syncedAt: Date()
        )

        XCTAssertTrue(WatchMeditationSharedStore.save(session, defaults: defaults))
        XCTAssertEqual(WatchMeditationSharedStore.load(defaults: defaults)?.id, session.id)
        XCTAssertEqual(
            WatchMeditationSharedStore.load(defaults: defaults)?.narrator,
            session.narrator
        )

        WatchMeditationSharedStore.clear(defaults: defaults)

        XCTAssertNil(WatchMeditationSharedStore.load(defaults: defaults))
    }

    @MainActor
    func testDailyMeditationsLoadBundledDemoAudio() {
        for phase in CyclePhase.allCases {
            let meditation = DailyMeditationProvider().meditation(for: phase, phaseDay: 1)
            let viewModel = MeditationPlayerViewModel(meditation: meditation)

            XCTAssertNotNil(meditation.audioResourceName)
            XCTAssertTrue(viewModel.isAudioLoaded, "Audio failed to load for \(phase.rawValue)")
            XCTAssertEqual(
                viewModel.duration,
                TimeInterval(meditation.durationMinutes * 60),
                accuracy: 0.2
            )
            viewModel.stop()
        }
    }

    @MainActor
    func testAutoPlayStartsPlaybackOnceWhenRequested() {
        let viewModel = MeditationPlayerViewModel(meditation: meditation, autoPlay: true)

        // Not playing until the view asks (mirrors .onAppear).
        XCTAssertFalse(viewModel.isPlaying)

        viewModel.autoPlayIfReady()
        XCTAssertTrue(viewModel.isPlaying)

        // Idempotent: a second trigger must not restart or crash.
        viewModel.autoPlayIfReady()
        XCTAssertTrue(viewModel.isPlaying)
    }

    @MainActor
    func testAutoPlayDoesNothingWhenNotRequested() {
        let viewModel = MeditationPlayerViewModel(meditation: meditation)

        viewModel.autoPlayIfReady()

        XCTAssertFalse(viewModel.isPlaying)
    }

    private var meditation: DailyMeditation {
        DailyMeditation(
            id: "test-meditation",
            titleLocalizationKey: "meditation.daily.luteal.title",
            descriptionLocalizationKey: "meditation.daily.luteal.description",
            phase: .luteal,
            phaseDay: 6,
            durationMinutes: 8,
            voiceLocalizationKey: "meditation.voice.yaren",
            audioResourceName: nil
        )
    }
}
