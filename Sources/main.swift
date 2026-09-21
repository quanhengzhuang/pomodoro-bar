// Pomodoro Bar 的 macOS 菜单栏应用全部源码。
//
// Mac 版刻意保持为一个 AppKit 单文件程序：脚本用 swiftc 直接编译，不依赖 Xcode 工程。
// `PomodoroController` 同时承担应用生命周期、菜单构建、计时状态机、记录/指引持久化等职责。
// 阅读时建议先看 PomodoroMode/PomodoroRecord，再沿 MARK 区段阅读 Controller。
import AppKit
import Foundation

/// Mac 番茄钟的倒计时模式。
///
/// 自由计时由 `isCountUp` 单独表示，未放进这个枚举。rawValue 主要用于内部英文名称，
/// 写入记录文件的是更稳定的 `recordType`。
enum PomodoroMode: String {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"

    /// 通常完成当前模式后自动选择的下一模式。
    var next: PomodoroMode {
        switch self {
        case .focus:
            return .shortBreak
        case .shortBreak, .longBreak:
            return .focus
        }
    }

    /// 菜单和提醒中展示的中文名称。
    var menuTitle: String {
        switch self {
        case .focus:
            return "专注"
        case .shortBreak:
            return "短休息"
        case .longBreak:
            return "长休息"
        }
    }

    /// records.json 中保存的稳定机器值；不要改成中文，以免破坏旧数据兼容。
    var recordType: String {
        switch self {
        case .focus:
            return "focus"
        case .shortBreak:
            return "short_break"
        case .longBreak:
            return "long_break"
        }
    }
}

/// Mac 与 iOS 共用 JSON 语义的一条完成记录。
///
/// 自定义 Codable 是为了同时兼容旧版 `completedAt/title/durationMinutes` 格式和当前的
/// `startedAt/endedAt/durationSeconds/type/note` 格式。读取旧数据后再次保存会写成新格式，
/// 但原始本地文件不会在迁移前被删除。
struct PomodoroRecord: Codable, Hashable {
    /// 新记录使用 UUID；旧 JSON 解码时按原字段生成跨设备稳定 ID。
    let recordID: String
    /// `yyyy-MM-dd HH:mm:ss`，便于用户直接阅读和按字符串排序。
    let startedAt: String
    let endedAt: String
    /// 记录结束当天的 `yyyy-MM-dd`。
    let date: String
    /// focus、short_break、long_break 或 count_up。
    let type: String
    /// 精确时长是业务真相；分钟字段保留给旧版本和人工查看。
    let durationSeconds: Int
    let durationMinutes: Int
    /// 用户输入的纯文本备注。
    let note: String

    /// 同时列出新旧格式可能出现的 key。
    enum CodingKeys: String, CodingKey {
        case recordID = "id"
        case date
        case startedAt
        case endedAt
        case durationSeconds
        case durationMinutes
        case type
        case note
        case completedAt
        case title
    }

    /// 创建当前格式记录时统一由秒数派生分钟数。
    init(
        recordID: String = UUID().uuidString.lowercased(),
        startedAt: String,
        endedAt: String,
        date: String,
        type: String,
        durationSeconds: Int,
        note: String
    ) {
        self.recordID = recordID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.date = date
        self.type = type
        self.durationSeconds = durationSeconds
        self.durationMinutes = durationSeconds / 60
        self.note = note
    }

    /// 兼容解码入口。
    ///
    /// 旧记录只有 completedAt 时，用同一时间同时填充开始和结束；虽然无法恢复历史时间段，
    /// 但可保留完成日期、时长和标题，不会丢弃用户数据。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let startedAt = try container.decodeIfPresent(String.self, forKey: .startedAt),
           let endedAt = try container.decodeIfPresent(String.self, forKey: .endedAt) {
            self.startedAt = startedAt
            self.endedAt = endedAt
        } else {
            let completedAt = try container.decode(Date.self, forKey: .completedAt)
            let fallbackTime = PomodoroRecord.makeDateTimeString(from: completedAt)
            self.startedAt = fallbackTime
            self.endedAt = fallbackTime
        }

        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        // durationSeconds 是后来增加的字段，旧数据回退为分钟 × 60。
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
            ?? durationMinutes * 60
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "focus"
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? String(endedAt.prefix(10))
        recordID = try container.decodeIfPresent(String.self, forKey: .recordID)
            ?? stableLegacyPomodoroRecordID(
                startedAt: startedAt,
                endedAt: endedAt,
                type: type,
                durationSeconds: durationSeconds,
                note: note
            )
    }

    /// 始终按当前可读 JSON 格式编码，不再写入历史兼容字段。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recordID, forKey: .recordID)
        try container.encode(date, forKey: .date)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(type, forKey: .type)
        try container.encode(note, forKey: .note)
    }

    /// CloudKit 与本地 JSON 之间的无损转换。
    init(cloudValue: CloudPomodoroSession) {
        self.init(
            recordID: cloudValue.recordID,
            startedAt: cloudValue.startedAt,
            endedAt: cloudValue.endedAt,
            date: cloudValue.date,
            type: cloudValue.type,
            durationSeconds: cloudValue.durationSeconds,
            note: cloudValue.note
        )
    }

    var cloudValue: CloudPomodoroSession {
        CloudPomodoroSession(
            recordID: recordID,
            startedAt: startedAt,
            endedAt: endedAt,
            date: date,
            type: type,
            durationSeconds: durationSeconds,
            note: note
        )
    }

    /// 把机器 type 转换为菜单标题；未知值原样显示，便于发现新类型或损坏数据。
    var displayTitle: String {
        switch type {
        case "focus":
            return "专注"
        case "short_break", "long_break":
            return "休息"
        case "count_up":
            return "计时"
        default:
            return type
        }
    }

    /// 不同记录类型在菜单前使用不同圆点颜色。
    var menuDotColor: NSColor {
        switch type {
        case "focus":
            return NSColor(calibratedRed: 0.88, green: 0.20, blue: 0.18, alpha: 1)
        case "count_up":
            return NSColor(calibratedRed: 0.95, green: 0.52, blue: 0.10, alpha: 1)
        default:
            return NSColor(calibratedRed: 0.10, green: 0.54, blue: 0.38, alpha: 1)
        }
    }

    /// 旧格式迁移时生成稳定日期字符串。
    private static func makeDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// 旧格式迁移时生成精确到秒的时间字符串。
    private static func makeDateTimeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

/// Mac App 的总控制器。
///
/// 同时实现：
/// - `NSApplicationDelegate`：处理应用启动；
/// - `NSMenuDelegate`：每次打开菜单前刷新 iCloud 数据；
/// - `NSUserNotificationCenterDelegate`：前台也展示完成提醒。
final class PomodoroController: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate, NSMenuDelegate {
    // MARK: - 菜单栏基础对象

    /// 系统菜单栏右侧的状态项；宽度随图标和时间文字变化。
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    /// 点击状态项后展示的整张菜单。
    private let menu = NSMenu()

    // MARK: - 当前计时状态

    /// 仅用于每秒刷新界面；实际经过时间始终由墙钟时间差计算。
    private var timer: Timer?
    /// 当前倒计时模式。自由计时仍保留最近模式，但由 isCountUp 覆盖语义。
    private var mode: PomodoroMode = .focus
    private var isCountUp = false
    private var isRunning = false
    private var hasActiveSession = false
    /// 用于判断每四次专注后的长休息；当前仅统计本次进程生命周期内自动完成次数。
    private var focusSessions = 0
    /// 无活动会话时显示的默认秒数，或调整倒计时时同步维护的剩余值。
    private var remainingSeconds = 25 * 60
    /// 整段会话最初开始的真实时间。
    private var sessionStartedAt: Date?
    /// 倒计时当前计划总秒数，调整时长后与模式默认值不同。
    private var sessionPlannedDurationSeconds: Int?
    /// 最近一次暂停开始时间。
    private var sessionPausedAt: Date?
    /// 之前所有已结束暂停片段的累计秒数。
    private var sessionPausedSeconds = 0
    private var sessionNote = ""

    // MARK: - 内存数据与存储配置

    private var records: [PomodoroRecord] = []
    /// daily-guidance.json 解码后的“日期 → 纯文本”字典。
    private var dailyGuidanceByDate: [String: String] = [:]
    private let cloudStore = PomodoroCloudKitStore()
    private var isSynchronizingCloud = false
    private var cloudMigrationAllowed = true
    private var hasShownCloudSyncError = false
    /// iCloud 文件解析失败后暂时标记，写入时回退本地以免覆盖损坏/未下载文件。
    private var unreadableICloudFileNames = Set<String>()
    // 时长配置集中在这里，单位统一为秒或明确带 Minutes 后缀。
    private let focusDurationMinutes = 25
    /// 旧版 UserDefaults 记录 key，仅用于兼容迁移。
    private let recordsStorageKey = "pomodoro.records"
    /// iCloud 不可用时的本机回退目录。
    private let localDataDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".pomodoro-status-bar", isDirectory: true)
    private let recordsFileName = "records.json"
    private let dailyGuidanceFileName = "daily-guidance.json"
    private let cloudBackupMarkerKey = "cloudkit.legacy-json-backup-created"
    private let iCloudDataDirectoryName = "PomodoroBar"
    // 今日指引显示与编辑共享这些尺寸，保证每行换行位置一致。
    private let dailyGuidanceMenuWidth: CGFloat = 520
    private let dailyGuidanceHorizontalPadding: CGFloat = 16
    private let dailyGuidanceVerticalPadding: CGFloat = 8

    private let shortBreakDurationSeconds = 5 * 60
    private let longBreakDurationSeconds = 15 * 60
    private let minimumRecordedSessionSeconds = 3 * 60
    private let collapsedRecordsLimit = 10
    private let historicalDateLimit = 30
    private let dailyGuidanceHistoryDayLimit = 30

    // MARK: - 复用菜单项、图标与格式化器

    /// 经常改变标题/启用状态的菜单项只创建一次，重建菜单时重复挂载。
    private lazy var statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private lazy var startMenuItem = NSMenuItem(
        title: "开始",
        action: #selector(startCountUpTimer),
        keyEquivalent: " "
    )
    private lazy var pauseMenuItem = NSMenuItem(
        title: "暂停",
        action: #selector(toggleTimer),
        keyEquivalent: " "
    )
    private lazy var endMenuItem = NSMenuItem(
        title: "结束",
        action: #selector(endCurrentSession),
        keyEquivalent: ""
    )
    private lazy var tomatoStatusIcon = makeTomatoStatusIcon()
    private lazy var pauseStatusIcon = makePauseStatusIcon()
    /// 从构建脚本复制到 App 包 Resources 的 icns 图标。
    private lazy var applicationIcon: NSImage? = {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()
    /// 历史菜单日期后的中文星期。
    private lazy var historyWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    // MARK: - 应用生命周期

    /// AppKit 完成启动后的总初始化入口。
    func applicationDidFinishLaunching(_ notification: Notification) {
        // accessory 模式不显示 Dock 图标和普通菜单栏，只保留状态栏入口。
        NSApp.setActivationPolicy(.accessory)
        terminateOtherInstances()
        configureApplicationIcon()
        configureNotifications()
        // 必须先复制原 JSON，再让任何兼容迁移或格式升级有机会回写文件。
        cloudMigrationAllowed = backupLegacyJSONBeforeCloudKitIfNeeded()
        loadRecords()
        loadDailyGuidance()
        synchronizeDailyGuidanceToICloudIfNeeded()
        remainingSeconds = duration(for: .focus)
        configureStatusItem()
        rebuildMenu()
        updateStatusTitle()
        if !cloudMigrationAllowed {
            showCloudMigrationBackupError()
        }
        Task { @MainActor [weak self] in
            await self?.synchronizeCloudData(reportErrors: false)
        }
    }

    /// 结束同 Bundle Identifier 的旧进程，避免开发重启后菜单栏出现多个番茄。
    private func terminateOtherInstances() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        for application in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            where application.processIdentifier != currentProcessIdentifier {
            application.terminate()
        }
    }

    /// 给系统提醒框和应用元数据设置图标。
    private func configureApplicationIcon() {
        NSApp.applicationIconImage = applicationIcon
    }

    /// 创建统一带应用图标的 Alert。
    private func makeAlert() -> NSAlert {
        let alert = NSAlert()
        alert.icon = applicationIcon
        return alert
    }

    /// 让旧版 NSUserNotification 在 App 前台也能交给本控制器决定展示。
    private func configureNotifications() {
        NSUserNotificationCenter.default.delegate = self
    }

    /// 配置状态栏按钮、菜单代理和空格快捷键所需的菜单关系。
    private func configureStatusItem() {
        statusItem.autosaveName = "local.codex.PomodoroStatusBar.statusItem"
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        statusItem.button?.toolTip = "番茄计时"
        menu.delegate = self
        statusItem.menu = menu
    }

    /// 菜单即将打开时，从磁盘重新合并数据。
    ///
    /// iCloud 文件可能由 iOS 或另一台 Mac 修改，不能只依赖启动时的一次加载。
    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshRecordsFromDataFiles()
        loadDailyGuidance()
        synchronizeFallbackDataToICloudIfNeeded()
        rebuildMenu()
        Task { @MainActor [weak self] in
            await self?.synchronizeCloudData(reportErrors: false)
        }
    }

    // MARK: - 菜单构建

    /// 按当前状态从头构建菜单项。
    ///
    /// NSMenu 项目不多，重建比逐项维护显隐状态更简单，也减少遗漏更新的风险。
    private func rebuildMenu() {
        menu.removeAllItems()

        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        addDailyGuidanceMenuItems()
        menu.addItem(.separator())

        if hasActiveSession {
            pauseMenuItem.target = self
            pauseMenuItem.title = isRunning ? "暂停" : "继续"
            pauseMenuItem.keyEquivalent = " "
            pauseMenuItem.keyEquivalentModifierMask = []
            menu.addItem(pauseMenuItem)

            endMenuItem.target = self
            menu.addItem(endMenuItem)
        } else {
            startMenuItem.target = self
            startMenuItem.keyEquivalent = " "
            startMenuItem.keyEquivalentModifierMask = []
            menu.addItem(startMenuItem)
        }

        if hasActiveSession && !isCountUp {
            let adjustTimeItem = NSMenuItem(title: "调整时间...", action: #selector(adjustActiveCountdown), keyEquivalent: "")
            adjustTimeItem.target = self
            menu.addItem(adjustTimeItem)
        }

        let noteItem = NSMenuItem(title: sessionNote.isEmpty ? "设置本段备注..." : "修改本段备注...", action: #selector(editSessionNote), keyEquivalent: "e")
        noteItem.target = self
        menu.addItem(noteItem)

        menu.addItem(.separator())

        let focusItem = NSMenuItem(title: "专注 \(focusDurationMinutes) 分钟", action: #selector(selectFocus), keyEquivalent: "1")
        focusItem.target = self
        focusItem.isEnabled = !hasActiveSession
        menu.addItem(focusItem)

        let shortBreakItem = NSMenuItem(title: "短休息 5 分钟", action: #selector(selectShortBreak), keyEquivalent: "2")
        shortBreakItem.target = self
        shortBreakItem.isEnabled = !hasActiveSession
        menu.addItem(shortBreakItem)

        let longBreakItem = NSMenuItem(title: "长休息 15 分钟", action: #selector(selectLongBreak), keyEquivalent: "3")
        longBreakItem.target = self
        longBreakItem.isEnabled = !hasActiveSession
        menu.addItem(longBreakItem)

        menu.addItem(.separator())

        addRecordsMenuItems()

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出番茄计时", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        updateStatusMenuItem()
    }

    // MARK: - 计时状态机

    /// 开始新计时或从暂停继续。
    ///
    /// 第一次开始时记录 sessionStartedAt 和计划总时长；继续时把刚结束的暂停片段累加。
    /// Timer 只驱动界面刷新，`activeSessionSeconds` 才负责根据真实时间计算结果。
    private func startTimer() {
        let now = Date()
        isRunning = true
        hasActiveSession = true
        if sessionStartedAt == nil {
            sessionStartedAt = now
            sessionPlannedDurationSeconds = isCountUp ? nil : duration(for: mode)
        }
        if let sessionPausedAt {
            // 把当前暂停片段计入总暂停时间，恢复运行后不再保留暂停起点。
            sessionPausedSeconds += max(0, Int(now.timeIntervalSince(sessionPausedAt)))
            self.sessionPausedAt = nil
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer!, forMode: .common)
        updateStatusTitle()
        rebuildMenu()
    }

    /// 暂停但保留会话和备注，等待用户继续或结束。
    private func pauseTimer() {
        isRunning = false
        sessionPausedAt = Date()
        timer?.invalidate()
        timer = nil
        updateStatusTitle()
        rebuildMenu()
    }

    /// 完全清空当前会话，恢复为未开始状态。
    ///
    /// 已经写入 records 的数据不受影响。
    private func stopTimer() {
        isRunning = false
        hasActiveSession = false
        sessionStartedAt = nil
        sessionPlannedDurationSeconds = nil
        sessionPausedAt = nil
        sessionPausedSeconds = 0
        sessionNote = ""
        timer?.invalidate()
        timer = nil
        updateStatusTitle()
        rebuildMenu()
    }

    /// 切换预设模式并重置该模式的默认时长。
    private func setMode(_ nextMode: PomodoroMode) {
        mode = nextMode
        remainingSeconds = duration(for: nextMode)
        stopTimer()
    }

    /// 从菜单快捷入口开始一个指定的倒计时模式。
    private func startMode(_ nextMode: PomodoroMode) {
        guard !hasActiveSession else {
            return
        }
        isCountUp = false
        setMode(nextMode)
        startTimer()
    }

    /// 倒计时自然归零后的完成流程：记录、选择下一模式、提示音和通知。
    private func completeCurrentMode() {
        if mode == .focus {
            focusSessions += 1
        }

        let completedMode = mode
        addTimerRecord(
            type: completedMode.recordType,
            durationSeconds: sessionPlannedDurationSeconds ?? duration(for: completedMode)
        )

        let nextMode: PomodoroMode
        if completedMode == .focus && focusSessions > 0 && focusSessions % 4 == 0 {
            // 标准番茄节奏：四次专注后安排长休息。
            nextMode = .longBreak
        } else {
            nextMode = completedMode.next
        }

        NSSound(named: "Glass")?.play()
        mode = nextMode
        remainingSeconds = duration(for: nextMode)
        stopTimer()
        showCompletionNotification(completedMode: completedMode, nextMode: nextMode)
    }

    /// 返回模式默认时长，单位秒。
    private func duration(for mode: PomodoroMode) -> Int {
        switch mode {
        case .focus:
            return focusDurationMinutes * 60
        case .shortBreak:
            return shortBreakDurationSeconds
        case .longBreak:
            return longBreakDurationSeconds
        }
    }

    /// 发送旧版 AppKit 本地通知。
    ///
    /// 此 API 已被系统标记 deprecated，但仍用于保持当前轻量单文件 Mac 构建；构建警告已知。
    private func showCompletionNotification(completedMode: PomodoroMode, nextMode: PomodoroMode) {
        let notification = NSUserNotification()
        notification.title = completedMode == .focus ? "专注完成" : "休息完成"
        notification.informativeText = "下一段：\(nextMode.menuTitle)"
        notification.soundName = NSUserNotificationDefaultSoundName
        notification.deliveryDate = Date()
        NSUserNotificationCenter.default.deliver(notification)
    }

    /// 即使 App 当前活跃，也允许系统展示通知。
    func userNotificationCenter(
        _ center: NSUserNotificationCenter,
        shouldPresent notification: NSUserNotification
    ) -> Bool {
        true
    }

    // MARK: - 状态栏显示

    /// 根据当前会话生成菜单栏的番茄/暂停图标和 `MM:SS` 文本。
    private func updateStatusTitle() {
        let displaySeconds: Int
        if isCountUp, hasActiveSession {
            displaySeconds = activeSessionSeconds()
        } else if hasActiveSession {
            let plannedDurationSeconds = sessionPlannedDurationSeconds ?? duration(for: mode)
            displaySeconds = max(0, plannedDurationSeconds - activeSessionSeconds())
        } else {
            displaySeconds = remainingSeconds
        }
        let minutes = displaySeconds / 60
        let seconds = displaySeconds % 60
        let title = NSMutableAttributedString()

        let iconAttachment = NSTextAttachment()
        // 未开始时显示番茄；活动中根据运行/暂停切换图标。
        iconAttachment.image = isRunning || !hasActiveSession ? tomatoStatusIcon : pauseStatusIcon
        iconAttachment.bounds = NSRect(x: 0, y: -2.5, width: 15, height: 15)
        title.append(NSAttributedString(attachment: iconAttachment))

        if isRunning || hasActiveSession {
            // 未开始时只显示图标，减少菜单栏占用。
            title.append(NSAttributedString(
                string: " \(String(format: "%02d:%02d", minutes, seconds))",
                attributes: [
                    .foregroundColor: NSColor.labelColor,
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
                ]
            ))
        }

        statusItem.button?.attributedTitle = title
        updateStatusMenuItem()
    }

    /// 用 AppKit 绘图 API 在内存中生成非模板番茄图标。
    ///
    /// 非模板图可保留红绿颜色；若设为模板图，系统会自动改为单色。
    private func makeTomatoStatusIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        NSColor(calibratedRed: 0.88, green: 0.20, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 3, y: 2.5, width: 12.5, height: 12.5)).fill()

        NSColor(calibratedRed: 0.10, green: 0.47, blue: 0.32, alpha: 1).setFill()
        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: 9, y: 16))
        leaf.line(to: NSPoint(x: 6.5, y: 12.2))
        leaf.line(to: NSPoint(x: 9, y: 13.2))
        leaf.line(to: NSPoint(x: 11.5, y: 12.2))
        leaf.close()
        leaf.fill()

        NSColor.white.withAlphaComponent(0.35).setFill()
        NSBezierPath(ovalIn: NSRect(x: 5.2, y: 10.2, width: 3.2, height: 2.2)).fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    /// 生成暂停状态的双竖条图标。
    private func makePauseStatusIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        NSColor(calibratedRed: 0.88, green: 0.20, blue: 0.18, alpha: 1).setFill()
        let leftBar = NSBezierPath(roundedRect: NSRect(x: 5, y: 3.5, width: 3, height: 11), xRadius: 1.2, yRadius: 1.2)
        let rightBar = NSBezierPath(roundedRect: NSRect(x: 10, y: 3.5, width: 3, height: 11), xRadius: 1.2, yRadius: 1.2)
        leftBar.fill()
        rightBar.fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    /// 更新菜单第一行的详细状态文字。
    private func updateStatusMenuItem() {
        let state: String
        if isRunning {
            state = "运行中"
        } else if hasActiveSession {
            state = "已暂停"
        } else {
            state = "未开始"
        }
        let elapsedSeconds: Int
        if hasActiveSession {
            elapsedSeconds = activeSessionSeconds()
        } else {
            elapsedSeconds = 0
        }
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        let noteSuffix = sessionNote.isEmpty ? "" : " · \(sessionNote)"
        let timerTitle = isCountUp ? "计时" : (mode == .focus ? "专注" : "休息")
        statusMenuItem.title = "\(timerTitle) · \(state) · \(String(format: "%02d:%02d", minutes, seconds))\(noteSuffix)"
    }

    // MARK: - 今日指引显示与持久化

    /// 把今天的指引正文和设置/修改入口加入主菜单。
    private func addDailyGuidanceMenuItems() {
        let guidance = dailyGuidanceByDate[todayDateKey] ?? ""
        if !guidance.isEmpty {
            let guidanceItem = NSMenuItem()
            guidanceItem.view = makeDailyGuidanceMenuView(text: guidance)
            guidanceItem.isEnabled = false
            menu.addItem(guidanceItem)
        }

        let editItem = NSMenuItem(
            title: guidance.isEmpty ? "设置今日指引..." : "修改今日指引...",
            action: #selector(editDailyGuidance),
            keyEquivalent: "g"
        )
        editItem.target = self
        menu.addItem(editItem)
    }

    /// 创建能完整自动换行的自定义 NSMenuItem 内容视图。
    ///
    /// 普通 NSMenuItem.title 不适合多行长文本，因此使用只读 NSTextView，并通过
    /// LayoutManager 计算实际高度。宽度、边距和字体与编辑框共享常量。
    private func makeDailyGuidanceMenuView(text: String) -> NSView {
        let contentWidth = dailyGuidanceMenuWidth - dailyGuidanceHorizontalPadding * 2
        let body = NSTextView(frame: NSRect(
            x: dailyGuidanceHorizontalPadding,
            y: dailyGuidanceVerticalPadding,
            width: contentWidth,
            height: 1
        ))
        let baseFont = NSFont.menuFont(ofSize: 0)
        body.isEditable = false
        body.isSelectable = false
        body.isRichText = false
        body.drawsBackground = false
        body.textContainerInset = .zero
        body.isHorizontallyResizable = false
        body.isVerticallyResizable = true
        body.textContainer?.lineFragmentPadding = 0
        body.textContainer?.widthTracksTextView = true
        body.textContainer?.containerSize = NSSize(
            width: contentWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        body.textStorage?.setAttributedString(NSAttributedString(
            string: text,
            attributes: dailyGuidanceTextAttributes
        ))

        let bodyHeight: CGFloat
        if let textContainer = body.textContainer, let layoutManager = body.layoutManager {
            // 强制 TextKit 完成布局后才能得到所有换行后的真实高度。
            layoutManager.ensureLayout(for: textContainer)
            bodyHeight = max(ceil(layoutManager.usedRect(for: textContainer).height) + 2, baseFont.pointSize + 3)
        } else {
            bodyHeight = baseFont.pointSize + 3
        }
        body.frame.size.height = bodyHeight

        let viewHeight = dailyGuidanceVerticalPadding * 2 + bodyHeight
        let container = NSView(frame: NSRect(x: 0, y: 0, width: dailyGuidanceMenuWidth, height: viewHeight))
        container.addSubview(body)
        return container
    }

    /// 展示和编辑共用的文字属性，确保颜色、字号和斜体一致。
    private var dailyGuidanceTextAttributes: [NSAttributedString.Key: Any] {
        [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: dailyGuidanceColor,
            .obliqueness: 0.16
        ]
    }

    /// 根据当前 Mac 外观选择有足够对比度的暖黄色。
    private var dailyGuidanceColor: NSColor {
        let appearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        if appearance == .darkAqua {
            return NSColor(calibratedRed: 0.98, green: 0.73, blue: 0.22, alpha: 1)
        }
        return NSColor(calibratedRed: 0.58, green: 0.39, blue: 0.05, alpha: 1)
    }

    /// 从本地回退目录和 iCloud 读取今日指引并按文件修改时间合并。
    ///
    /// 较新的文件值覆盖较旧文件的同日期值；这样从本地迁移到 iCloud 时不会直接丢历史。
    private func loadDailyGuidance() {
        var storedGuidance: [(modifiedAt: Date, values: [String: String])] = []

        for fileURL in readableDataFileURLs(named: dailyGuidanceFileName) {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                continue
            }

            do {
                let data = try Data(contentsOf: fileURL)
                let values = try JSONDecoder().decode([String: String].self, from: data)
                markICloudFileReadable(fileURL)
                let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let modifiedAt = attributes?[.modificationDate] as? Date ?? .distantPast
                storedGuidance.append((modifiedAt, values))
            } catch {
                markICloudFileUnreadable(fileURL)
                NSLog("Could not load daily guidance from \(fileURL.path): \(error.localizedDescription)")
            }
        }

        var mergedGuidance: [String: String] = [:]
        for stored in storedGuidance.sorted(by: { $0.modifiedAt < $1.modifiedAt }) {
            // 从旧到新 merge，使闭包选择 newer 时得到最后修改文件的值。
            mergedGuidance.merge(stored.values) { _, newer in newer }
        }
        dailyGuidanceByDate = mergedGuidance
    }

    /// 把完整日期字典编码为可读、按 key 排序的 JSON，并写到首个可用目录。
    @discardableResult
    private func saveDailyGuidance(_ values: [String: String]) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            var data = try encoder.encode(values)
            data.append(0x0A)
            return writeDataFile(data, named: dailyGuidanceFileName)
        } catch {
            NSLog("Could not encode daily guidance: \(error.localizedDescription)")
            return nil
        }
    }

    /// 本地回退文件比 iCloud 新时，把合并结果同步回 iCloud。
    private func synchronizeDailyGuidanceToICloudIfNeeded() {
        guard shouldSynchronizeFallbackFileToICloud(named: dailyGuidanceFileName) else {
            return
        }
        _ = saveDailyGuidance(dailyGuidanceByDate)
    }

    /// 菜单打开时检查记录是否需要回迁 iCloud。
    private func synchronizeFallbackDataToICloudIfNeeded() {
        if shouldSynchronizeFallbackFileToICloud(named: recordsFileName) {
            _ = saveRecords()
        }
        synchronizeDailyGuidanceToICloudIfNeeded()
    }

    // MARK: - CloudKit 同步、冲突合并与迁移备份

    /// 下载 CloudKit 计时记录并与本地 JSON 合并，然后把记录写回两端。
    @MainActor
    private func synchronizeCloudData(reportErrors: Bool) async {
        guard cloudMigrationAllowed, !isSynchronizingCloud else { return }
        isSynchronizingCloud = true
        defer { isSynchronizingCloud = false }

        do {
            let fetchedSessions = try await cloudStore.fetchSessions()

            records = mergeRecordGroups([records, fetchedSessions.map(PomodoroRecord.init(cloudValue:))])

            guard saveRecords() != nil else {
                throw CocoaError(.fileWriteUnknown)
            }

            try await cloudStore.saveSessions(records.map(\.cloudValue))
            hasShownCloudSyncError = false
            rebuildMenu()
        } catch {
            NSLog("CloudKit synchronization failed: \(error.localizedDescription)")
            if reportErrors, !hasShownCloudSyncError {
                hasShownCloudSyncError = true
                showCloudSyncError()
            }
        }
    }

    /// CloudKit 首次运行前备份本地/iCloud Drive 记录 JSON，任一复制失败都不开始迁移。
    private func backupLegacyJSONBeforeCloudKitIfNeeded() -> Bool {
        if UserDefaults.standard.bool(forKey: cloudBackupMarkerKey) { return true }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backupDirectory = localDataDirectoryURL
            .appendingPathComponent("Legacy Backups", isDirectory: true)
            .appendingPathComponent(formatter.string(from: Date()), isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            var copiedPaths = Set<String>()
            for fileName in [recordsFileName] {
                for sourceURL in readableDataFileURLs(named: fileName)
                where FileManager.default.fileExists(atPath: sourceURL.path)
                    && copiedPaths.insert(sourceURL.standardizedFileURL.path).inserted {
                    let location = isICloudDataFile(sourceURL) ? "icloud" : "local"
                    let targetURL = backupDirectory.appendingPathComponent("\(location)-\(fileName)")
                    try FileManager.default.copyItem(at: sourceURL, to: targetURL)
                }
            }
            UserDefaults.standard.set(true, forKey: cloudBackupMarkerKey)
            return true
        } catch {
            NSLog("Could not back up legacy data before CloudKit migration: \(error.localizedDescription)")
            return false
        }
    }

    private func showCloudSyncError() {
        let alert = makeAlert()
        alert.messageText = "iCloud 数据暂时未同步"
        alert.informativeText = "本机 JSON 已安全保存，网络或 iCloud 恢复后会再次合并。"
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showCloudMigrationBackupError() {
        let alert = makeAlert()
        alert.messageText = "未开始 CloudKit 迁移"
        alert.informativeText = "原 JSON 文件备份失败。为保护现有数据，已保持本地模式且未上传。"
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// 今天对应的 JSON 日期 key。
    private var todayDateKey: String {
        recordDateFormatter.string(from: Date())
    }

    // MARK: - 记录菜单

    /// 构建今日摘要、今日记录、最近 30 天历史、今日指引历史和打开文件入口。
    private func addRecordsMenuItems() {
        let today = recordDateFormatter.string(from: Date())
        let insideItem = NSMenuItem(title: "番茄内时间：\(formattedPomodoroTimeToday())", action: nil, keyEquivalent: "")
        insideItem.isEnabled = false
        menu.addItem(insideItem)

        let outsideItem = NSMenuItem(title: "番茄外时间：\(formattedOutsidePomodoroTimeToday())", action: nil, keyEquivalent: "")
        outsideItem.isEnabled = false
        menu.addItem(outsideItem)

        let todayRecords = records.filter { $0.date == today }
        if todayRecords.isEmpty {
            let emptyItem = NSMenuItem(title: "今日暂无记录", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            let reversedRecords = Array(todayRecords.reversed())
            // 主菜单只放最近几条，避免菜单过长；全部记录仍可进入子菜单查看。
            let recentRecords = Array(reversedRecords.prefix(collapsedRecordsLimit))

            for record in recentRecords {
                addRecordMenuItem(record, to: menu)
            }
        }

        let todayRecordsItem = NSMenuItem(title: "今日全部记录（共 \(todayRecords.count) 条）", action: nil, keyEquivalent: "")
        let todayRecordsMenu = NSMenu()
        if todayRecords.isEmpty {
            let emptyItem = NSMenuItem(title: "今日暂无记录", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            todayRecordsMenu.addItem(emptyItem)
        } else {
            for record in todayRecords.reversed() {
                addRecordMenuItem(record, to: todayRecordsMenu)
            }
        }
        todayRecordsItem.submenu = todayRecordsMenu
        menu.addItem(todayRecordsItem)

        let historicalRecords = records.filter { $0.date != today }
        // 先按日期分组，再对日期倒序，形成“日期 → 当天记录”的两级菜单。
        let historicalRecordsByDate = Dictionary(grouping: historicalRecords, by: \PomodoroRecord.date)
        let historicalDates = historicalRecordsByDate.keys.sorted(by: >)
        let visibleHistoricalDates = historicalDates.prefix(historicalDateLimit)
        let olderDateCount = historicalDates.count - visibleHistoricalDates.count
        let historyItem = NSMenuItem(
            title: "历史记录（共 \(historicalDates.count) 天 / \(historicalRecords.count) 条）",
            action: nil,
            keyEquivalent: ""
        )
        let historyMenu = NSMenu()
        if historicalDates.isEmpty {
            let emptyItem = NSMenuItem(title: "暂无历史记录", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            historyMenu.addItem(emptyItem)
        } else {
            for date in visibleHistoricalDates {
                guard let dateRecords = historicalRecordsByDate[date] else {
                    continue
                }
                let weekday = recordDateFormatter.date(from: date)
                    .map { historyWeekdayFormatter.string(from: $0) }
                let weekdaySuffix = weekday.map { " \($0)" } ?? ""
                let dateItem = NSMenuItem(
                    title: "\(date)\(weekdaySuffix)（共 \(dateRecords.count) 条）",
                    action: nil,
                    keyEquivalent: ""
                )
                let dateMenu = NSMenu()
                for record in dateRecords.reversed() {
                    addRecordMenuItem(record, to: dateMenu)
                }
                dateItem.submenu = dateMenu
                historyMenu.addItem(dateItem)
            }

            if olderDateCount > 0 {
                // 超过 30 天的数据没有删除，只是不继续铺开菜单；用户可打开 JSON 查看。
                historyMenu.addItem(.separator())
                let olderRecordsItem = NSMenuItem(
                    title: "更早记录（共 \(olderDateCount) 天）...",
                    action: #selector(openRecordsFile),
                    keyEquivalent: ""
                )
                olderRecordsItem.target = self
                historyMenu.addItem(olderRecordsItem)
            }
        }
        historyItem.submenu = historyMenu
        menu.addItem(historyItem)

        addDailyGuidanceHistoryMenuItem()

        let openRecordsItem = NSMenuItem(title: "打开记录文件...", action: #selector(openRecordsFile), keyEquivalent: "")
        openRecordsItem.target = self
        menu.addItem(openRecordsItem)
    }

    /// 添加最近 30 个自然日内非空的今日指引历史子菜单。
    private func addDailyGuidanceHistoryMenuItem() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: Date())
        let earliestVisibleDate = calendar.date(
            byAdding: .day,
            value: -(dailyGuidanceHistoryDayLimit - 1),
            to: today
        ) ?? today

        let entries: [(dateKey: String, date: Date, text: String)] = dailyGuidanceByDate.compactMap { dateKey, text in
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty, let date = recordDateFormatter.date(from: dateKey) else {
                return nil
            }

            let startOfDate = calendar.startOfDay(for: date)
            // 排除未来日期和 30 天窗口之前的数据，但绝不修改原字典。
            guard startOfDate >= earliestVisibleDate, startOfDate <= today else {
                return nil
            }
            return (dateKey, startOfDate, text)
        }
        .sorted { $0.date > $1.date }

        let historyItem = NSMenuItem(
            title: "今日指引记录（近 \(dailyGuidanceHistoryDayLimit) 天）",
            action: nil,
            keyEquivalent: ""
        )
        let historyMenu = NSMenu()

        if entries.isEmpty {
            let emptyItem = NSMenuItem(title: "暂无今日指引记录", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            historyMenu.addItem(emptyItem)
        } else {
            for entry in entries {
                let weekday = historyWeekdayFormatter.string(from: entry.date)
                let dateItem = NSMenuItem(
                    title: "\(entry.dateKey) \(weekday)",
                    action: nil,
                    keyEquivalent: ""
                )
                let dateMenu = NSMenu()
                // 复用今天正文的 520 点多行视图，历史展示样式完全一致。
                let guidanceItem = NSMenuItem()
                guidanceItem.view = makeDailyGuidanceMenuView(text: entry.text)
                guidanceItem.isEnabled = false
                dateMenu.addItem(guidanceItem)
                dateItem.submenu = dateMenu
                historyMenu.addItem(dateItem)
            }
        }

        historyItem.submenu = historyMenu
        menu.addItem(historyItem)
    }

    /// 组合带彩色圆点的富文本菜单标题。
    private func recordMenuTitle(dotColor: NSColor, text: String) -> NSAttributedString {
        let title = NSMutableAttributedString()
        title.append(NSAttributedString(
            string: "● ",
            attributes: [
                .foregroundColor: dotColor,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            ]
        ))
        title.append(NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.menuFont(ofSize: 0)
            ]
        ))
        return title
    }

    /// 把一条记录格式化后加入指定菜单。
    private func addRecordMenuItem(_ record: PomodoroRecord, to targetMenu: NSMenu) {
        let noteSuffix = record.note.isEmpty ? "" : " · \(record.note)"
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.attributedTitle = recordMenuTitle(
            dotColor: record.menuDotColor,
            text: "\(menuTimeRangeText(record)) · \(record.displayTitle) · \(recordDurationMinutes(record)) 分钟\(noteSuffix)"
        )
        item.isEnabled = false
        targetMenu.addItem(item)
    }

    /// 从完整日期时间中截取到分钟，用于菜单紧凑显示。
    private func menuTimeText(_ dateTime: String) -> String {
        String(dateTime.prefix(16))
    }

    /// 拼出 `yyyy-MM-dd HH:mm-HH:mm` 的时间范围。
    private func menuTimeRangeText(_ record: PomodoroRecord) -> String {
        let startedAt = menuTimeText(record.startedAt)
        let endedAt = menuTimeText(record.endedAt)
        let endTime = endedAt.count >= 16 ? String(endedAt.suffix(5)) : endedAt
        return "\(startedAt)-\(endTime)"
    }

    /// 菜单只展示整分钟；JSON 仍保留精确秒数。
    private func recordDurationMinutes(_ record: PomodoroRecord) -> Int {
        record.durationSeconds / 60
    }

    // MARK: - 当前会话时间计算

    /// 计算当前会话真正运行的秒数，扣除所有暂停片段。
    ///
    /// 使用开始/暂停时间差而不是 Timer tick 次数，因此系统睡眠或主线程繁忙不会造成漂移。
    private func activeSessionSeconds(at date: Date = Date()) -> Int {
        guard let sessionStartedAt else {
            return 0
        }

        var pausedSeconds = sessionPausedSeconds
        if let sessionPausedAt {
            // 当前仍处于暂停时，把尚未结算的暂停片段也临时计入。
            pausedSeconds += max(0, Int(date.timeIntervalSince(sessionPausedAt)))
        }

        let elapsedSeconds = max(0, Int(date.timeIntervalSince(sessionStartedAt)))
        return max(0, elapsedSeconds - pausedSeconds)
    }

    // MARK: - 记录读取、合并与写入

    /// 把当前会话转换为记录并触发保存。
    private func addTimerRecord(type: String, durationSeconds: Int) {
        let startedAt = sessionStartedAt ?? Date().addingTimeInterval(-TimeInterval(durationSeconds))
        let endedAt = Date()
        records.append(PomodoroRecord(
            startedAt: recordDateTimeFormatter.string(from: startedAt),
            endedAt: recordDateTimeFormatter.string(from: endedAt),
            date: recordDateFormatter.string(from: endedAt),
            type: type,
            durationSeconds: durationSeconds,
            note: sessionNote
        ))
        saveRecords()
        Task { @MainActor [weak self] in
            await self?.synchronizeCloudData(reportErrors: true)
        }
    }

    /// 启动时读取本地/iCloud记录，并兼容迁移旧 UserDefaults 数据。
    private func loadRecords() {
        var recordGroups = loadRecordGroupsFromDataFiles()

        let legacyRecords = loadLegacyRecordsFromUserDefaults()
        if let legacyRecords {
            recordGroups.append(legacyRecords)
        }

        records = mergeRecordGroups(recordGroups)
        guard !recordGroups.isEmpty else {
            return
        }

        // 只把合并结果写入 JSON；旧 UserDefaults 也保留，便于 CloudKit 迁移后回滚。
        if legacyRecords != nil {
            _ = saveRecords()
        }
    }

    /// 菜单打开时吸收磁盘上的新记录，同时保留当前内存中尚未出现的记录。
    private func refreshRecordsFromDataFiles() {
        let storedRecordGroups = loadRecordGroupsFromDataFiles()
        guard !storedRecordGroups.isEmpty else {
            return
        }
        records = mergeRecordGroups(storedRecordGroups + [records])
    }

    /// 保存前再次合并磁盘，减少多来源写入时相互覆盖的概率。
    @discardableResult
    private func saveRecords() -> URL? {
        records = mergeRecordGroups(loadRecordGroupsFromDataFiles() + [records])
        return writeDataFile(Data(renderRecordsJSON().utf8), named: recordsFileName)
    }

    /// 分别读取所有候选 records.json；单个文件损坏不会阻止读取另一个。
    private func loadRecordGroupsFromDataFiles() -> [[PomodoroRecord]] {
        var recordGroups: [[PomodoroRecord]] = []

        for fileURL in readableDataFileURLs(named: recordsFileName) {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                continue
            }

            do {
                let data = try Data(contentsOf: fileURL)
                recordGroups.append(try recordsDecoder.decode([PomodoroRecord].self, from: data))
                markICloudFileReadable(fileURL)
            } catch {
                markICloudFileUnreadable(fileURL)
                NSLog("Could not load pomodoro records from \(fileURL.path): \(error.localizedDescription)")
            }
        }

        return recordGroups
    }

    /// 对多组记录去重并按结束时间、开始时间稳定排序。
    ///
    /// 使用跨设备稳定 recordID 去重；旧 JSON 会在解码时补齐兼容 ID。
    private func mergeRecordGroups(_ groups: [[PomodoroRecord]]) -> [PomodoroRecord] {
        var seenRecordIDs = Set<String>()
        var mergedRecords: [PomodoroRecord] = []

        for group in groups {
            for record in group where seenRecordIDs.insert(record.recordID).inserted {
                mergedRecords.append(record)
            }
        }

        return mergedRecords.sorted {
            if $0.endedAt == $1.endedAt {
                return $0.startedAt < $1.startedAt
            }
            return $0.endedAt < $1.endedAt
        }
    }

    /// 手工渲染可读 JSON，以固定字段顺序和空格风格。
    ///
    /// JSONEncoder 不保证字段顺序；这里稳定输出便于用户手工维护和版本比较。
    private func renderRecordsJSON() -> String {
        guard !records.isEmpty else {
            return "[]\n"
        }

        let renderedRecords = records.map { record in
            """
              {
                "id" : "\(jsonEscaped(record.recordID))",
                "date" : "\(jsonEscaped(record.date))",
                "startedAt" : "\(jsonEscaped(record.startedAt))",
                "endedAt" : "\(jsonEscaped(record.endedAt))",
                "durationSeconds" : \(record.durationSeconds),
                "durationMinutes" : \(record.durationMinutes),
                "type" : "\(jsonEscaped(record.type))",
                "note" : "\(jsonEscaped(record.note))"
              }
            """
        }

        return "[\n" + renderedRecords.joined(separator: ",\n") + "\n]\n"
    }

    /// 按 JSON 标准转义字符串中的引号、反斜线、换行和控制字符。
    private func jsonEscaped(_ value: String) -> String {
        var escaped = ""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"":
                escaped += "\\\""
            case "\\":
                escaped += "\\\\"
            case "\n":
                escaped += "\\n"
            case "\r":
                escaped += "\\r"
            case "\t":
                escaped += "\\t"
            default:
                if scalar.value < 0x20 {
                    escaped += String(format: "\\u%04X", scalar.value)
                } else {
                    escaped.unicodeScalars.append(scalar)
                }
            }
        }
        return escaped
    }

    // MARK: - 今日时间统计

    /// 从当天第一次计时开始到现在，扣除番茄内时长，得到“番茄外时间”。
    private func formattedOutsidePomodoroTimeToday() -> String {
        let seconds = outsidePomodoroSecondsToday()
        return formattedDuration(seconds)
    }

    /// 今天已记录和正在进行的所有会话总时长。
    private func formattedPomodoroTimeToday() -> String {
        let seconds = pomodoroSecondsToday()
        return formattedDuration(seconds)
    }

    /// 把秒数转换为用户可读的小时和分钟。
    private func formattedDuration(_ seconds: Int) -> String {
        return "\(seconds / 3600) 小时 \((seconds % 3600) / 60) 分钟"
    }

    /// 计算从今天首次番茄开始后，没有落在番茄记录中的时间。
    private func outsidePomodoroSecondsToday() -> Int {
        guard let firstStart = firstPomodoroStartToday() else {
            return 0
        }

        let elapsedSinceFirstStart = max(0, Int(Date().timeIntervalSince(firstStart)))
        return max(0, elapsedSinceFirstStart - pomodoroSecondsToday())
    }

    /// 在完成记录和当前会话中寻找今天最早的开始时间。
    private func firstPomodoroStartToday() -> Date? {
        let today = recordDateFormatter.string(from: Date())
        var firstStart: Date?

        for record in records where record.date == today {
            guard let startedAt = recordDateTimeFormatter.date(from: record.startedAt) else {
                continue
            }

            if firstStart == nil || startedAt < firstStart! {
                firstStart = startedAt
            }
        }

        if let sessionStartedAt, recordDateFormatter.string(from: sessionStartedAt) == today {
            if firstStart == nil || sessionStartedAt < firstStart! {
                firstStart = sessionStartedAt
            }
        }

        return firstStart
    }

    /// 合计今天完成记录和当前活动会话的运行秒数。
    private func pomodoroSecondsToday() -> Int {
        let today = recordDateFormatter.string(from: Date())
        var pomodoroSeconds = 0

        for record in records where record.date == today {
            pomodoroSeconds += max(0, record.durationSeconds)
        }

        if let sessionStartedAt, recordDateFormatter.string(from: sessionStartedAt) == today {
            pomodoroSeconds += activeSessionSeconds()
        }

        return pomodoroSeconds
    }

    /// 读取早期版本保存在 UserDefaults 的记录，供一次性迁移。
    private func loadLegacyRecordsFromUserDefaults() -> [PomodoroRecord]? {
        guard let data = UserDefaults.standard.data(forKey: recordsStorageKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return try? decoder.decode([PomodoroRecord].self, from: data)
    }

    // MARK: - iCloud 与本地回退目录

    /// 当前用户 iCloud Drive 在 macOS 文件系统中的标准容器位置。
    ///
    /// 这里不会主动创建 iCloud 根目录；若用户未启用 iCloud Drive，就使用本地回退目录。
    private var iCloudDriveDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    /// iCloud Drive 可用时返回 `PomodoroBar/` 子目录，否则返回 nil。
    private var iCloudDataDirectoryURL: URL? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: iCloudDriveDirectoryURL.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            return nil
        }

        return iCloudDriveDirectoryURL
            .appendingPathComponent(iCloudDataDirectoryName, isDirectory: true)
    }

    /// 返回读取候选：先本地、后 iCloud。
    ///
    /// 调用者通常会同时读出并合并，而不是“找到一个就停止”，以兼容迁移中的两份数据。
    private func readableDataFileURLs(named fileName: String) -> [URL] {
        var fileURLs = [localDataDirectoryURL.appendingPathComponent(fileName)]
        if let iCloudDataDirectoryURL {
            fileURLs.append(iCloudDataDirectoryURL.appendingPathComponent(fileName))
        }
        return fileURLs
    }

    /// 判断 URL 是否正好位于本应用的 iCloud 数据目录。
    private func isICloudDataFile(_ fileURL: URL) -> Bool {
        guard let iCloudDataDirectoryURL else {
            return false
        }
        return fileURL.deletingLastPathComponent().standardizedFileURL
            == iCloudDataDirectoryURL.standardizedFileURL
    }

    /// 某个 iCloud 文件成功读取后，解除本次运行期间的写入回避标记。
    private func markICloudFileReadable(_ fileURL: URL) {
        if isICloudDataFile(fileURL) {
            unreadableICloudFileNames.remove(fileURL.lastPathComponent)
        }
    }

    /// iCloud 文件存在但不可读/JSON 损坏时做标记，防止随后保存直接覆盖它。
    private func markICloudFileUnreadable(_ fileURL: URL) {
        if isICloudDataFile(fileURL) {
            unreadableICloudFileNames.insert(fileURL.lastPathComponent)
        }
    }

    /// 返回按优先级排列的写入目标。
    ///
    /// 正常只写 iCloud；iCloud 不可用或该文件本次读取失败时写本地回退目录。
    private func writableDataFileURLs(named fileName: String) -> [URL] {
        let localFileURL = localDataDirectoryURL.appendingPathComponent(fileName)
        guard let iCloudDataDirectoryURL,
              !unreadableICloudFileNames.contains(fileName) else {
            return [localFileURL]
        }

        return [iCloudDataDirectoryURL.appendingPathComponent(fileName), localFileURL]
    }

    /// 判断本地回退文件是否需要同步到 iCloud。
    ///
    /// iCloud 文件不存在或本地修改时间更新时才同步；不会删除本地原文件。
    private func shouldSynchronizeFallbackFileToICloud(named fileName: String) -> Bool {
        guard let iCloudDataDirectoryURL,
              !unreadableICloudFileNames.contains(fileName) else {
            return false
        }

        let localFileURL = localDataDirectoryURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: localFileURL.path) else {
            return false
        }

        let iCloudFileURL = iCloudDataDirectoryURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: iCloudFileURL.path) else {
            return true
        }

        return modificationDate(of: localFileURL) > modificationDate(of: iCloudFileURL)
    }

    /// 获取文件修改时间；读取失败用 distantPast，使有效文件自然获胜。
    private func modificationDate(of fileURL: URL) -> Date {
        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attributes?[.modificationDate] as? Date ?? .distantPast
    }

    /// 原子写入第一个可用目标，并返回实际 URL。
    ///
    /// `Data.write(.atomic)` 先写临时文件再替换，减少进程中断留下半份 JSON 的风险。
    @discardableResult
    private func writeDataFile(_ data: Data, named fileName: String) -> URL? {
        for fileURL in writableDataFileURLs(named: fileName) {
            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: fileURL, options: .atomic)
                return fileURL
            } catch {
                NSLog("Could not save \(fileName) to \(fileURL.path): \(error.localizedDescription)")
            }
        }

        return nil
    }

    // MARK: - JSON 与日期工具

    /// 记录解码器保留早期 ISO8601 Date 兼容策略。
    private var recordsDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// JSON 日期 key 的固定公历格式。
    private var recordDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    /// 记录起止时间的固定格式。
    private var recordDateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    // MARK: - NSMenu actions

    /// 前台 Timer 每秒调用的选择器。
    @objc private func tick() {
        if isCountUp {
            // 自由计时没有归零条件，只需刷新状态栏。
            updateStatusTitle()
            return
        }

        let plannedDurationSeconds = sessionPlannedDurationSeconds ?? duration(for: mode)
        remainingSeconds = max(0, plannedDurationSeconds - activeSessionSeconds())

        guard remainingSeconds > 0 else {
            completeCurrentMode()
            return
        }

        updateStatusTitle()

        if remainingSeconds == 0 {
            completeCurrentMode()
        }
    }

    /// 从 00:00 开始自由正计时。
    @objc private func startCountUpTimer() {
        guard !hasActiveSession else {
            return
        }
        isCountUp = true
        remainingSeconds = 0
        sessionStartedAt = nil
        sessionPlannedDurationSeconds = nil
        startTimer()
    }

    /// 空格快捷键入口：无会话时开始自由计时，有会话时暂停/继续。
    @objc private func toggleTimer() {
        guard hasActiveSession else {
            startCountUpTimer()
            return
        }
        isRunning ? pauseTimer() : startTimer()
    }

    /// 用户手动结束当前会话。
    ///
    /// 小于三分钟时二次确认且不写记录；达到门槛才持久化。
    @objc private func endCurrentSession() {
        guard hasActiveSession else {
            return
        }

        let elapsedSeconds = activeSessionSeconds()

        let endedCountUp = isCountUp
        if elapsedSeconds < minimumRecordedSessionSeconds {
            let alert = makeAlert()
            alert.messageText = "结束本段？"
            alert.informativeText = "计时时长不足 \(minimumRecordedSessionSeconds / 60) 分钟，结束后不会写入记录。"
            alert.addButton(withTitle: "结束")
            alert.addButton(withTitle: "取消")
            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else {
                return
            }
        }

        if elapsedSeconds >= minimumRecordedSessionSeconds {
            addTimerRecord(
                type: endedCountUp ? "count_up" : mode.recordType,
                durationSeconds: elapsedSeconds
            )
        }

        remainingSeconds = endedCountUp ? 0 : duration(for: mode)
        stopTimer()
    }

    /// 使用简单单行 Alert 编辑当前时段备注。
    @objc private func editSessionNote() {
        let alert = makeAlert()
        alert.messageText = "本段备注"
        alert.informativeText = "备注会随本段完成记录一起保存。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = sessionNote
        input.placeholderString = "例如：写方案、读论文、修 bug"
        alert.accessoryView = input

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            sessionNote = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            rebuildMenu()
        }
    }

    /// 使用多行 NSTextView 编辑今天的指引。
    ///
    /// 编辑框与菜单显示共用宽度、边距和 attributed-string 属性，因此同一文本换行一致。
    /// 保存前重新加载文件，尽量合并其他设备刚写入的日期；失败时恢复内存旧值。
    @objc private func editDailyGuidance() {
        let alert = makeAlert()
        alert.messageText = "今日指引"
        let weekday = historyWeekdayFormatter.string(from: Date())
        alert.informativeText = "\(todayDateKey) \(weekday) · 支持换行；保存空内容可清除。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: dailyGuidanceMenuWidth, height: 220))
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 8
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.borderColor = NSColor.separatorColor.cgColor

        let textView = NSTextView(frame: scrollView.contentView.bounds)
        // TextView 宽度固定，垂直方向允许内容增长并由外层 ScrollView 滚动。
        textView.minSize = NSSize(width: dailyGuidanceMenuWidth, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: dailyGuidanceMenuWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(
            width: dailyGuidanceHorizontalPadding,
            height: dailyGuidanceVerticalPadding
        )
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = false
        // 明确使用和菜单正文相同的“可排版内容宽度”。
        textView.textContainer?.containerSize = NSSize(
            width: dailyGuidanceMenuWidth - dailyGuidanceHorizontalPadding * 2,
            height: CGFloat.greatestFiniteMagnitude
        )
        let existingGuidance = dailyGuidanceByDate[todayDateKey] ?? ""
        textView.textStorage?.setAttributedString(NSAttributedString(
            string: existingGuidance,
            attributes: dailyGuidanceTextAttributes
        ))
        textView.typingAttributes = dailyGuidanceTextAttributes
        textView.insertionPointColor = dailyGuidanceColor
        textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
        scrollView.documentView = textView
        alert.accessoryView = scrollView

        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = textView
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let guidance = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        // 重新读盘后只覆盖今天，保留刚从其他来源同步来的日期。
        loadDailyGuidance()
        let previousGuidance = dailyGuidanceByDate
        if guidance.isEmpty {
            dailyGuidanceByDate[todayDateKey] = ""
        } else {
            dailyGuidanceByDate[todayDateKey] = guidance
        }
        guard saveDailyGuidance(dailyGuidanceByDate) != nil else {
            dailyGuidanceByDate = previousGuidance
            showDailyGuidanceSaveError()
            return
        }
        rebuildMenu()
    }

    /// 保存失败时显示不会自动关闭或覆盖数据的明确提示。
    private func showDailyGuidanceSaveError() {
        let alert = makeAlert()
        alert.messageText = "无法保存今日指引"
        alert.informativeText = "请检查 iCloud Drive 或本地数据目录是否可写。"
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// 先保存/合并记录，再用系统默认应用打开实际 JSON 文件。
    @objc private func openRecordsFile() {
        let existingFileURL = readableDataFileURLs(named: recordsFileName)
            .reversed()
            .first { FileManager.default.fileExists(atPath: $0.path) }
        guard let recordsFileURL = saveRecords() ?? existingFileURL else {
            let alert = makeAlert()
            alert.messageText = "无法保存记录文件"
            alert.informativeText = "请检查 iCloud Drive 或本地数据目录是否可写。"
            alert.addButton(withTitle: "好")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }

        if !NSWorkspace.shared.open(recordsFileURL) {
            let alert = makeAlert()
            alert.messageText = "无法打开记录文件"
            alert.informativeText = recordsFileURL.path
            alert.addButton(withTitle: "好")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    /// 菜单模式快捷入口。
    @objc private func selectFocus() {
        startMode(.focus)
    }

    @objc private func selectShortBreak() {
        startMode(.shortBreak)
    }

    @objc private func selectLongBreak() {
        startMode(.longBreak)
    }

    /// 弹窗调整活动倒计时的计划总长度。
    @objc private func adjustActiveCountdown() {
        guard hasActiveSession && !isCountUp else {
            return
        }

        let alert = makeAlert()
        alert.messageText = "调整时间"
        alert.informativeText = "请输入调整的分钟数（-180 到 180；正数增加，负数缩短，不能为 0）。"
        alert.addButton(withTitle: "调整")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        input.stringValue = "5"
        input.placeholderString = "5 或 -5"
        alert.accessoryView = input

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let minutes = Int(trimmed), minutes != 0, (-180...180).contains(minutes) else {
                showInvalidAdjustmentDurationAlert()
                return
            }

            let adjustmentSeconds = minutes * 60
            // 不能把总时长缩到已经运行时间之前，否则剩余时间会为零或负数。
            guard remainingSeconds + adjustmentSeconds > 0 else {
                showInvalidAdjustmentDurationAlert()
                return
            }

            remainingSeconds += adjustmentSeconds
            let plannedDurationSeconds = sessionPlannedDurationSeconds ?? duration(for: mode)
            sessionPlannedDurationSeconds = plannedDurationSeconds + adjustmentSeconds
            updateStatusTitle()
            rebuildMenu()
        }
    }

    /// 所有时长输入错误共用的提示。
    private func showInvalidAdjustmentDurationAlert() {
        let alert = makeAlert()
        alert.messageText = "调整时长无效"
        alert.informativeText = "请输入 -180 到 180 之间的非零整数分钟，并确保调整后仍有剩余时间。"
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// 退出菜单栏应用。
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - 手工启动 AppKit 事件循环

// 此项目没有 @main App 类型；swiftc 编译 main.swift 后从这些顶层语句开始执行。
let app = NSApplication.shared
let delegate = PomodoroController()
app.delegate = delegate
app.run()
