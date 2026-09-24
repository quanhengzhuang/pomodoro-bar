// Live Activity 按钮背后的 App Intent。
//
// iOS 17 可以在不打开主 App 的情况下执行这些 Intent。它们通过 App Group 读取/写入共享
// 会话，然后同步 ActivityKit 和完成通知；主 App 下次活跃时再把结果合并回自己的状态。
import ActivityKit
import AppIntents
import Foundation
import UserNotifications

/// 切换当前时段的暂停/继续状态。
@available(iOS 17.0, *)
struct TogglePomodoroIntent: LiveActivityIntent {
    // 这些静态属性会出现在系统的 Intent 元数据中。
    static var title: LocalizedStringResource = "暂停或继续番茄钟"
    static var description = IntentDescription("切换当前番茄时段的运行状态。")
    static var openAppWhenRun = false

    /// App Intent 参数需要可序列化类型，因此 UUID 以字符串传递。
    @Parameter(title: "时段 ID")
    var sessionID: String

    /// AppIntents 框架反序列化参数时需要无参初始化器。
    init() {}

    /// SwiftUI 按钮使用的便利初始化器。
    init(sessionID: UUID) {
        self.sessionID = sessionID.uuidString
    }

    /// 执行顺序：核对会话 → 修改 → 持久化 → 通知主 App → 更新活动和提醒。
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

/// 为当前倒计时时长增加五分钟。
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
        // `addFiveMinutes` 会拒绝自由计时和已经结束的会话。
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

/// 从锁屏或灵动岛结束当前时段。
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
        // 先留下 ended 快照供主 App补记记录，再立即停止通知和实时活动。
        PomodoroIntentSupport.notifySessionChanged()
        PomodoroIntentSupport.cancelCompletionNotification(for: session.id)
        await PomodoroIntentSupport.endActivity(for: session)
        return .result()
    }
}

/// 三个 Intent 共用的读取、校验和系统同步逻辑。
@available(iOS 17.0, *)
private enum PomodoroIntentSupport {
    /// 通知当前进程中的观察者共享状态已改变。
    static func notifySessionChanged() {
        NotificationCenter.default.post(name: .pomodoroSharedSessionDidChange, object: nil)
    }

    /// 只返回 ID 匹配且仍处于 active 状态的会话。
    ///
    /// 这一步是重要的竞态保护：旧锁屏卡片迟到的点击不能控制一段新计时。
    static func activeSession(with value: String) -> PomodoroSharedSession? {
        guard let expectedID = UUID(uuidString: value),
              let session = PomodoroSharedStorage.load(),
              session.id == expectedID,
              session.status == .active else {
            return nil
        }
        return session
    }

    /// 找到相同 sessionID 的实时活动并刷新显示状态。
    static func updateActivity(for session: PomodoroSharedSession) async {
        guard let activity = activity(for: session.id) else { return }
        await activity.update(ActivityContent(state: contentState(for: session), staleDate: nil))
    }

    /// 用最终状态结束实时活动，并要求系统立即从锁屏移除。
    static func endActivity(for session: PomodoroSharedSession) async {
        guard let activity = activity(for: session.id) else { return }
        let content = ActivityContent(state: contentState(for: session), staleDate: nil)
        await activity.end(content, dismissalPolicy: .immediate)
    }

    /// 按新的剩余时间重新安排完成通知。
    ///
    /// 暂停、自由计时或已经到期时不应存在完成通知。先取消旧请求可以防止“加 5 分”后
    /// 旧通知仍按原时间触发。
    static func updateCompletionNotification(for session: PomodoroSharedSession) async {
        cancelCompletionNotification(for: session.id)
        let now = Date()
        let remainingSeconds = session.displaySeconds(at: now)
        guard session.isRunning, !session.isCountUp, remainingSeconds > 0 else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        // Intent 不主动弹出授权对话框；只有已有通知权限时才安排提醒。
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

    /// 删除属于指定时段的待发送完成通知。
    static func cancelCompletionNotification(for sessionID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [completionNotificationID(for: sessionID)]
        )
    }

    /// ActivityKit 可能同时保留其他活动，因此必须按稳定 ID 查找而不是盲取第一个。
    private static func activity(for sessionID: UUID) -> Activity<PomodoroActivityAttributes>? {
        Activity<PomodoroActivityAttributes>.activities.first {
            $0.attributes.sessionID == sessionID
        }
    }

    /// 把共享会话模型转换为 ActivityKit 的轻量显示状态。
    ///
    /// 运行态把累计时间折回 `timerStart`，使系统计时文本可连续推进；暂停态则以传入日期
    /// 为锚点构造冻结后的时间值。
    private static func contentState(
        for session: PomodoroSharedSession,
        at date: Date = Date()
    ) -> PomodoroActivityAttributes.ContentState {
        let elapsed = session.elapsedSeconds(at: date)
        let timerStart: Date
        let timerEnd: Date?
        if session.isRunning, let resumedAt = session.lastResumedAt {
            // 最近继续时间减去此前累计时间，可得到整段计时的等效起点。
            timerStart = resumedAt.addingTimeInterval(-TimeInterval(session.accumulatedSeconds))
            timerEnd = session.plannedDurationSeconds.map {
                timerStart.addingTimeInterval(TimeInterval($0))
            }
        } else {
            // 暂停时不再依赖流动的当前时间，只保留可复现的锚点和固定秒数。
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

    /// 主 App 与 Intent 使用相同规则命名通知，以便双方都能取消同一请求。
    private static func completionNotificationID(for sessionID: UUID) -> String {
        "pomodoro-complete-\(sessionID.uuidString)"
    }
}
