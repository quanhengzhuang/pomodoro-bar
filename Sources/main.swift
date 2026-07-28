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
    let durationMinutes: Int
    let note: String

    enum CodingKeys: String, CodingKey {
        case date
        case startedAt
        case endedAt
        case durationMinutes
        case type
        case note
        case completedAt
        case title
    }

    init(startedAt: String, endedAt: String, date: String, type: String, durationMinutes: Int, note: String) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.date = date
        self.type = type
        self.durationMinutes = durationMinutes
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
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "focus"
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? String(endedAt.prefix(10))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
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
        default:
            return type
        }
    }

    var menuDotColor: NSColor {
        type == "focus"
            ? NSColor(calibratedRed: 0.88, green: 0.20, blue: 0.18, alpha: 1)
            : NSColor(calibratedRed: 0.10, green: 0.54, blue: 0.38, alpha: 1)
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
    private var isRunning = false
    private var hasActiveSession = false
    private var focusSessions = 0
    private var remainingSeconds = 25 * 60
    private var sessionStartedAt: Date?
    private var sessionPlannedDurationSeconds: Int?
    private var sessionNote = ""
    private var records: [PomodoroRecord] = []
    private var focusDurationMinutes = 25
    private let recordsStorageKey = "pomodoro.records"
    private let focusDurationStorageKey = "pomodoro.focusDurationMinutes"
    private let recordsDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".pomodoro-status-bar", isDirectory: true)
    private let recordsFileName = "records.json"

    private let shortBreakDurationSeconds = 5 * 60
    private let longBreakDurationSeconds = 15 * 60
    private let collapsedRecordsLimit = 10

    private lazy var statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private lazy var startPauseMenuItem = NSMenuItem(
        title: "开始",
        action: #selector(toggleTimer),
        keyEquivalent: " "
    )
    private lazy var tomatoStatusIcon = makeTomatoStatusIcon()
    private lazy var pauseStatusIcon = makePauseStatusIcon()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureNotifications()
        loadPreferences()
        loadRecords()
        remainingSeconds = duration(for: .focus)
        configureStatusItem()
        rebuildMenu()
        updateStatusTitle()
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

        startPauseMenuItem.target = self
        startPauseMenuItem.title = isRunning ? "暂停" : "开始"
        menu.addItem(startPauseMenuItem)

        let resetItem = NSMenuItem(title: "重置", action: #selector(resetTimer), keyEquivalent: "r")
        resetItem.target = self
        menu.addItem(resetItem)

        let skipItem = NSMenuItem(title: "跳到下一段", action: #selector(skipToNextMode), keyEquivalent: "n")
        skipItem.target = self
        menu.addItem(skipItem)

        let noteItem = NSMenuItem(title: sessionNote.isEmpty ? "设置本段备注..." : "修改本段备注...", action: #selector(editSessionNote), keyEquivalent: "e")
        noteItem.target = self
        menu.addItem(noteItem)

        menu.addItem(.separator())

        let focusItem = NSMenuItem(title: "专注 \(focusDurationMinutes) 分钟", action: #selector(selectFocus), keyEquivalent: "1")
        focusItem.target = self
        focusItem.state = mode == .focus ? .on : .off
        menu.addItem(focusItem)

        let shortBreakItem = NSMenuItem(title: "短休息 5 分钟", action: #selector(selectShortBreak), keyEquivalent: "2")
        shortBreakItem.target = self
        shortBreakItem.state = mode == .shortBreak ? .on : .off
        menu.addItem(shortBreakItem)

        let longBreakItem = NSMenuItem(title: "长休息 15 分钟", action: #selector(selectLongBreak), keyEquivalent: "3")
        longBreakItem.target = self
        longBreakItem.state = mode == .longBreak ? .on : .off
        menu.addItem(longBreakItem)

        let focusDurationItem = NSMenuItem(title: "设置专注时长...", action: #selector(editFocusDuration), keyEquivalent: "")
        focusDurationItem.target = self
        menu.addItem(focusDurationItem)

        menu.addItem(.separator())

        addRecordsMenuItems()

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出番茄计时", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        updateStatusMenuItem()
    }

    private func startTimer() {
        isRunning = true
        hasActiveSession = true
        if sessionStartedAt == nil {
            sessionStartedAt = Date()
            sessionPlannedDurationSeconds = duration(for: mode)
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
        setMode(nextMode)
        startTimer()
    }

    private func completeCurrentMode() {
        if mode == .focus {
            focusSessions += 1
        }

        let completedMode = mode
        addPomodoroRecord(mode: completedMode)

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
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
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
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        statusMenuItem.title = "\(mode.menuTitle) · \(state) · \(String(format: "%02d:%02d", minutes, seconds))"
    }

    private func addRecordsMenuItems() {
        let today = recordDateFormatter.string(from: Date())
        let todayFocusCount = records.filter { $0.date == today && $0.type == "focus" }.count
        let todayTotalCount = records.filter { $0.date == today }.count
        let todayItem = NSMenuItem(title: "今日完成：\(todayFocusCount) 个番茄 · 共 \(todayTotalCount) 段", action: nil, keyEquivalent: "")
        todayItem.isEnabled = false
        menu.addItem(todayItem)

        let outsideItem = NSMenuItem(title: "番茄外时间：\(formattedOutsidePomodoroTimeToday())", action: nil, keyEquivalent: "")
        outsideItem.isEnabled = false
        menu.addItem(outsideItem)

        let todayRecords = records.filter { $0.date == today }
        if todayRecords.isEmpty {
            let emptyItem = NSMenuItem(title: "暂无记录", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            let reversedRecords = Array(todayRecords.reversed())
            let recentRecords = Array(reversedRecords.prefix(collapsedRecordsLimit))

            for record in recentRecords {
                addRecordMenuItem(record, to: menu)
            }

            let allRecordsItem = NSMenuItem(title: "全部记录（共 \(todayRecords.count) 条）", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for record in reversedRecords {
                addRecordMenuItem(record, to: submenu)
            }
            allRecordsItem.submenu = submenu
            menu.addItem(allRecordsItem)
        }

        let fileItem = NSMenuItem(title: "记录文件：~/.pomodoro-status-bar/records.json", action: nil, keyEquivalent: "")
        fileItem.isEnabled = false
        menu.addItem(fileItem)

        let clearItem = NSMenuItem(title: "清空记录", action: #selector(clearRecords), keyEquivalent: "")
        clearItem.target = self
        clearItem.isEnabled = !records.isEmpty
        menu.addItem(clearItem)
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
        let recordFont = NSFont(name: "Monaco", size: NSFont.systemFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: recordFont
        ]

        title.append(NSAttributedString(
            string: text,
            attributes: textAttributes
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
        guard let startedAt = recordDateTimeFormatter.date(from: record.startedAt),
              let endedAt = recordDateTimeFormatter.date(from: record.endedAt) else {
            return record.durationMinutes
        }
        return max(0, Int(endedAt.timeIntervalSince(startedAt) / 60))
    }

    private func addPomodoroRecord(mode completedMode: PomodoroMode) {
        let plannedDurationSeconds = sessionPlannedDurationSeconds ?? duration(for: completedMode)
        let startedAt = sessionStartedAt ?? Date().addingTimeInterval(-TimeInterval(plannedDurationSeconds))
        let endedAt = Date()
        let durationMinutes = plannedDurationSeconds / 60
        records.append(PomodoroRecord(
            startedAt: recordDateTimeFormatter.string(from: startedAt),
            endedAt: recordDateTimeFormatter.string(from: endedAt),
            date: recordDateFormatter.string(from: endedAt),
            type: completedMode.recordType,
            durationMinutes: durationMinutes,
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

    private func loadPreferences() {
        let storedFocusDuration = UserDefaults.standard.integer(forKey: focusDurationStorageKey)
        if storedFocusDuration > 0 {
            focusDurationMinutes = min(180, max(1, storedFocusDuration))
        }
    }

    private func savePreferences() {
        UserDefaults.standard.set(focusDurationMinutes, forKey: focusDurationStorageKey)
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
        return "\(seconds / 3600) 小时 \((seconds % 3600) / 60) 分钟"
    }

    private func outsidePomodoroSecondsToday() -> Int {
        let today = recordDateFormatter.string(from: Date())
        let now = Date()
        var firstStart: Date?
        var pomodoroSeconds = 0

        for record in records where record.date == today {
            guard let startedAt = recordDateTimeFormatter.date(from: record.startedAt) else {
                continue
            }

            if firstStart == nil || startedAt < firstStart! {
                firstStart = startedAt
            }

            if let endedAt = recordDateTimeFormatter.date(from: record.endedAt) {
                pomodoroSeconds += max(0, Int(endedAt.timeIntervalSince(startedAt)))
            } else {
                pomodoroSeconds += max(0, record.durationMinutes * 60)
            }
        }

        if let sessionStartedAt, recordDateFormatter.string(from: sessionStartedAt) == today {
            if firstStart == nil || sessionStartedAt < firstStart! {
                firstStart = sessionStartedAt
            }

            let currentSessionDuration = sessionPlannedDurationSeconds ?? duration(for: mode)
            let currentUsedSeconds = max(0, currentSessionDuration - remainingSeconds)
            pomodoroSeconds += currentUsedSeconds
        }

        guard let firstStart else {
            return 0
        }

        let elapsedSinceFirstStart = max(0, Int(now.timeIntervalSince(firstStart)))
        return max(0, elapsedSinceFirstStart - pomodoroSeconds)
    }

    private func backupRecordsBeforeClearing() -> URL? {
        guard FileManager.default.fileExists(atPath: recordsFileURL.path) else {
            return nil
        }

        do {
            try FileManager.default.createDirectory(
                at: recordsDirectoryURL,
                withIntermediateDirectories: true
            )
            let timestamp = backupDateFormatter.string(from: Date())
            let backupURL = recordsDirectoryURL.appendingPathComponent("records.backup-\(timestamp).json")
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try FileManager.default.removeItem(at: backupURL)
            }
            try FileManager.default.copyItem(at: recordsFileURL, to: backupURL)
            return backupURL
        } catch {
            NSLog("Could not backup pomodoro records: \(error.localizedDescription)")
            return nil
        }
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

    private var backupDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }

    @objc private func tick() {
        guard remainingSeconds > 0 else {
            completeCurrentMode()
            return
        }

        remainingSeconds -= 1
        updateStatusTitle()

        if remainingSeconds == 0 {
            completeCurrentMode()
        }
    }

    @objc private func toggleTimer() {
        isRunning ? pauseTimer() : startTimer()
    }

    @objc private func resetTimer() {
        remainingSeconds = duration(for: mode)
        stopTimer()
    }

    @objc private func skipToNextMode() {
        let nextMode = mode.next
        setMode(nextMode)
    }

    @objc private func editSessionNote() {
        let alert = NSAlert()
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

    @objc private func clearRecords() {
        let alert = NSAlert()
        alert.messageText = "清空番茄记录？"
        alert.informativeText = "清空前会自动备份当前 records.json。"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let backupURL = backupRecordsBeforeClearing()
            records = []
            saveRecords()
            if let backupURL {
                let backupAlert = NSAlert()
                backupAlert.messageText = "记录已清空"
                backupAlert.informativeText = "备份文件：\(backupURL.path)"
                backupAlert.addButton(withTitle: "好")
                backupAlert.runModal()
            }
            rebuildMenu()
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

    @objc private func editFocusDuration() {
        let alert = NSAlert()
        alert.messageText = "专注时长"
        alert.informativeText = "请输入 1 到 180 分钟。新的时长会用于下一段专注。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        input.stringValue = "\(focusDurationMinutes)"
        input.placeholderString = "25"
        alert.accessoryView = input

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let trimmed = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let minutes = Int(trimmed), (1...180).contains(minutes) else {
                showInvalidFocusDurationAlert()
                return
            }

            focusDurationMinutes = minutes
            savePreferences()
            if mode == .focus && !hasActiveSession {
                remainingSeconds = duration(for: .focus)
            }
            updateStatusTitle()
            rebuildMenu()
        }
    }

    private func showInvalidFocusDurationAlert() {
        let alert = NSAlert()
        alert.messageText = "专注时长无效"
        alert.informativeText = "请输入 1 到 180 之间的整数分钟。"
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
