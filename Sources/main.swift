import AppKit
import Foundation

enum PomodoroMode: String {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"

    var next: PomodoroMode {
        switch self {
        case .focus:
            return .shortBreak
        case .shortBreak, .longBreak:
            return .focus
        }
    }

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

struct PomodoroRecord: Codable {
    let startedAt: String
    let endedAt: String
    let date: String
    let type: String
    let durationSeconds: Int
    let durationMinutes: Int
    let note: String

    enum CodingKeys: String, CodingKey {
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

    init(startedAt: String, endedAt: String, date: String, type: String, durationSeconds: Int, note: String) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.date = date
        self.type = type
        self.durationSeconds = durationSeconds
        self.durationMinutes = durationSeconds / 60
        self.note = note
    }

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
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
            ?? durationMinutes * 60
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "focus"
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? String(endedAt.prefix(10))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        try container.encode(type, forKey: .type)
        try container.encode(note, forKey: .note)
    }

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

    private static func makeDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func makeDateTimeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

final class PomodoroController: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private var timer: Timer?
    private var mode: PomodoroMode = .focus
    private var isCountUp = false
    private var isRunning = false
    private var hasActiveSession = false
    private var focusSessions = 0
    private var remainingSeconds = 25 * 60
    private var sessionStartedAt: Date?
    private var sessionPlannedDurationSeconds: Int?
    private var sessionPausedAt: Date?
    private var sessionPausedSeconds = 0
    private var sessionNote = ""
    private var records: [PomodoroRecord] = []
    private let focusDurationMinutes = 25
    private let recordsStorageKey = "pomodoro.records"
    private let recordsDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".pomodoro-status-bar", isDirectory: true)
    private let recordsFileName = "records.json"

    private let shortBreakDurationSeconds = 5 * 60
    private let longBreakDurationSeconds = 15 * 60
    private let minimumRecordedSessionSeconds = 3 * 60
    private let collapsedRecordsLimit = 10
    private let historicalDateLimit = 30

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
    private lazy var applicationIcon: NSImage? = {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()
    private lazy var historyWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        terminateOtherInstances()
        configureApplicationIcon()
        configureNotifications()
        loadRecords()
        remainingSeconds = duration(for: .focus)
        configureStatusItem()
        rebuildMenu()
        updateStatusTitle()
    }

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

    private func configureApplicationIcon() {
        NSApp.applicationIconImage = applicationIcon
    }

    private func makeAlert() -> NSAlert {
        let alert = NSAlert()
        alert.icon = applicationIcon
        return alert
    }

    private func configureNotifications() {
        NSUserNotificationCenter.default.delegate = self
    }

    private func configureStatusItem() {
        statusItem.autosaveName = "local.codex.PomodoroStatusBar.statusItem"
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        statusItem.button?.toolTip = "番茄计时"
        statusItem.menu = menu
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
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

    private func startTimer() {
        let now = Date()
        isRunning = true
        hasActiveSession = true
        if sessionStartedAt == nil {
            sessionStartedAt = now
            sessionPlannedDurationSeconds = isCountUp ? nil : duration(for: mode)
        }
        if let sessionPausedAt {
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

    private func pauseTimer() {
        isRunning = false
        sessionPausedAt = Date()
        timer?.invalidate()
        timer = nil
        updateStatusTitle()
        rebuildMenu()
    }

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

    private func setMode(_ nextMode: PomodoroMode) {
        mode = nextMode
        remainingSeconds = duration(for: nextMode)
        stopTimer()
    }

    private func startMode(_ nextMode: PomodoroMode) {
        guard !hasActiveSession else {
            return
        }
        isCountUp = false
        setMode(nextMode)
        startTimer()
    }

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

    private func showCompletionNotification(completedMode: PomodoroMode, nextMode: PomodoroMode) {
        let notification = NSUserNotification()
        notification.title = completedMode == .focus ? "专注完成" : "休息完成"
        notification.informativeText = "下一段：\(nextMode.menuTitle)"
        notification.soundName = NSUserNotificationDefaultSoundName
        notification.deliveryDate = Date()
        NSUserNotificationCenter.default.deliver(notification)
    }

    func userNotificationCenter(
        _ center: NSUserNotificationCenter,
        shouldPresent notification: NSUserNotification
    ) -> Bool {
        true
    }

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
        iconAttachment.image = isRunning || !hasActiveSession ? tomatoStatusIcon : pauseStatusIcon
        iconAttachment.bounds = NSRect(x: 0, y: -2.5, width: 15, height: 15)
        title.append(NSAttributedString(attachment: iconAttachment))

        if isRunning || hasActiveSession {
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

        let openRecordsItem = NSMenuItem(title: "打开记录文件...", action: #selector(openRecordsFile), keyEquivalent: "")
        openRecordsItem.target = self
        menu.addItem(openRecordsItem)
    }

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

    private func menuTimeText(_ dateTime: String) -> String {
        String(dateTime.prefix(16))
    }

    private func menuTimeRangeText(_ record: PomodoroRecord) -> String {
        let startedAt = menuTimeText(record.startedAt)
        let endedAt = menuTimeText(record.endedAt)
        let endTime = endedAt.count >= 16 ? String(endedAt.suffix(5)) : endedAt
        return "\(startedAt)-\(endTime)"
    }

    private func recordDurationMinutes(_ record: PomodoroRecord) -> Int {
        record.durationSeconds / 60
    }

    private func activeSessionSeconds(at date: Date = Date()) -> Int {
        guard let sessionStartedAt else {
            return 0
        }

        var pausedSeconds = sessionPausedSeconds
        if let sessionPausedAt {
            pausedSeconds += max(0, Int(date.timeIntervalSince(sessionPausedAt)))
        }

        let elapsedSeconds = max(0, Int(date.timeIntervalSince(sessionStartedAt)))
        return max(0, elapsedSeconds - pausedSeconds)
    }

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
    }

    private func loadRecords() {
        if let data = try? Data(contentsOf: recordsFileURL) {
            records = (try? recordsDecoder.decode([PomodoroRecord].self, from: data)) ?? []
            saveRecords()
            return
        }

        migrateRecordsFromUserDefaults()
    }

    private func saveRecords() {
        do {
            try FileManager.default.createDirectory(
                at: recordsDirectoryURL,
                withIntermediateDirectories: true
            )
            let data = Data(renderRecordsJSON().utf8)
            try data.write(to: recordsFileURL, options: .atomic)
        } catch {
            NSLog("Could not save pomodoro records: \(error.localizedDescription)")
        }
    }

    private func renderRecordsJSON() -> String {
        guard !records.isEmpty else {
            return "[]\n"
        }

        let renderedRecords = records.map { record in
            """
              {
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

    private func formattedOutsidePomodoroTimeToday() -> String {
        let seconds = outsidePomodoroSecondsToday()
        return formattedDuration(seconds)
    }

    private func formattedPomodoroTimeToday() -> String {
        let seconds = pomodoroSecondsToday()
        return formattedDuration(seconds)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        return "\(seconds / 3600) 小时 \((seconds % 3600) / 60) 分钟"
    }

    private func outsidePomodoroSecondsToday() -> Int {
        guard let firstStart = firstPomodoroStartToday() else {
            return 0
        }

        let elapsedSinceFirstStart = max(0, Int(Date().timeIntervalSince(firstStart)))
        return max(0, elapsedSinceFirstStart - pomodoroSecondsToday())
    }

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

    private func migrateRecordsFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: recordsStorageKey) else {
            records = []
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        records = (try? decoder.decode([PomodoroRecord].self, from: data)) ?? []
        saveRecords()
        UserDefaults.standard.removeObject(forKey: recordsStorageKey)
    }

    private var recordsFileURL: URL {
        recordsDirectoryURL.appendingPathComponent(recordsFileName)
    }

    private var recordsDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private var recordDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var recordDateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    @objc private func tick() {
        if isCountUp {
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

    @objc private func toggleTimer() {
        guard hasActiveSession else {
            startCountUpTimer()
            return
        }
        isRunning ? pauseTimer() : startTimer()
    }

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

    @objc private func openRecordsFile() {
        if !FileManager.default.fileExists(atPath: recordsFileURL.path) {
            saveRecords()
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

    @objc private func selectFocus() {
        startMode(.focus)
    }

    @objc private func selectShortBreak() {
        startMode(.shortBreak)
    }

    @objc private func selectLongBreak() {
        startMode(.longBreak)
    }

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

    private func showInvalidAdjustmentDurationAlert() {
        let alert = makeAlert()
        alert.messageText = "调整时长无效"
        alert.informativeText = "请输入 -180 到 180 之间的非零整数分钟，并确保调整后仍有剩余时间。"
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = PomodoroController()
app.delegate = delegate
app.run()
