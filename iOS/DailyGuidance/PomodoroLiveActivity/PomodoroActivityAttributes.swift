import ActivityKit
import Foundation

struct PomodoroActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let modeTitle: String
        let isCountUp: Bool
        let isRunning: Bool
        let timerStart: Date
        let timerEnd: Date?
        let pausedSeconds: Int
    }

    let sessionID: UUID
}
