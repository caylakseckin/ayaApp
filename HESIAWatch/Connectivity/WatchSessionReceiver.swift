import Foundation
import WatchConnectivity
import WidgetKit

@MainActor
final class WatchSessionReceiver: NSObject, ObservableObject {
    static let shared = WatchSessionReceiver()

    @Published private(set) var todaySession: WatchMeditationSession?
    @Published private(set) var isRequestingLatestPractice = false
    @Published private(set) var playbackState: WatchPlaybackState?

    private let connectivitySession: WCSession?
    private var requestResetTask: Task<Void, Never>?

    private override init() {
        Self.removeLegacyLocalAudio()
        todaySession = WatchMeditationSharedStore.load()
        connectivitySession = WCSession.isSupported() ? .default : nil
        super.init()
        connectivitySession?.delegate = self
        connectivitySession?.activate()
    }

    func activate() {
        connectivitySession?.activate()
        if let context = connectivitySession?.receivedApplicationContext {
            consumePractice(context)
            consumePlaybackState(context)
        }
        requestLatestPractice()
    }

    func requestLatestPractice(force: Bool = false) {
        guard
            force || todaySession == nil,
            let connectivitySession,
            connectivitySession.activationState == .activated,
            !isRequestingLatestPractice
        else { return }

        isRequestingLatestPractice = true
        requestResetTask?.cancel()
        requestResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.isRequestingLatestPractice = false
        }

        let request: [String: Any] = [
            WatchConnectivityPayload.requestLatestPracticeKey: true
        ]
        if connectivitySession.isReachable {
            connectivitySession.sendMessage(
                request,
                replyHandler: nil,
                errorHandler: { _ in connectivitySession.transferUserInfo(request) }
            )
        } else {
            connectivitySession.transferUserInfo(request)
        }
    }

    /// Sends a transient remote-control command. Audio always remains on iPhone.
    @discardableResult
    func sendPlaybackCommand(
        action: WatchPlaybackAction,
        sessionID: String,
        position: TimeInterval,
        completion: @escaping (Bool) -> Void
    ) -> Bool {
        guard
            let connectivitySession,
            connectivitySession.activationState == .activated,
            connectivitySession.isReachable,
            let data = try? JSONEncoder().encode(
                WatchPlaybackCommand(
                    sessionID: sessionID,
                    action: action,
                    position: position
                )
            )
        else { return false }

        connectivitySession.sendMessage(
            [WatchConnectivityPayload.playbackCommandKey: data],
            replyHandler: { [weak self] reply in
                let accepted = reply[WatchConnectivityPayload.playbackAcceptedKey] as? Bool
                    == true
                Task { @MainActor in
                    self?.consumePlaybackState(reply)
                    completion(accepted)
                }
            },
            errorHandler: { _ in
                Task { @MainActor in completion(false) }
            }
        )
        return true
    }

    private func consumePractice(_ payload: [String: Any]) {
        if payload[WatchConnectivityPayload.clearPracticeKey] as? Bool == true {
            todaySession = nil
            playbackState = nil
            WatchMeditationSharedStore.clear()
            finishRequest()
            WidgetCenter.shared.reloadTimelines(ofKind: "HESIAWatchWidget")
            return
        }

        guard
            let data = payload[WatchConnectivityPayload.sessionDataKey] as? Data,
            let session = try? JSONDecoder().decode(WatchMeditationSession.self, from: data),
            shouldAccept(session)
        else { return }

        if todaySession?.syncedAt == session.syncedAt {
            finishRequest()
            return
        }

        todaySession = session
        if playbackState?.sessionID != session.id {
            playbackState = nil
        }
        WatchMeditationSharedStore.save(session)
        finishRequest()
        WidgetCenter.shared.reloadTimelines(ofKind: "HESIAWatchWidget")
    }

    private func consumePlaybackState(_ payload: [String: Any]) {
        guard
            let data = payload[WatchConnectivityPayload.playbackStateKey] as? Data,
            let state = try? JSONDecoder().decode(WatchPlaybackState.self, from: data),
            state.sessionID == todaySession?.id
        else { return }
        playbackState = state
    }

    private func shouldAccept(_ incomingSession: WatchMeditationSession) -> Bool {
        guard let todaySession else { return true }
        return (incomingSession.syncedAt ?? .distantPast)
            >= (todaySession.syncedAt ?? .distantPast)
    }

    private func finishRequest() {
        requestResetTask?.cancel()
        requestResetTask = nil
        isRequestingLatestPractice = false
    }

    private static func removeLegacyLocalAudio() {
        let fileManager = FileManager.default
        guard let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return }
        let legacyAudioDirectory = applicationSupportURL.appendingPathComponent(
            "HESIA/WatchAudio",
            isDirectory: true
        )
        try? fileManager.removeItem(at: legacyAudioDirectory)
    }
}

extension WatchSessionReceiver: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        let context = session.receivedApplicationContext
        Task { @MainActor [weak self] in
            self?.consumePractice(context)
            self?.consumePlaybackState(context)
            self?.requestLatestPractice()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.consumePractice(applicationContext)
            self?.consumePlaybackState(applicationContext)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.consumePractice(message)
            self?.consumePlaybackState(message)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor [weak self] in
            self?.requestLatestPractice(force: true)
        }
    }
}

private enum WatchConnectivityPayload {
    static let sessionDataKey = "todayMeditationSession"
    static let requestLatestPracticeKey = "requestLatestPractice"
    static let clearPracticeKey = "clearTodayMeditationSession"
    static let playbackCommandKey = "playbackCommand"
    static let playbackStateKey = "playbackState"
    static let playbackAcceptedKey = "playbackAccepted"
}
