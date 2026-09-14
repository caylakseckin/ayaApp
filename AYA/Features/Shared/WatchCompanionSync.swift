import Foundation
import Combine
import WatchConnectivity

@MainActor
final class WatchPlaybackCoordinator: ObservableObject {
    static let shared = WatchPlaybackCoordinator()

    @Published var isPlayerPresented = false
    private(set) var playbackSession: MeditationPlaybackSession?

    private var statePublishingCancellable: AnyCancellable?

    private init() {}

    /// Makes sessions started from any iPhone life-stage screen visible and
    /// controllable on the paired Watch as well.
    func register(_ session: MeditationPlaybackSession) {
        guard playbackSession !== session else { return }
        playbackSession = session
        startPublishingState()
        publishCurrentState()
    }

    @discardableResult
    func handle(
        _ command: WatchPlaybackCommand,
        meditation: DailyMeditation,
        language: AppLanguage
    ) -> Bool {
        guard meditation.id == command.sessionID else { return false }
        guard !meditation.requiresPremiumAccess || PremiumStore.shared.canUsePremiumNow else {
            resetForLocalDataReset()
            return false
        }

        if playbackSession?.meditation.id != meditation.id {
            playbackSession?.viewModel.stop()
            playbackSession = MeditationPlaybackSession(
                meditation: meditation,
                language: language,
                registersWithWatch: false
            )
            startPublishingState()
        }

        guard let viewModel = playbackSession?.viewModel else { return false }

        switch command.action {
        case .play:
            isPlayerPresented = true
            viewModel.play()
        case .pause:
            viewModel.pause()
        case .seek:
            viewModel.seek(to: command.position)
        }

        publishCurrentState()
        return true
    }

    private func startPublishingState() {
        statePublishingCancellable?.cancel()
        guard let playbackSession else { return }

        let sessionID = playbackSession.meditation.id
        let viewModel = playbackSession.viewModel
        statePublishingCancellable = Publishers.CombineLatest3(
            viewModel.$isPlaying,
            viewModel.$currentTime,
            viewModel.$duration
        )
        .map { isPlaying, position, duration in
            WatchPlaybackState(
                sessionID: sessionID,
                isPlaying: isPlaying,
                position: position,
                duration: duration
            )
        }
        .removeDuplicates()
        .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)
        .sink { state in
            Task { @MainActor in
                WatchCompanionSync.shared.sendPlaybackState(state)
            }
        }
    }

    private func publishCurrentState() {
        guard let playbackSession else { return }
        let viewModel = playbackSession.viewModel
        WatchCompanionSync.shared.sendPlaybackState(
            WatchPlaybackState(
                sessionID: playbackSession.meditation.id,
                isPlaying: viewModel.isPlaying,
                position: viewModel.currentTime,
                duration: viewModel.duration
            )
        )
    }

    func resetForLocalDataReset() {
        playbackSession?.viewModel.stop()
        playbackSession = nil
        isPlayerPresented = false
        statePublishingCancellable?.cancel()
        statePublishingCancellable = nil
    }
}

final class WatchCompanionSync: NSObject {
    static let shared = WatchCompanionSync()

    private struct CurrentPractice {
        let meditation: DailyMeditation
        let stageKey: String
        let detailText: String
        let periodValue: Int
    }

    private enum PersistenceKeys {
        static let sessionData = "watch.latestPregnancy.sessionData"
    }

    private let connectivitySession: WCSession?
    private var pendingSessionData: Data?
    private var practiceRefreshTask: Task<Void, Never>?
    private var latestSessionData: Data?
    private var latestPlaybackStateData: Data?

    private override init() {
        connectivitySession = WCSession.isSupported() ? .default : nil
        super.init()
        restorePersistedPractice()
        connectivitySession?.delegate = self
        connectivitySession?.activate()
    }

    func activate() {
        connectivitySession?.activate()
    }

    @MainActor
    func resetForLocalDataReset() {
        clearCurrentPractice()
    }

    func sendPlaybackState(_ state: WatchPlaybackState) {
        guard
            let data = try? JSONEncoder().encode(state)
        else { return }

        latestPlaybackStateData = data
        guard
            let connectivitySession,
            connectivitySession.activationState == .activated
        else { return }

        let payload = currentContext(playbackStateData: data)
        try? connectivitySession.updateApplicationContext(payload)

        if connectivitySession.isReachable {
            connectivitySession.sendMessage(
                [WatchConnectivityPayload.playbackStateKey: data],
                replyHandler: nil,
                errorHandler: nil
            )
        }
    }

    @MainActor
    func synchronizeCurrentPracticeIfEntitled() async {
        guard let activeStage = activeStage else {
            clearCurrentPractice()
            return
        }

        if activeStage.isPremium {
            await PremiumStore.shared.refreshEntitlements()
            guard PremiumStore.shared.hasPremiumAccess else {
                clearCurrentPractice()
                return
            }
        }

        synchronizeCurrentPractice()
    }

    @MainActor
    func invalidatePremiumAccess() {
        if WatchPlaybackCoordinator.shared.playbackSession?.meditation.requiresPremiumAccess == true {
            WatchPlaybackCoordinator.shared.resetForLocalDataReset()
        }
        if activeStage?.isPremium == true { clearCurrentPractice() }
    }

    @MainActor
    func synchronizeCurrentPractice() {
        practiceRefreshTask?.cancel()

        let language = AppLanguage.resolved(
            from: UserDefaults.standard.string(forKey: "app.language")
        )
        guard let practice = currentPractice(language: language) else {
            clearCurrentPractice()
            return
        }

        if persistedSessionMatches(practice.meditation) {
            resendLatestPractice()
        }

        practiceRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let metadata: RemoteMeditationMetadata?
            if let source = practice.meditation.remoteAudioSource {
                metadata = try? await RemoteMeditationContentLoader.loadMetadata(source: source)
            } else {
                metadata = nil
            }

            guard !Task.isCancelled else { return }

            if metadata == nil, self.persistedSessionMatches(practice.meditation) {
                self.resendLatestPractice()
            } else {
                self.sendPractice(
                    practice,
                    metadata: metadata,
                    language: language
                )
            }
            self.practiceRefreshTask = nil
        }
    }

    func sendPregnancyPractice(
        meditation: DailyMeditation,
        calculation: PregnancyCalculation,
        metadata: RemoteMeditationMetadata?,
        language: AppLanguage
    ) {
        let practice = CurrentPractice(
            meditation: meditation,
            stageKey: "watch.stage.pregnancy",
            detailText: stageDetail(
                stageTitleKey: "life_stage.pregnancy.title",
                value: calculation.currentWeek,
                unit: .week,
                language: language
            ),
            periodValue: min(max(calculation.currentWeek, 4), 42)
        )
        sendPractice(practice, metadata: metadata, language: language)
    }

    private func sendPractice(
        _ practice: CurrentPractice,
        metadata: RemoteMeditationMetadata?,
        language: AppLanguage
    ) {
        let meditation = practice.meditation
        let title = metadata?.localizedTitle(for: language)
            ?? language.localizedString(forKey: meditation.titleLocalizationKey)
        let durationMinutes = metadata?.durationMinutes ?? meditation.durationMinutes
        let session = WatchMeditationSession(
            id: meditation.id,
            title: title,
            stageKey: practice.stageKey,
            detailText: practice.detailText,
            week: practice.periodValue,
            duration: TimeInterval(durationMinutes * 60),
            narrator: metadata?.narrator,
            syncedAt: Date()
        )

        if latestPracticeMatches(session) {
            resendLatestPractice()
            return
        }

        guard let data = try? JSONEncoder().encode(session) else { return }
        latestSessionData = data
        persistLatestPractice(sessionData: data)
        pendingSessionData = data
        publishPendingContextIfPossible()
    }

    private enum PeriodUnit {
        case day
        case week
    }

    private var activeStage: LifeStage? {
        UserDefaults.standard.string(forKey: LifeStagePersistenceKeys.activeStage)
            .flatMap(LifeStage.init(rawValue:))
    }

    private func currentPractice(language: AppLanguage) -> CurrentPractice? {
        let defaults = UserDefaults.standard
        guard let activeStage else { return nil }

        switch activeStage {
        case .cycle:
            guard
                defaults.object(forKey: CyclePersistenceKeys.lastPeriodStartDate) != nil,
                let profile = CycleProfile(
                    lastPeriodStartDate: Date(
                        timeIntervalSince1970: defaults.double(
                            forKey: CyclePersistenceKeys.lastPeriodStartDate
                        )
                    ),
                    averageCycleLength: defaults.integer(
                        forKey: CyclePersistenceKeys.averageLength
                    ),
                    averagePeriodDuration: defaults.integer(
                        forKey: CyclePersistenceKeys.averagePeriodDuration
                    )
                )
            else { return nil }
            let calculation = CycleCalculator().calculate(profile: profile)
            return CurrentPractice(
                meditation: DailyMeditationProvider().meditation(
                    for: calculation.currentPhase,
                    phaseDay: calculation.phaseDay,
                    cycleDay: calculation.currentCycleDay
                ),
                stageKey: "watch.stage.cycle",
                detailText: stageDetail(
                    stageTitleKey: "life_stage.cycle.title",
                    value: calculation.currentCycleDay,
                    unit: .day,
                    language: language
                ),
                periodValue: calculation.currentCycleDay
            )

        case .pregnancy:
            guard let profile = PregnancyStore().profile else { return nil }
            let calculation = PregnancyTracker().calculate(profile: profile)
            return CurrentPractice(
                meditation: PregnancyContentProvider().meditation(for: calculation),
                stageKey: "watch.stage.pregnancy",
                detailText: stageDetail(
                    stageTitleKey: "life_stage.pregnancy.title",
                    value: calculation.currentWeek,
                    unit: .week,
                    language: language
                ),
                periodValue: min(max(calculation.currentWeek, 4), 42)
            )

        case .birthMoment:
            guard let meditation = BirthMomentMeditationProvider.meditations.first else {
                return nil
            }
            return CurrentPractice(
                meditation: meditation,
                stageKey: "watch.stage.birth_moment",
                detailText: language.localizedString(forKey: "life_stage.birthMoment.title"),
                periodValue: 0
            )

        case .postpartum:
            guard let profile = PostpartumStore().profile else { return nil }
            let calculation = PostpartumTracker().calculate(profile: profile)
            return CurrentPractice(
                meditation: PostpartumMeditationProvider().meditation(for: calculation),
                stageKey: "watch.stage.postpartum",
                detailText: stageDetail(
                    stageTitleKey: "life_stage.postpartum.title",
                    value: calculation.currentDay,
                    unit: .day,
                    language: language
                ),
                periodValue: calculation.currentDay
            )

        case .motherhood03:
            return nil
        }
    }

    private func stageDetail(
        stageTitleKey: String,
        value: Int,
        unit: PeriodUnit,
        language: AppLanguage
    ) -> String {
        let title = language.localizedString(forKey: stageTitleKey)
        let detail: String
        switch (language, unit) {
        case (.turkish, .day), (.system, .day): detail = "\(value). gün"
        case (.turkish, .week), (.system, .week): detail = "\(value). hafta"
        case (.english, .day): detail = "Day \(value)"
        case (.english, .week): detail = "Week \(value)"
        }
        return "\(title) • \(detail)"
    }

    private func resendLatestPractice() {
        guard let latestSessionData else { return }
        pendingSessionData = latestSessionData
        publishPendingContextIfPossible()
    }

    private func handleSyncRequest(_ payload: [String: Any]) {
        guard payload[WatchConnectivityPayload.requestLatestPracticeKey] as? Bool == true else {
            return
        }

        Task { @MainActor [weak self] in
            await self?.synchronizeCurrentPracticeIfEntitled()
        }
    }

    private func handlePlaybackCommand(
        _ payload: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard
            let data = payload[WatchConnectivityPayload.playbackCommandKey] as? Data,
            let command = try? JSONDecoder().decode(WatchPlaybackCommand.self, from: data)
        else {
            replyHandler([WatchConnectivityPayload.playbackAcceptedKey: false])
            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                replyHandler([WatchConnectivityPayload.playbackAcceptedKey: false])
                return
            }
            await PremiumStore.shared.refreshEntitlements()
            if self.activeStage?.isPremium == true, !PremiumStore.shared.canUsePremiumNow {
                self.clearCurrentPractice()
                WatchPlaybackCoordinator.shared.resetForLocalDataReset()
                replyHandler([WatchConnectivityPayload.playbackAcceptedKey: false])
                return
            }
            let language = AppLanguage.resolved(
                from: UserDefaults.standard.string(forKey: "app.language")
            )
            guard
                let practice = self.currentPractice(language: language),
                practice.meditation.id == command.sessionID
            else {
                self.synchronizeCurrentPractice()
                replyHandler([WatchConnectivityPayload.playbackAcceptedKey: false])
                return
            }

            let accepted = WatchPlaybackCoordinator.shared.handle(
                command,
                meditation: practice.meditation,
                language: language
            )
            var reply: [String: Any] = [
                WatchConnectivityPayload.playbackAcceptedKey: accepted
            ]
            if let latestPlaybackStateData = self.latestPlaybackStateData {
                reply[WatchConnectivityPayload.playbackStateKey] = latestPlaybackStateData
            }
            replyHandler(reply)
        }
    }

    private func persistedSessionMatches(_ meditation: DailyMeditation) -> Bool {
        guard
            let latestSessionData,
            let session = try? JSONDecoder().decode(WatchMeditationSession.self, from: latestSessionData)
        else { return false }
        return session.id == meditation.id
    }

    private func latestPracticeMatches(_ candidate: WatchMeditationSession) -> Bool {
        guard
            let latestSessionData,
            let latest = try? JSONDecoder().decode(
                WatchMeditationSession.self,
                from: latestSessionData
            )
        else { return false }

        return latest.id == candidate.id
            && latest.title == candidate.title
            && latest.stageKey == candidate.stageKey
            && latest.detailText == candidate.detailText
            && latest.week == candidate.week
            && latest.duration == candidate.duration
            && latest.narrator == candidate.narrator
    }

    private func persistLatestPractice(sessionData: Data) {
        UserDefaults.standard.set(sessionData, forKey: PersistenceKeys.sessionData)
    }

    private func restorePersistedPractice() {
        latestSessionData = UserDefaults.standard.data(forKey: PersistenceKeys.sessionData)
    }

    private func clearCurrentPractice() {
        practiceRefreshTask?.cancel()
        practiceRefreshTask = nil
        pendingSessionData = nil
        latestSessionData = nil
        latestPlaybackStateData = nil

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: PersistenceKeys.sessionData)

        guard
            let connectivitySession,
            connectivitySession.activationState == .activated
        else { return }
        try? connectivitySession.updateApplicationContext([
            WatchConnectivityPayload.clearPracticeKey: true
        ])
    }

    private func publishPendingContextIfPossible() {
        guard
            let connectivitySession,
            connectivitySession.activationState == .activated,
            let pendingSessionData
        else { return }

        do {
            let payload = currentContext(
                sessionData: pendingSessionData,
                playbackStateData: latestPlaybackStateData
            )
            try connectivitySession.updateApplicationContext(payload)
            if connectivitySession.isReachable {
                connectivitySession.sendMessage(
                    payload,
                    replyHandler: nil,
                    errorHandler: nil
                )
            }
            self.pendingSessionData = nil
        } catch {
            // Keep the newest payload pending; the next activation or screen refresh retries it.
        }
    }

    private func currentContext(
        sessionData: Data? = nil,
        playbackStateData: Data? = nil
    ) -> [String: Any] {
        var payload: [String: Any] = [:]
        if let sessionData = sessionData ?? latestSessionData {
            payload[WatchConnectivityPayload.sessionDataKey] = sessionData
        }
        if let playbackStateData = playbackStateData ?? latestPlaybackStateData {
            payload[WatchConnectivityPayload.playbackStateKey] = playbackStateData
        }
        return payload
    }
}

extension WatchCompanionSync: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.publishPendingContextIfPossible()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.handleSyncRequest(message)
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handlePlaybackCommand(message, replyHandler: replyHandler)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.handleSyncRequest(userInfo)
        }
    }
}

enum WatchConnectivityPayload {
    static let sessionDataKey = "todayMeditationSession"
    static let requestLatestPracticeKey = "requestLatestPractice"
    static let clearPracticeKey = "clearTodayMeditationSession"
    static let playbackCommandKey = "playbackCommand"
    static let playbackStateKey = "playbackState"
    static let playbackAcceptedKey = "playbackAccepted"
}
