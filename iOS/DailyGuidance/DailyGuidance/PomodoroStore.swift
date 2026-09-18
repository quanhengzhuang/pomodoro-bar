import ActivityKit
import Combine
import Foundation
import SwiftUI
import UserNotifications

enum PomodoroMode: String, Codable, CaseIterable, Identifiable {
    case countUp = "count_up"
    case focus = "focus"
    case shortBreak = "short_break"
    case longBreak = "long_break"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .countUp: return "自由计时"
        case .focus: return "专注"
        case .shortBreak: return "短休息"
        case .longBreak: return "长休息"
        }
    }

    var compactTitle: String {
        switch self {
        case .countUp: return "计时"
        case .focus: return "专注"
        case .shortBreak, .longBreak: return "休息"
        }
    }

    var durationSeconds: Int? {
        switch self {
        case .countUp: return nil
        case .focus: return 25 * 60
        case .shortBreak: return 5 * 60
        case .longBreak: return 15 * 60
        }
    }

    var next: PomodoroMode {
        switch self {
        case .focus: return .shortBreak
        case .shortBreak, .longBreak, .countUp: return .focus
        }
    }

    var symbolName: String {
        switch self {
        case .countUp: return "stopwatch.fill"
        case .focus: return "scope"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }
}

struct PomodoroRecord: Codable, Hashable, Identifiable {
    let startedAt: String
    let endedAt: String
    let date: String
    let type: String
    let durationSeconds: Int
    let durationMinutes: Int
    let note: String

    var id: String { "\(startedAt)|\(endedAt)|\(type)|\(note)" }

    init(startedAt: Date, endedAt: Date, type: String, durationSeconds: Int, note: String) {
        self.startedAt = Self.dateTimeFormatter.string(from: startedAt)
        self.endedAt = Self.dateTimeFormatter.string(from: endedAt)
        date = Self.dateFormatter.string(from: endedAt)
        self.type = type
        self.durationSeconds = durationSeconds
        durationMinutes = durationSeconds / 60
        self.note = note
    }

    var mode: PomodoroMode {
        PomodoroMode(rawValue: type) ?? .countUp
    }

    var timeRange: String {
        "\(startedAt.suffix(8).prefix(5))–\(endedAt.suffix(8).prefix(5))"
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

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

@MainActor
final class PomodoroStore: ObservableObject {
    @Published private(set) var selectedMode: PomodoroMode = .focus
    @Published private(set) var isRunning = false
    @Published private(set) var hasActiveSession = false
    @Published private(set) var displaySeconds = 25 * 60
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var progress = 0.0
    @Published private(set) var records: [PomodoroRecord] = []
    @Published private(set) var liveActivityEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    @Published var note = ""
    @Published var errorMessage: String?

    private var sessionID = UUID()
    private var startedAt: Date?
    private var plannedDurationSeconds: Int?
    private var accumulatedSeconds = 0
    private var lastResumedAt: Date?
    private var ticker: Timer?
    private var sharedSessionObserver: AnyCancellable?
    private var activity: Activity<PomodoroActivityAttributes>?
    private let minimumRecordedSessionSeconds = 3 * 60
    private let sessionStorageKey = "ios.pomodoro.active-session"

    private var completionNotificationID: String {
        "pomodoro-complete-\(sessionID.uuidString)"
    }

    private var recordsURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PomodoroBar", isDirectory: true)
            .appendingPathComponent("records.json")
    }

    var modeOptions: [PomodoroMode] { PomodoroMode.allCases }

    var primaryActionTitle: String {
        guard hasActiveSession else { return "开始" }
        return isRunning ? "暂停" : "继续"
    }

    var todayFocusSeconds: Int {
        records
            .filter { $0.date == PomodoroRecord.dateFormatter.string(from: Date()) && $0.type == PomodoroMode.focus.rawValue }
            .reduce(0) { $0 + $1.durationSeconds }
    }

    var todaySessionCount: Int {
        records.filter { $0.date == PomodoroRecord.dateFormatter.string(from: Date()) }.count
    }

    var recentRecords: [PomodoroRecord] {
        Array(records.reversed().prefix(5))
    }

    init() {
        sharedSessionObserver = NotificationCenter.default
            .publisher(for: .pomodoroSharedSessionDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.reconcileSharedSession()
                }
            }
    }

    func prepare() async {
        loadRecords()
        restoreSession()
        reconcileSharedSession()
        activity = Activity<PomodoroActivityAttributes>.activities.first {
            $0.attributes.sessionID == sessionID
        }
        if hasActiveSession {
            refresh(at: Date())
            if isRunning { startTicker() }
            await syncLiveActivity()
        }
    }

    func selectMode(_ mode: PomodoroMode) {
        guard !hasActiveSession else { return }
        selectedMode = mode
        displaySeconds = mode.durationSeconds ?? 0
        elapsedSeconds = 0
        progress = 0
    }

    func performPrimaryAction() {
        if !hasActiveSession {
            startNewSession()
        } else if isRunning {
            pause()
        } else {
            resume()
        }
    }

    func endSession(recordIfEligible: Bool = true) {
        guard hasActiveSession else { return }
        refresh(at: Date())
        if recordIfEligible && elapsedSeconds >= minimumRecordedSessionSeconds {
            appendRecord(durationSeconds: elapsedSeconds)
        }
        let finalState = activityState()
        cancelCompletionNotification()
        resetSession()
        Task { await endLiveActivity(finalState: finalState) }
    }

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

    func updateNote(_ value: String) {
        note = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasActiveSession {
            persistSession()
            Task { await syncLiveActivity() }
        }
    }

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

    private func resume() {
        lastResumedAt = Date()
        isRunning = true
        startTicker()
        persistSession()
        Task { await authorizeAndScheduleCompletionNotification() }
        Task { await syncLiveActivity() }
    }

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        refresh(at: Date())
        if selectedMode != .countUp, displaySeconds <= 0 {
            completeCountdown()
        }
    }

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
            displaySeconds = seconds
            progress = Double(seconds % (25 * 60)) / Double(25 * 60)
        }
    }

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

    private func nextMode(after mode: PomodoroMode) -> PomodoroMode {
        guard mode == .focus else { return mode.next }
        let completedFocusSessions = records.filter { $0.type == PomodoroMode.focus.rawValue }.count
        return completedFocusSessions.isMultiple(of: 4) ? .longBreak : .shortBreak
    }

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

    private func loadRecords() {
        guard let data = try? Data(contentsOf: recordsURL) else { return }
        do {
            records = try JSONDecoder().decode([PomodoroRecord].self, from: data)
        } catch {
            errorMessage = "记录文件无法读取；原文件未被修改。"
        }
    }

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

    private func activityState(at date: Date = Date()) -> PomodoroActivityAttributes.ContentState {
        let timerStart: Date
        let timerEnd: Date?
        let pausedValue: Int
        if isRunning, let resumedAt = lastResumedAt {
            timerStart = resumedAt.addingTimeInterval(-TimeInterval(accumulatedSeconds))
            timerEnd = plannedDurationSeconds.map { timerStart.addingTimeInterval(TimeInterval($0)) }
            pausedValue = elapsedSeconds
        } else {
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

    private func endLiveActivity(finalState: PomodoroActivityAttributes.ContentState) async {
        let current = activity ?? Activity<PomodoroActivityAttributes>.activities.first
        await current?.end(using: finalState, dismissalPolicy: .immediate)
        activity = nil
    }

    private func authorizeAndScheduleCompletionNotification() async {
        cancelCompletionNotification()
        guard isRunning, selectedMode != .countUp, displaySeconds > 0 else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
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

    private func cancelCompletionNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [completionNotificationID])
    }
}
