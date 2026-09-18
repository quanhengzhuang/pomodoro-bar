import ActivityKit
import AppIntents
import Foundation
import UserNotifications

@available(iOS 17.0, *)
struct TogglePomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "暂停或继续番茄钟"
    static var description = IntentDescription("切换当前番茄时段的运行状态。")
    static var openAppWhenRun = false

    @Parameter(title: "时段 ID")
    var sessionID: String

    init() {}

    init(sessionID: UUID) {
        self.sessionID = sessionID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard var session = PomodoroIntentSupport.activeSession(with: sessionID) else {
            return .result()
        }

        session.toggleRunning(at: Date())
        guard PomodoroSharedStorage.save(session) else { return .result() }
        PomodoroIntentSupport.notifySessionChanged()
        await PomodoroIntentSupport.updateActivity(for: session)
        await PomodoroIntentSupport.updateCompletionNotification(for: session)
        return .result()
    }
}

@available(iOS 17.0, *)
struct AddFiveMinutesIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "增加五分钟"
    static var description = IntentDescription("为当前倒计时增加五分钟。")
    static var openAppWhenRun = false

    @Parameter(title: "时段 ID")
    var sessionID: String

    init() {}

    init(sessionID: UUID) {
        self.sessionID = sessionID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard var session = PomodoroIntentSupport.activeSession(with: sessionID),
              session.addFiveMinutes(at: Date()) else {
            return .result()
        }

        guard PomodoroSharedStorage.save(session) else { return .result() }
        PomodoroIntentSupport.notifySessionChanged()
        await PomodoroIntentSupport.updateActivity(for: session)
        await PomodoroIntentSupport.updateCompletionNotification(for: session)
        return .result()
    }
}

@available(iOS 17.0, *)
struct EndPomodoroIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "结束番茄时段"
    static var description = IntentDescription("结束当前番茄时段。")
    static var openAppWhenRun = false

    @Parameter(title: "时段 ID")
    var sessionID: String

    init() {}

    init(sessionID: UUID) {
        self.sessionID = sessionID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard var session = PomodoroIntentSupport.activeSession(with: sessionID) else {
            return .result()
        }

        session.end(at: Date())
        guard PomodoroSharedStorage.save(session) else { return .result() }
        PomodoroIntentSupport.notifySessionChanged()
        PomodoroIntentSupport.cancelCompletionNotification(for: session.id)
        await PomodoroIntentSupport.endActivity(for: session)
        return .result()
    }
}

@available(iOS 17.0, *)
private enum PomodoroIntentSupport {
    static func notifySessionChanged() {
        NotificationCenter.default.post(name: .pomodoroSharedSessionDidChange, object: nil)
    }

    static func activeSession(with value: String) -> PomodoroSharedSession? {
        guard let expectedID = UUID(uuidString: value),
              let session = PomodoroSharedStorage.load(),
              session.id == expectedID,
              session.status == .active else {
            return nil
        }
        return session
    }

    static func updateActivity(for session: PomodoroSharedSession) async {
        guard let activity = activity(for: session.id) else { return }
        await activity.update(ActivityContent(state: contentState(for: session), staleDate: nil))
    }

    static func endActivity(for session: PomodoroSharedSession) async {
        guard let activity = activity(for: session.id) else { return }
        let content = ActivityContent(state: contentState(for: session), staleDate: nil)
        await activity.end(content, dismissalPolicy: .immediate)
    }

    static func updateCompletionNotification(for session: PomodoroSharedSession) async {
        cancelCompletionNotification(for: session.id)
        let now = Date()
        let remainingSeconds = session.displaySeconds(at: now)
        guard session.isRunning, !session.isCountUp, remainingSeconds > 0 else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else { return }

        let content = UNMutableNotificationContent()
        content.title = session.modeRawValue == "focus" ? "专注完成" : "休息完成"
        content.body = "打开 Pomodoro Bar 开始下一段。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(remainingSeconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: completionNotificationID(for: session.id),
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    static func cancelCompletionNotification(for sessionID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [completionNotificationID(for: sessionID)]
        )
    }

    private static func activity(for sessionID: UUID) -> Activity<PomodoroActivityAttributes>? {
        Activity<PomodoroActivityAttributes>.activities.first {
            $0.attributes.sessionID == sessionID
        }
    }

    private static func contentState(
        for session: PomodoroSharedSession,
        at date: Date = Date()
    ) -> PomodoroActivityAttributes.ContentState {
        let elapsed = session.elapsedSeconds(at: date)
        let timerStart: Date
        let timerEnd: Date?
        if session.isRunning, let resumedAt = session.lastResumedAt {
            timerStart = resumedAt.addingTimeInterval(-TimeInterval(session.accumulatedSeconds))
            timerEnd = session.plannedDurationSeconds.map {
                timerStart.addingTimeInterval(TimeInterval($0))
            }
        } else {
            timerStart = date.addingTimeInterval(-TimeInterval(elapsed))
            timerEnd = session.plannedDurationSeconds.map {
                date.addingTimeInterval(TimeInterval(max(0, $0 - elapsed)))
            }
        }

        return PomodoroActivityAttributes.ContentState(
            modeTitle: session.modeTitle,
            isCountUp: session.isCountUp,
            isRunning: session.isRunning,
            timerStart: timerStart,
            timerEnd: timerEnd,
            pausedSeconds: session.displaySeconds(at: date)
        )
    }

    private static func completionNotificationID(for sessionID: UUID) -> String {
        "pomodoro-complete-\(sessionID.uuidString)"
    }
}
