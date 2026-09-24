// Live Activity 扩展使用的 ActivityKit 数据协议。
//
// 这是主 App 中同名类型的镜像。两个 target 分别编译，字段名称、类型和顺序必须保持一致；
// 新增状态时请同时修改 `Pomodoro/PomodoroActivityAttributes.swift`。
import ActivityKit
import Foundation

/// 描述一条番茄钟实时活动。
struct PomodoroActivityAttributes: ActivityAttributes {
    /// 可由主 App 或 App Intent 更新的动态显示状态。
    struct ContentState: Codable, Hashable {
        /// 显示在锁屏和灵动岛上的模式短标题。
        let modeTitle: String
        /// 区分自由正计时与有终点的倒计时。
        let isCountUp: Bool
        /// 决定显示动态系统计时器还是暂停后的固定文本。
        let isRunning: Bool
        /// 系统计时文本使用的起点。
        let timerStart: Date
        /// 倒计时终点；正计时为 `nil`。
        let timerEnd: Date?
        /// 暂停时显示的秒数；含义由 `isCountUp` 决定为已用或剩余时间。
        let pausedSeconds: Int
    }

    /// 所属计时时段的 UUID。
    let sessionID: UUID
}
