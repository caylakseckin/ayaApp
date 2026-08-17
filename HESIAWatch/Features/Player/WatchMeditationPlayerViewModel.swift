import Foundation

/// A thin remote control for the iPhone meditation player.
/// The Watch never downloads, prepares, or plays meditation audio.
@MainActor
final class WatchMeditationPlayerViewModel: ObservableObject {
    @Published private(set) var currentTime: TimeInterval
    @Published private(set) var duration: TimeInterval
    @Published private(set) var isPlaying: Bool
    @Published private(set) var isLoading = false
    @Published private(set) var isPhoneUnavailable = false

    let session: WatchMeditationSession
    private var progressTimer: Timer?

    init(
        session: WatchMeditationSession,
        currentTime: TimeInterval = 0,
        isPlaying: Bool = false
    ) {
        self.session = session
        self.currentTime = min(max(currentTime, 0), session.duration)
        duration = session.duration
        self.isPlaying = isPlaying
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    func prepareAndPlay() {
        start()
    }

    func start() {
        guard !isPlaying else { return }
        if currentTime >= duration {
            currentTime = 0
        }

        let sent = sendCommand(.play) { [weak self] accepted in
            guard let self, !accepted else { return }
            self.isPlaying = false
            self.isPhoneUnavailable = true
            self.stopProgressTimer()
        }
        guard sent else {
            isPhoneUnavailable = true
            return
        }

        // Immediate feedback on the Watch. The iPhone's authoritative state
        // follows through WCSession and corrects this snapshot if needed.
        isPhoneUnavailable = false
        isPlaying = true
        startProgressTimer()
    }

    func togglePlayback() {
        isPlaying ? pause() : start()
    }

    func pause() {
        guard isPlaying else { return }
        let sent = sendCommand(.pause) { [weak self] accepted in
            guard let self, !accepted else { return }
            self.isPhoneUnavailable = true
        }
        guard sent else {
            isPhoneUnavailable = true
            return
        }

        isPhoneUnavailable = false
        isPlaying = false
        stopProgressTimer()
    }

    func skip(by seconds: TimeInterval) {
        let previousTime = currentTime
        currentTime = min(max(currentTime + seconds, 0), duration)

        let sent = sendCommand(.seek) { [weak self] accepted in
            guard let self, !accepted else { return }
            self.currentTime = previousTime
            self.isPhoneUnavailable = true
        }
        guard sent else {
            currentTime = previousTime
            isPhoneUnavailable = true
            return
        }

        isPhoneUnavailable = false
    }

    func applyRemotePlaybackState(_ state: WatchPlaybackState) {
        guard state.sessionID == session.id else { return }
        isLoading = false
        isPhoneUnavailable = false
        duration = max(state.duration, 1)
        currentTime = min(max(state.position, 0), duration)
        isPlaying = state.isPlaying
        state.isPlaying ? startProgressTimer() : stopProgressTimer()
    }

    func stopObserving() {
        stopProgressTimer()
    }

    @discardableResult
    private func sendCommand(
        _ action: WatchPlaybackAction,
        completion: @escaping (Bool) -> Void
    ) -> Bool {
        WatchSessionReceiver.shared.sendPlaybackCommand(
            action: action,
            sessionID: session.id,
            position: currentTime,
            completion: completion
        )
    }

    private func startProgressTimer() {
        guard progressTimer == nil else { return }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.currentTime = min(self.currentTime + 0.5, self.duration)
                if self.currentTime >= self.duration {
                    self.isPlaying = false
                    self.stopProgressTimer()
                }
            }
        }
        RunLoop.main.add(progressTimer!, forMode: .common)
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
