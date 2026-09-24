// 主 App 与 Live Activity 扩展共享的“当前计时时段”模型。
//
// 两个进程不能直接访问彼此内存，因此把可交互计时状态编码到 App Group 的 UserDefaults。
// 主 App 和扩展 target 都必须包含本文件，并在 entitlements 中使用相同 App Group。
import Foundation

extension Notification.Name {
    /// 同一进程内共享状态发生变化的提示。
    ///
    /// App Intent 可能在扩展进程执行，跨进程同步最终仍依赖 App Group；此通知主要用于
    /// Intent 恰好在主 App 进程执行时立即刷新界面，主 App 回到前台时还会再次主动对账。
    static let pomodoroSharedSessionDidChange = Notification.Name(
        "local.codex.PomodoroBar.shared-session-did-change"
    )
}

/// 可跨主 App、Live Activity 和 App Intent 编解码的计时时段快照。
///
/// `accumulatedSeconds + lastResumedAt` 是核心时间模型：暂停前的累计秒数持久保存；运行中
/// 再加上“当前时间 - 最近继续时间”。这样无需每秒写磁盘，也不怕进程被系统挂起。
struct PomodoroSharedSession: Codable, Equatable {
    /// `ended` 是一次性终态。主 App 读到它后补写记录并清理现场。
    enum Status: String, Codable {
        case active
        case ended
    }

    /// 一段计时的唯一标识，用于拒绝迟到的旧按钮操作。
    let id: UUID
    /// `PomodoroMode.rawValue`；共享层不依赖主 App 的枚举定义。
    let modeRawValue: String
    /// 直接供 Live Activity 展示的短标题。
    let modeTitle: String
    /// 自由计时没有计划总时长。
    let isCountUp: Bool
    /// 整段会话第一次开始的时间。
    let startedAt: Date
    /// 是否正在流逝时间。
    var isRunning: Bool
    /// 倒计时计划总秒数；自由计时为 `nil`。
    var plannedDurationSeconds: Int?
    /// 截至最近一次暂停之前已经实际运行的秒数。
    var accumulatedSeconds: Int
    /// 当前运行片段的起点；暂停时必须为 `nil`。
    var lastResumedAt: Date?
    /// 用户为本段添加的备注。
    var note: String
    /// 当前仍有效或已由锁屏按钮结束。
    var status: Status
    /// 结束按钮的实际触发时间，用于生成记录结束时间。
    var endedAt: Date?
    /// 最后修改时间，便于今后诊断状态新旧。
    var updatedAt: Date

    /// 计算指定时刻已经运行的总秒数。
    ///
    /// 使用传入的 `date` 而不是在内部多次调用 `Date()`，保证一次状态计算中的各字段一致。
    func elapsedSeconds(at date: Date) -> Int {
        var seconds = accumulatedSeconds
        if isRunning, let lastResumedAt {
            seconds += max(0, Int(date.timeIntervalSince(lastResumedAt)))
        }
        return max(0, seconds)
    }

    /// 返回界面应显示的秒数：自由计时显示已用时间，倒计时显示剩余时间。
    func displaySeconds(at date: Date) -> Int {
        let elapsed = elapsedSeconds(at: date)
        return plannedDurationSeconds.map { max(0, $0 - elapsed) } ?? elapsed
    }

    /// 在运行和暂停之间切换。
    ///
    /// 暂停时把本轮运行时间折算进累计值；继续时只记录新的起点，避免重复累计。
    mutating func toggleRunning(at date: Date) {
        guard status == .active else { return }
        if isRunning {
            accumulatedSeconds = elapsedSeconds(at: date)
            lastResumedAt = nil
            isRunning = false
        } else {
            lastResumedAt = date
            isRunning = true
        }
        updatedAt = date
    }

    /// 为倒计时增加五分钟。自由计时或已结束时返回 `false`。
    mutating func addFiveMinutes(at date: Date) -> Bool {
        guard status == .active, !isCountUp, let plannedDurationSeconds else { return false }
        self.plannedDurationSeconds = plannedDurationSeconds + 5 * 60
        updatedAt = date
        return true
    }

    /// 把会话变为结束态并冻结最终时长。
    mutating func end(at date: Date) {
        guard status == .active else { return }
        accumulatedSeconds = elapsedSeconds(at: date)
        lastResumedAt = nil
        isRunning = false
        status = .ended
        endedAt = date
        updatedAt = date
    }
}

/// App Group UserDefaults 的最小读写封装。
///
/// key 带 `v1` 版本号，未来若改变编码结构可使用新 key 做兼容迁移，而不必破坏旧数据。
enum PomodoroSharedStorage {
    /// 必须与两个 target 的 entitlements 完全一致。
    static let appGroupIdentifier = "group.local.codex.PomodoroBar"
    static let sessionKey = "pomodoro.shared-session.v1"

    /// 读取并解码当前共享会话；没有数据或格式损坏时返回 `nil`。
    static func load() -> PomodoroSharedSession? {
        guard let data = defaults?.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(PomodoroSharedSession.self, from: data)
    }

    /// 编码并保存快照。返回值让调用者决定失败时是否继续更新 Live Activity。
    @discardableResult
    static func save(_ session: PomodoroSharedSession) -> Bool {
        guard let defaults, let data = try? JSONEncoder().encode(session) else { return false }
        defaults.set(data, forKey: sessionKey)
        return true
    }

    /// 清除共享会话。
    ///
    /// 传入 `sessionID` 时会先核对身份，防止旧时段的异步清理误删刚开始的新时段。
    static func clear(sessionID: UUID? = nil) {
        guard let defaults else { return }
        if let sessionID, load()?.id != sessionID { return }
        defaults.removeObject(forKey: sessionKey)
    }

    /// `suiteName` 让主 App 和扩展访问同一 App Group 容器，而不是各自独立的默认容器。
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
}
