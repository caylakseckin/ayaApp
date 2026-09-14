import AVFoundation
import Combine
import Foundation
import MediaPlayer
import UIKit

@MainActor
final class MeditationPlayerViewModel: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval
    @Published private(set) var playbackEnded = false
    @Published private(set) var isAudioLoaded = false
    @Published private(set) var isLoadingAudio = false
    @Published private(set) var isAudioUnavailable = false
    @Published private(set) var remoteTitle: String?
    @Published private(set) var remoteDescription: String?
    @Published private(set) var remoteNarrator: String?
    @Published private(set) var displayDurationMinutes: Int

    private var audioPlayer: AVAudioPlayer?
    private let requiresPremiumAccess: Bool
    private let premiumStore: PremiumStore
    private var premiumAccessCancellable: AnyCancellable?
    private let requiresRemoteAudio: Bool
    private let remoteAudioSource: RemoteMeditationAudioSource?
    private let language: AppLanguage
    private var audioPreparationTask: Task<Void, Never>?
    private var temporaryRemoteAudioURL: URL?
    private var shouldAutoPlay = false
    private var hasStartedAutoPlay = false
    private var progressTimer: Timer?
    private let timerInterval: TimeInterval = 0.25
    private var remoteCommandTargets: [(command: MPRemoteCommand, target: Any)] = []
    private var nowPlayingTitle = ""
    private var nowPlayingArtist = ""
    private var nowPlayingPhase = ""
    private var hasPublishedNowPlayingInfo = false
    private lazy var nowPlayingArtwork: MPMediaItemArtwork? = {
        guard let image = UIImage(named: "HESIANowPlayingArtwork") else { return nil }
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }()

    init(
        meditation: DailyMeditation,
        language: AppLanguage = AppLanguage.defaultExplicitLanguage,
        autoPlay: Bool = false,
        premiumStore: PremiumStore = .shared
    ) {
        duration = TimeInterval(meditation.durationMinutes * 60)
        displayDurationMinutes = meditation.durationMinutes
        requiresRemoteAudio = meditation.remoteAudioSource != nil
        remoteAudioSource = meditation.remoteAudioSource
        self.language = language
        self.premiumStore = premiumStore
        requiresPremiumAccess = meditation.requiresPremiumAccess
        shouldAutoPlay = autoPlay
        super.init()

        if requiresPremiumAccess {
            premiumAccessCancellable = premiumStore.$hasPremiumAccess
                .dropFirst()
                .sink { [weak self] allowed in
                    if !allowed { self?.stop() }
                }
            guard premiumStore.canUsePremiumNow else { return }
        }

        if let remoteAudioSource = meditation.remoteAudioSource {
            isLoadingAudio = true
            audioPreparationTask = Task { [weak self] in
                await self?.prepareRemoteAudio(
                    source: remoteAudioSource,
                    language: language
                )
            }
        } else {
            prepareAudio(named: meditation.audioResourceName)
        }
    }

    /// Retries remote audio preparation after a failure (backs the player's
    /// "Retry" button). No-op for bundled meditations.
    func retry() {
        guard !requiresPremiumAccess || premiumStore.canUsePremiumNow else { stop(); return }
        guard let remoteAudioSource else { return }
        let language = self.language
        audioPreparationTask?.cancel()
        isAudioUnavailable = false
        isLoadingAudio = true
        audioPreparationTask = Task { [weak self] in
            await self?.prepareRemoteAudio(
                source: remoteAudioSource,
                language: language
            )
        }
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    func configureNowPlaying(title: String, artist: String, phase: String) {
        nowPlayingTitle = remoteTitle ?? title
        nowPlayingArtist = remoteNarrator ?? artist
        nowPlayingPhase = phase

        if hasPublishedNowPlayingInfo {
            updateNowPlayingInfo()
        }
    }

    /// Starts playback automatically once — only when the player was opened via an
    /// intentional tap (autoPlay). No-op while loading, if already playing/started,
    /// or when remote audio isn't ready (the error/Retry state handles failures).
    func autoPlayIfReady() {
        guard shouldAutoPlay, !hasStartedAutoPlay, !isPlaying, !isLoadingAudio else { return }
        guard !(requiresRemoteAudio && !isAudioLoaded) else { return }
        hasStartedAutoPlay = true
        play()
    }

    func play() {
        guard !requiresPremiumAccess || premiumStore.canUsePremiumNow else { stop(); return }
        // A play request may arrive from the Watch while remote audio is still
        // loading. Keep that intent so preparation can start playback when ready.
        shouldAutoPlay = true
        guard !isPlaying else { return }
        guard
            !isLoadingAudio,
            !requiresRemoteAudio || isAudioLoaded
        else { return }

        if currentTime >= duration {
            seek(to: 0)
        }

        configureAudioSession()
        configureRemoteCommandsIfNeeded()
        audioPlayer?.play()
        playbackEnded = false
        isPlaying = true
        startProgressTimer()
        updateNowPlayingInfo()
    }

    func pause() {
        // Also cancels a pending automatic start when pause arrives during load.
        shouldAutoPlay = false
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
        updateNowPlayingInfo()
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func seek(to time: TimeInterval) {
        let clampedTime = min(max(time, 0), duration)
        currentTime = clampedTime
        audioPlayer?.currentTime = clampedTime
        playbackEnded = clampedTime >= duration

        if playbackEnded {
            audioPlayer?.pause()
            isPlaying = false
            stopProgressTimer()
        }

        if hasPublishedNowPlayingInfo {
            updateNowPlayingInfo()
        }
    }

    func seek(toProgress progress: Double) {
        seek(to: min(max(progress, 0), 1) * duration)
    }

    func skipBackward(seconds: TimeInterval = 5) {
        seek(to: currentTime - seconds)
    }

    func skipForward(seconds: TimeInterval = 5) {
        seek(to: currentTime + seconds)
    }

    func stop() {
        shouldAutoPlay = false
        audioPreparationTask?.cancel()
        audioPreparationTask = nil
        stopProgressTimer()
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        playbackEnded = false
        clearNowPlayingInfo()
        removeRemoteCommands()
        removeTemporaryRemoteAudio()

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func prepareAudio(named resourceName: String?) {
        guard
            let resourceName,
            let url = bundledAudioURL(for: resourceName)
        else { return }

        prepareAudio(at: url)
    }

    @discardableResult
    private func prepareAudio(at url: URL) -> Bool {
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return false }

        player.delegate = self
        player.prepareToPlay()
        player.enableRate = false
        audioPlayer = player
        isAudioLoaded = true

        if player.duration > 0 {
            duration = player.duration
        }
        return true
    }

    private func prepareRemoteAudio(
        source: RemoteMeditationAudioSource,
        language: AppLanguage
    ) async {
        let metadata: RemoteMeditationMetadata
        do {
            metadata = try await RemoteMeditationContentLoader.loadMetadata(source: source)
        } catch {
            guard !Task.isCancelled else {
                isLoadingAudio = false
                return
            }
            prepareAudio(named: source.fallbackResourceName)
            isAudioUnavailable = !isAudioLoaded
            isLoadingAudio = false
            audioPreparationTask = nil
            autoPlayIfReady()
            return
        }

        guard !Task.isCancelled else {
            isLoadingAudio = false
            return
        }

        remoteTitle = metadata.localizedTitle(for: language)
        remoteDescription = metadata.localizedDescription(for: language)
        remoteNarrator = metadata.narrator
        displayDurationMinutes = metadata.durationMinutes
        nowPlayingTitle = remoteTitle ?? nowPlayingTitle
        nowPlayingArtist = remoteNarrator ?? nowPlayingArtist

        do {
            let audioFile = try await RemoteMeditationContentLoader.loadAudio(
                metadata: metadata,
                source: source,
                language: language
            )
            guard !Task.isCancelled else {
                if audioFile.storage == .temporary {
                    try? FileManager.default.removeItem(at: audioFile.url)
                }
                isLoadingAudio = false
                return
            }
            if audioFile.storage == .temporary {
                temporaryRemoteAudioURL = audioFile.url
            }
            isAudioUnavailable = !prepareAudio(at: audioFile.url)
        } catch {
            guard !Task.isCancelled else {
                isLoadingAudio = false
                return
            }
            isAudioUnavailable = true
        }

        isLoadingAudio = false
        audioPreparationTask = nil

        if hasPublishedNowPlayingInfo {
            updateNowPlayingInfo()
        }

        autoPlayIfReady()
    }

    private func removeTemporaryRemoteAudio() {
        guard let temporaryRemoteAudioURL else { return }
        audioPlayer = nil
        try? FileManager.default.removeItem(at: temporaryRemoteAudioURL)
        self.temporaryRemoteAudioURL = nil
    }

    private func bundledAudioURL(for resourceName: String) -> URL? {
        let resource = resourceName as NSString
        let pathExtension = resource.pathExtension
        let name = resource.deletingPathExtension

        let bundles = [Bundle.main, Bundle(for: MeditationPlayerViewModel.self)]
        return bundles.lazy.compactMap { bundle in
            bundle.url(
                forResource: name,
                withExtension: pathExtension.isEmpty ? nil : pathExtension
            )
        }.first
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
    }

    private func configureRemoteCommandsIfNeeded() {
        guard remoteCommandTargets.isEmpty else { return }

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false

        register(commandCenter.playCommand) { player in
            player.play()
        }
        register(commandCenter.pauseCommand) { player in
            player.pause()
        }
        register(commandCenter.togglePlayPauseCommand) { player in
            player.togglePlayback()
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [5]
        register(commandCenter.skipBackwardCommand) { player in
            player.skipBackward()
        }

        commandCenter.skipForwardCommand.preferredIntervals = [5]
        register(commandCenter.skipForwardCommand) { player in
            player.skipForward()
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        let positionTarget = commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }

            Task { @MainActor [weak self] in
                self?.seek(to: positionEvent.positionTime)
            }
            return .success
        }
        remoteCommandTargets.append((commandCenter.changePlaybackPositionCommand, positionTarget))
    }

    private func register(
        _ command: MPRemoteCommand,
        action: @escaping @MainActor (MeditationPlayerViewModel) -> Void
    ) {
        command.isEnabled = true
        let target = command.addTarget { [weak self] _ in
            guard self != nil else { return .commandFailed }

            Task { @MainActor [weak self] in
                guard let self else { return }
                action(self)
            }
            return .success
        }
        remoteCommandTargets.append((command, target))
    }

    private func removeRemoteCommands() {
        for registration in remoteCommandTargets {
            registration.command.removeTarget(registration.target)
        }
        remoteCommandTargets.removeAll()
    }

    private func updateNowPlayingInfo() {
        let fallbackTitle = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleDisplayName"
        ) as? String ?? "HESIA"

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlayingTitle.isEmpty ? fallbackTitle : nowPlayingTitle,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]

        if !nowPlayingArtist.isEmpty {
            info[MPMediaItemPropertyArtist] = nowPlayingArtist
        }
        if !nowPlayingPhase.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = nowPlayingPhase
        }
        if let nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = nowPlayingArtwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        hasPublishedNowPlayingInfo = true
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        hasPublishedNowPlayingInfo = false
    }

    private func startProgressTimer() {
        stopProgressTimer()

        let timer = Timer(timeInterval: timerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard !requiresPremiumAccess || premiumStore.canUsePremiumNow else { stop(); return }
        guard isPlaying else { return }

        if let audioPlayer {
            currentTime = min(audioPlayer.currentTime, duration)
        } else {
            // Local content can ship before an audio file is assigned. Keeping the
            // transport deterministic lets the complete player UI remain testable.
            currentTime = min(currentTime + timerInterval, duration)
        }

        if currentTime >= duration {
            finishPlayback()
        }
    }

    private func finishPlayback() {
        stopProgressTimer()
        currentTime = duration
        audioPlayer?.currentTime = duration
        isPlaying = false
        playbackEnded = true
        updateNowPlayingInfo()
    }
}

extension MeditationPlayerViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.finishPlayback()
        }
    }
}

enum MeditationTimeFormatter {
    static func clock(_ time: TimeInterval) -> String {
        let totalSeconds = max(Int(time.rounded(.down)), 0)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
