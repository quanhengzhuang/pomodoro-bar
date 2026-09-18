import Foundation

extension Notification.Name {
    static let pomodoroSharedSessionDidChange = Notification.Name(
        "local.codex.PomodoroBar.shared-session-did-change"
    )
}

struct PomodoroSharedSession: Codable, Equatable {
    enum Status: String, Codable {
        case active
        case ended
    }

    let id: UUID
    let modeRawValue: String
    let modeTitle: String
    let isCountUp: Bool
    let startedAt: Date
    var isRunning: Bool
    var plannedDurationSeconds: Int?
    var accumulatedSeconds: Int
    var lastResumedAt: Date?
    var note: String
    var status: Status
    var endedAt: Date?
    var updatedAt: Date

    func elapsedSeconds(at date: Date) -> Int {
        var seconds = accumulatedSeconds
        if isRunning, let lastResumedAt {
            seconds += max(0, Int(date.timeIntervalSince(lastResumedAt)))
        }
        return max(0, seconds)
    }

    func displaySeconds(at date: Date) -> Int {
        let elapsed = elapsedSeconds(at: date)
        return plannedDurationSeconds.map { max(0, $0 - elapsed) } ?? elapsed
    }

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

    mutating func addFiveMinutes(at date: Date) -> Bool {
        guard status == .active, !isCountUp, let plannedDurationSeconds else { return false }
        self.plannedDurationSeconds = plannedDurationSeconds + 5 * 60
        updatedAt = date
        return true
    }

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

enum PomodoroSharedStorage {
    static let appGroupIdentifier = "group.local.codex.PomodoroBar"
    static let sessionKey = "pomodoro.shared-session.v1"

    static func load() -> PomodoroSharedSession? {
        guard let data = defaults?.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(PomodoroSharedSession.self, from: data)
    }

    @discardableResult
    static func save(_ session: PomodoroSharedSession) -> Bool {
        guard let defaults, let data = try? JSONEncoder().encode(session) else { return false }
        defaults.set(data, forKey: sessionKey)
        return true
    }

    static func clear(sessionID: UUID? = nil) {
        guard let defaults else { return }
        if let sessionID, load()?.id != sessionID { return }
        defaults.removeObject(forKey: sessionKey)
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
}
