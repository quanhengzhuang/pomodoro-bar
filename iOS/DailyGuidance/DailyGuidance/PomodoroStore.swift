// iOS 番茄钟的核心业务状态与持久化。
//
// SwiftUI 页面只发送“开始、暂停、继续、结束”等意图；真正的计时状态机、记录文件、
// 本地通知、Live Activity 和跨进程共享状态都由这个文件维护。
import ActivityKit
import Combine
import Foundation
import SwiftUI
import UserNotifications

/// iOS 支持的四种计时模式。
///
/// rawValue 会写入 JSON 和 App Group，共享后不应随意改名；界面文案请修改 `title`。
enum PomodoroMode: String, Codable, CaseIterable, Identifiable {
    case countUp = "count_up"
    case focus = "focus"
    case shortBreak = "short_break"
    case longBreak = "long_break"

    var id: String { rawValue }

    /// 首页模式选择器使用的完整中文名称。
    var title: String {
        switch self {
        case .countUp: return "自由计时"
        case .focus: return "专注"
        case .shortBreak: return "短休息"
        case .longBreak: return "长休息"
        }
    }

    /// 锁屏/灵动岛空间有限，使用更短的名称。
    var compactTitle: String {
        switch self {
        case .countUp: return "计时"
        case .focus: return "专注"
        case .shortBreak, .longBreak: return "休息"
        }
    }

    /// 计划时长。自由计时没有终点，因此返回 `nil`。
    var durationSeconds: Int? {
        switch self {
        case .countUp: return nil
        case .focus: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }

    /// 一般情况下完成当前模式后应切换到的下一模式。
    /// 第四次专注后的长休息由 Store 结合历史记录另行判断。
    var next: PomodoroMode {
        switch self {
        case .focus: return .shortBreak
        case .shortBreak, .longBreak, .countUp: return .focus
        }
    }

    /// SF Symbol 名称，用于首页模式按钮和最近记录图标。
    var symbolName: String {
        switch self {
        case .countUp: return "stopwatch.fill"
        case .focus: return "scope"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }
}

/// 一条已经结束并写入本机 JSON 的计时记录。
///
/// 日期使用稳定字符串而不是直接编码 `Date`，使文件可读，也与 Mac 版格式兼容。
struct PomodoroRecord: Codable, Hashable, Identifiable {
    let startedAt: String
    let endedAt: String
    let date: String
    let type: String
    let durationSeconds: Int
    let durationMinutes: Int
    let note: String

    /// 旧数据没有独立 UUID；组合稳定字段生成足以去重的身份。
    var id: String { "\(startedAt)|\(endedAt)|\(type)|\(note)" }

    /// 从真实时间和业务字段创建可持久化记录。
    init(startedAt: Date, endedAt: Date, type: String, durationSeconds: Int, note: String) {
        self.startedAt = Self.dateTimeFormatter.string(from: startedAt)
        self.endedAt = Self.dateTimeFormatter.string(from: endedAt)
        date = Self.dateFormatter.string(from: endedAt)
        self.type = type
        self.durationSeconds = durationSeconds
        durationMinutes = durationSeconds / 60
        self.note = note
    }

    /// 把文件中的 type 字符串还原为界面模式；未知旧值安全回退为自由计时。
    var mode: PomodoroMode {
        PomodoroMode(rawValue: type) ?? .countUp
    }

    /// 最近记录列表使用的紧凑时间范围，例如 `09:30–09:55`。
    var timeRange: String {
        "\(startedAt.suffix(8).prefix(5))–\(endedAt.suffix(8).prefix(5))"
    }

    /// 仅包含日期的 POSIX 格式化器，避免设备语言改变 JSON 格式。
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// 精确到秒的记录时间格式化器。
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

/// 正在进行的会话在主 App 沙盒内的恢复快照。
///
/// 它与 `PomodoroSharedSession` 角色不同：前者用于主 App 自身重启恢复；后者用于 App Group
/// 跨主 App 和 Live Activity Intent 通信。两者保存相同核心时间字段以便相互对账。
private struct PersistedSession: Codable {
    let id: UUID
    let mode: PomodoroMode
    let isRunning: Bool
    let startedAt: Date
    let plannedDurationSeconds: Int?
    let accumulatedSeconds: Int
    let lastResumedAt: Date?
    let note: String
}

/// iOS 番茄钟的单一状态源。
///
/// `@MainActor` 让 Timer、SwiftUI 和异步 ActivityKit 回调最终都在主线程更新 Published 属性。
@MainActor
final class PomodoroStore: ObservableObject {
    // MARK: - 界面可观察状态

    /// 用户当前选中的模式；会话进行中不能切换。
    @Published private(set) var selectedMode: PomodoroMode = .focus
    /// 当前时间是否仍在累积。
    @Published private(set) var isRunning = false
    /// 是否存在一段可暂停/继续/结束的会话。
    @Published private(set) var hasActiveSession = false
    /// 页面大数字：自由计时为已用秒数，倒计时为剩余秒数。
    @Published private(set) var displaySeconds = 25 * 60
    /// 当前会话实际运行的累计秒数，不包含暂停时间。
    @Published private(set) var elapsedSeconds = 0
    /// 环形进度的 0...1 比例；自由计时每 25 分钟循环一次视觉进度。
    @Published private(set) var progress = 0.0
    /// 已完成记录，内部按时间正序保存。
    @Published private(set) var records: [PomodoroRecord] = []
    /// 系统设置是否允许 Live Activity。
    @Published private(set) var liveActivityEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    /// 当前时段备注。允许页面双向绑定，但持久化仍由 `updateNote` 统一触发。
    @Published var note = ""
    /// 需要页面弹窗展示的非致命错误。
    @Published var errorMessage: String?

    // MARK: - 当前会话内部状态

    /// 每次开始新会话都会更换，用于关联共享状态、通知和 Live Activity。
    private var sessionID = UUID()
    /// 整段会话第一次开始时间。
    private var startedAt: Date?
    /// 倒计时总计划秒数；调整时间后会变化，自由计时为 nil。
    private var plannedDurationSeconds: Int?
    /// 最近一次暂停前已经运行的秒数。
    private var accumulatedSeconds = 0
    /// 当前运行片段开始时间；暂停时为 nil。
    private var lastResumedAt: Date?
    /// 只负责让前台界面每秒刷新，不作为时间真相来源。
    private var ticker: Timer?
    /// 监听当前进程中 App Intent 发布的共享状态变化。
    private var sharedSessionObserver: AnyCancellable?
    /// 主 App 当前持有的 ActivityKit 实例。
    private var activity: Activity<PomodoroActivityAttributes>?
    /// 少于三分钟的手动结束不写记录，避免误触产生噪声。
    private let minimumRecordedSessionSeconds = 3 * 60
    /// 主 App UserDefaults 中保存会话快照的 key。
    private let sessionStorageKey = "ios.pomodoro.active-session"

    /// 每段会话使用独立通知 ID，避免取消旧提醒时误伤新时段。
    private var completionNotificationID: String {
        "pomodoro-complete-\(sessionID.uuidString)"
    }

    /// iOS 记录存放在 App 自己的 Application Support 沙盒，不直接写 Mac 的 iCloud records.json。
    private var recordsURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PomodoroBar", isDirectory: true)
            .appendingPathComponent("records.json")
    }

    // MARK: - 页面派生数据

    var modeOptions: [PomodoroMode] { PomodoroMode.allCases }

    /// 主按钮根据状态在开始、暂停、继续之间切换。
    var primaryActionTitle: String {
        guard hasActiveSession else { return "开始" }
        return isRunning ? "暂停" : "继续"
    }

    /// 今天所有专注记录的总秒数。
    var todayFocusSeconds: Int {
        records
            .filter { $0.date == PomodoroRecord.dateFormatter.string(from: Date()) && $0.type == PomodoroMode.focus.rawValue }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    /// 今天完成的全部模式记录数量。
    var todaySessionCount: Int {
        records.filter { $0.date == PomodoroRecord.dateFormatter.string(from: Date()) }.count
    }

    /// 首页只展示最后五条；完整数据仍保存在 `records`。
    var recentRecords: [PomodoroRecord] {
        Array(records.reversed().prefix(5))
    }

    init() {
        // Intent 更新共享状态后立即对账。weak self 避免订阅闭包与 Store 互相强持有。
        sharedSessionObserver = NotificationCenter.default
            .publisher(for: .pomodoroSharedSessionDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.reconcileSharedSession()
                }
            }
    }

    // MARK: - 生命周期与用户操作

    /// 首次进入 App 时恢复记录、未结束会话和已有 Live Activity。
    func prepare() async {
        loadRecords()
        restoreSession()
        reconcileSharedSession()
        activity = Activity<PomodoroActivityAttributes>.activities.first {
            $0.attributes.sessionID == sessionID
        }
        if hasActiveSession {
            // 根据墙钟时间重新计算，不能相信上次保存时的界面秒数。
            refresh(at: Date())
            if isRunning { startTicker() }
            await syncLiveActivity()
        }
    }

    /// 只允许在没有活动会话时切换模式。
    func selectMode(_ mode: PomodoroMode) {
        guard !hasActiveSession else { return }
        selectedMode = mode
        displaySeconds = mode.durationSeconds ?? 0
        elapsedSeconds = 0
        progress = 0
    }

    /// 首页主按钮的统一入口，把当前状态映射到开始、暂停或继续。
    func performPrimaryAction() {
        if !hasActiveSession {
            startNewSession()
        } else if isRunning {
            pause()
        } else {
            resume()
        }
    }

    /// 手动结束当前会话，并在达到门槛时写入记录。
    ///
    /// `recordIfEligible` 为将来的“放弃本段”场景预留；正常页面调用保持默认 true。
    func endSession(recordIfEligible: Bool = true) {
        guard hasActiveSession else { return }
        refresh(at: Date())
        if recordIfEligible && elapsedSeconds >= minimumRecordedSessionSeconds {
            appendRecord(durationSeconds: elapsedSeconds)
        }
        let finalState = activityState()
        // 先抓取最终 Activity 状态，再 reset；否则重置后的字段会污染锁屏最后一帧。
        cancelCompletionNotification()
        resetSession()
        Task { await endLiveActivity(finalState: finalState) }
    }

    /// 增减倒计时总长度。调整后必须仍有正的剩余时间。
    func adjustCountdown(minutes: Int) -> Bool {
        guard hasActiveSession, selectedMode != .countUp, minutes != 0 else { return false }
        refresh(at: Date())
        let adjustedDuration = (plannedDurationSeconds ?? selectedMode.durationSeconds ?? 0) + minutes * 60
        guard adjustedDuration > elapsedSeconds else { return false }
        plannedDurationSeconds = adjustedDuration
        refresh(at: Date())
        persistSession()
        Task { await authorizeAndScheduleCompletionNotification() }
        Task { await syncLiveActivity() }
        return true
    }

    /// 清理备注首尾空白，并在会话中同步到恢复快照与实时活动。
    func updateNote(_ value: String) {
        note = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasActiveSession {
            persistSession()
            Task { await syncLiveActivity() }
        }
    }

    /// 响应 App 前后台切换。
    ///
    /// 进入后台时停止一秒 ticker 以节省资源；回前台后通过真实时间差一次性追平。
    func scenePhaseChanged(_ phase: ScenePhase) {
        if phase == .active {
            reconcileSharedSession()
            guard hasActiveSession else { return }
            refresh(at: Date())
            if selectedMode != .countUp, displaySeconds <= 0 {
                completeCountdown()
            } else if isRunning {
                startTicker()
            }
        } else {
            guard hasActiveSession else { return }
            refresh(at: Date())
            ticker?.invalidate()
            ticker = nil
            persistSession()
            Task { await syncLiveActivity() }
        }
    }

    // MARK: - 计时状态机

    /// 初始化一段全新会话，并同时启动本地恢复、通知和 Live Activity 链路。
    private func startNewSession() {
        let now = Date()
        sessionID = UUID()
        hasActiveSession = true
        isRunning = true
        startedAt = now
        lastResumedAt = now
        accumulatedSeconds = 0
        plannedDurationSeconds = selectedMode.durationSeconds
        elapsedSeconds = 0
        displaySeconds = plannedDurationSeconds ?? 0
        progress = 0
        startTicker()
        persistSession()
        Task { await authorizeAndScheduleCompletionNotification() }
        Task { await syncLiveActivity() }
    }

    /// 冻结当前累计时间并停止前台刷新。
    private func pause() {
        refresh(at: Date())
        accumulatedSeconds = elapsedSeconds
        lastResumedAt = nil
        isRunning = false
        ticker?.invalidate()
        ticker = nil
        cancelCompletionNotification()
        persistSession()
        Task { await syncLiveActivity() }
    }

    /// 从当前时刻开启一个新的运行片段。
    private func resume() {
        lastResumedAt = Date()
        isRunning = true
        startTicker()
        persistSession()
        Task { await authorizeAndScheduleCompletionNotification() }
        Task { await syncLiveActivity() }
    }

    /// 创建每秒触发的前台 Timer。
    ///
    /// 使用 `.common` RunLoop 模式，用户滚动界面时计时显示也能继续更新。
    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    /// 每秒重新派生界面时间，并在倒计时归零时完成本段。
    private func tick() {
        refresh(at: Date())
        if selectedMode != .countUp, displaySeconds <= 0 {
            completeCountdown()
        }
    }

    /// 以“累计值 + 当前运行片段时间”计算所有界面字段。
    ///
    /// Timer 可能被系统延迟，因此绝不能简单地每次减一；墙钟差值才是时间真相。
    private func refresh(at date: Date) {
        guard hasActiveSession else { return }
        var seconds = accumulatedSeconds
        if isRunning, let lastResumedAt {
            seconds += max(0, Int(date.timeIntervalSince(lastResumedAt)))
        }
        elapsedSeconds = seconds
        if let duration = plannedDurationSeconds {
            displaySeconds = max(0, duration - seconds)
            progress = duration > 0 ? min(1, Double(seconds) / Double(duration)) : 0
        } else {
            // 自由计时没有终点，环形进度仅作为 25 分钟循环的视觉提示。
            displaySeconds = seconds
            progress = Double(seconds % (25 * 60)) / Double(25 * 60)
        }
    }

    /// 自动完成倒计时、写入完整计划时长并切换下一模式。
    private func completeCountdown() {
        guard hasActiveSession else { return }
        let completedMode = selectedMode
        appendRecord(durationSeconds: plannedDurationSeconds ?? elapsedSeconds)
        let upcomingMode = nextMode(after: completedMode)
        let finalState = activityState()
        resetSession()
        selectedMode = upcomingMode
        displaySeconds = upcomingMode.durationSeconds ?? 0
        Task { await endLiveActivity(finalState: finalState) }
    }

    /// 每完成四次专注安排一次长休息，其余情况使用模式的默认 next。
    private func nextMode(after mode: PomodoroMode) -> PomodoroMode {
        guard mode == .focus else { return mode.next }
        let completedFocusSessions = records.filter { $0.type == PomodoroMode.focus.rawValue }.count
        return completedFocusSessions.isMultiple(of: 4) ? .longBreak : .shortBreak
    }

    /// 清空当前会话内存、恢复快照和可选的 App Group 共享状态。
    ///
    /// `clearSharedSession: false` 用于从共享状态对账时，避免刚读出的值被提前删除。
    private func resetSession(clearSharedSession: Bool = true) {
        let endedSessionID = sessionID
        ticker?.invalidate()
        ticker = nil
        hasActiveSession = false
        isRunning = false
        startedAt = nil
        lastResumedAt = nil
        accumulatedSeconds = 0
        plannedDurationSeconds = nil
        note = ""
        displaySeconds = selectedMode.durationSeconds ?? 0
        elapsedSeconds = 0
        progress = 0
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
        if clearSharedSession {
            PomodoroSharedStorage.clear(sessionID: endedSessionID)
        }
    }

    // MARK: - 完成记录

    /// 创建并去重一条记录，然后原子保存整个数组。
    private func appendRecord(
        durationSeconds: Int,
        startedAt recordStartedAt: Date? = nil,
        endedAt recordEndedAt: Date = Date(),
        mode: PomodoroMode? = nil,
        note recordNote: String? = nil
    ) {
        let start = recordStartedAt ?? startedAt
            ?? recordEndedAt.addingTimeInterval(-TimeInterval(durationSeconds))
        let record = PomodoroRecord(
            startedAt: start,
            endedAt: recordEndedAt,
            type: (mode ?? selectedMode).rawValue,
            durationSeconds: max(0, durationSeconds),
            note: recordNote ?? note
        )
        guard !records.contains(where: { $0.id == record.id }) else { return }
        records.append(record)
        saveRecords()
    }

    /// 从 Application Support 读取记录；解析失败时不覆盖原文件。
    private func loadRecords() {
        guard let data = try? Data(contentsOf: recordsURL) else { return }
        do {
            records = try JSONDecoder().decode([PomodoroRecord].self, from: data)
        } catch {
            errorMessage = "记录文件无法读取；原文件未被修改。"
        }
    }

    /// 以可读、稳定排序的 JSON 原子写入记录。
    private func saveRecords() {
        do {
            let directory = recordsURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            var data = try encoder.encode(records)
            data.append(0x0A)
            try data.write(to: recordsURL, options: .atomic)
        } catch {
            errorMessage = "记录暂时无法保存，请稍后重试。"
        }
    }

    // MARK: - 会话恢复与跨进程同步

    /// 同时保存主 App 恢复快照，并可选择镜像到 App Group。
    private func persistSession(mirrorToSharedStorage: Bool = true) {
        guard hasActiveSession, let startedAt else { return }
        let value = PersistedSession(
            id: sessionID,
            mode: selectedMode,
            isRunning: isRunning,
            startedAt: startedAt,
            plannedDurationSeconds: plannedDurationSeconds,
            accumulatedSeconds: accumulatedSeconds,
            lastResumedAt: lastResumedAt,
            note: note
        )
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: sessionStorageKey)
        }
        if mirrorToSharedStorage {
            PomodoroSharedStorage.save(sharedSession(startedAt: startedAt))
        }
    }

    /// 从主 App 自己的 UserDefaults 恢复尚未结束的会话字段。
    private func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionStorageKey),
              let value = try? JSONDecoder().decode(PersistedSession.self, from: data) else { return }
        sessionID = value.id
        selectedMode = value.mode
        isRunning = value.isRunning
        hasActiveSession = true
        startedAt = value.startedAt
        plannedDurationSeconds = value.plannedDurationSeconds
        accumulatedSeconds = value.accumulatedSeconds
        lastResumedAt = value.lastResumedAt
        note = value.note
    }

    /// 把 App Group 中可能由锁屏按钮修改的状态合并回主 App。
    ///
    /// 这是交互实时活动最关键的对账入口。若共享状态为 ended，会补写记录并结束活动；
    /// 若仍 active，则恢复暂停/运行状态、提醒与 ticker。
    private func reconcileSharedSession() {
        guard let shared = PomodoroSharedStorage.load() else {
            if hasActiveSession {
                persistSession()
            }
            return
        }

        apply(sharedSession: shared)
        let referenceDate = shared.endedAt ?? Date()
        refresh(at: referenceDate)

        if shared.status == .ended {
            let elapsed = shared.elapsedSeconds(at: referenceDate)
            let duration = shared.plannedDurationSeconds.map { min(elapsed, $0) } ?? elapsed
            if duration >= minimumRecordedSessionSeconds {
                // 使用共享快照中的起止时间和备注，避免主 App 被挂起期间的信息丢失。
                appendRecord(
                    durationSeconds: duration,
                    startedAt: shared.startedAt,
                    endedAt: referenceDate,
                    mode: selectedMode,
                    note: shared.note
                )
            }
            let finalState = activityState(at: referenceDate)
            cancelCompletionNotification()
            resetSession()
            Task { await endLiveActivity(finalState: finalState) }
            return
        }

        persistSession(mirrorToSharedStorage: false)
        if isRunning {
            startTicker()
            Task { await authorizeAndScheduleCompletionNotification() }
        } else {
            ticker?.invalidate()
            ticker = nil
            cancelCompletionNotification()
        }
        Task { await syncLiveActivity() }
    }

    /// 把共享模型字段复制到主 Store。
    private func apply(sharedSession: PomodoroSharedSession) {
        sessionID = sharedSession.id
        selectedMode = PomodoroMode(rawValue: sharedSession.modeRawValue) ?? .countUp
        isRunning = sharedSession.isRunning
        hasActiveSession = true
        startedAt = sharedSession.startedAt
        plannedDurationSeconds = sharedSession.plannedDurationSeconds
        accumulatedSeconds = sharedSession.accumulatedSeconds
        lastResumedAt = sharedSession.lastResumedAt
        note = sharedSession.note
    }

    /// 从主 Store 生成可跨进程编码的 active 快照。
    private func sharedSession(startedAt: Date) -> PomodoroSharedSession {
        PomodoroSharedSession(
            id: sessionID,
            modeRawValue: selectedMode.rawValue,
            modeTitle: selectedMode.compactTitle,
            isCountUp: selectedMode == .countUp,
            startedAt: startedAt,
            isRunning: isRunning,
            plannedDurationSeconds: plannedDurationSeconds,
            accumulatedSeconds: accumulatedSeconds,
            lastResumedAt: lastResumedAt,
            note: note,
            status: .active,
            endedAt: nil,
            updatedAt: Date()
        )
    }

    // MARK: - Live Activity

    /// 把当前计时状态转换为 ActivityKit 可高效渲染的时间锚点。
    private func activityState(at date: Date = Date()) -> PomodoroActivityAttributes.ContentState {
        let timerStart: Date
        let timerEnd: Date?
        let pausedValue: Int
        if isRunning, let resumedAt = lastResumedAt {
            // 把之前累计秒数折回起点，系统就能从一个 Date 连续计算完整经过时间。
            timerStart = resumedAt.addingTimeInterval(-TimeInterval(accumulatedSeconds))
            timerEnd = plannedDurationSeconds.map { timerStart.addingTimeInterval(TimeInterval($0)) }
            pausedValue = elapsedSeconds
        } else {
            // 暂停时 `pausedValue` 固定；timerStart/timerEnd 仅用于保持完整状态结构。
            timerStart = date.addingTimeInterval(-TimeInterval(elapsedSeconds))
            timerEnd = plannedDurationSeconds.map { date.addingTimeInterval(TimeInterval(max(0, $0 - elapsedSeconds))) }
            pausedValue = displaySeconds
        }
        return PomodoroActivityAttributes.ContentState(
            modeTitle: selectedMode.compactTitle,
            isCountUp: selectedMode == .countUp,
            isRunning: isRunning,
            timerStart: timerStart,
            timerEnd: timerEnd,
            pausedSeconds: pausedValue
        )
    }

    /// 更新已有 Live Activity；若还没有，则为当前 sessionID 创建一条。
    private func syncLiveActivity() async {
        liveActivityEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        guard liveActivityEnabled, hasActiveSession else { return }
        let state = activityState()
        if let activity {
            await activity.update(using: state)
            return
        }
        do {
            activity = try Activity.request(
                attributes: PomodoroActivityAttributes(sessionID: sessionID),
                contentState: state,
                pushType: nil
            )
        } catch {
            errorMessage = "实时活动未能启动，计时仍会正常继续。"
        }
    }

    /// 结束与当前会话对应的 Activity，并立即从系统界面移除。
    private func endLiveActivity(finalState: PomodoroActivityAttributes.ContentState) async {
        let current = activity ?? Activity<PomodoroActivityAttributes>.activities.first
        await current?.end(using: finalState, dismissalPolicy: .immediate)
        activity = nil
    }

    // MARK: - 本地完成通知

    /// 请求必要权限并按照当前剩余秒数安排一次完成提醒。
    ///
    /// 每次暂停、继续或调整时间都会取消旧请求再重建，防止多个提醒重复触发。
    private func authorizeAndScheduleCompletionNotification() async {
        cancelCompletionNotification()
        guard isRunning, selectedMode != .countUp, displaySeconds > 0 else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            // 只在主 App 中请求权限；Live Activity Intent 不应突然弹出系统授权框。
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }

        guard isRunning, selectedMode != .countUp, displaySeconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = selectedMode == .focus ? "专注完成" : "休息完成"
        content.body = "打开 Pomodoro Bar 开始下一段。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(displaySeconds), repeats: false)
        let request = UNNotificationRequest(identifier: completionNotificationID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// 取消当前 sessionID 对应的待发送通知。
    private func cancelCompletionNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [completionNotificationID])
    }
}
