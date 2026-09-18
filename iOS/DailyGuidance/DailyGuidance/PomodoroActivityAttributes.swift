// 主 App 使用的 ActivityKit 数据协议。
//
// Live Activity 扩展是另一个编译 target，无法直接引用主 App 内部类型，因此扩展目录中保留
// 一份结构完全相同的声明。修改字段时必须同步修改两份，否则主 App 与扩展无法正确交换状态。
import ActivityKit
import Foundation

/// 一条实时活动中“不会随计时变化”的属性，以及可更新的 `ContentState`。
struct PomodoroActivityAttributes: ActivityAttributes {
    /// 锁屏和灵动岛每次刷新时使用的动态状态。
    ///
    /// 这里传递时间锚点，而不是每秒传递一段格式化字符串。系统可用这些日期自行绘制连续计时，
    /// 即使主 App 被挂起，锁屏倒计时也仍能继续变化。
    struct ContentState: Codable, Hashable {
        /// “专注”“休息”或“计时”等短标题。
        let modeTitle: String
        /// `true` 表示正计时；`false` 表示倒计时。
        let isCountUp: Bool
        /// 当前是否运行。暂停时界面改为显示固定的 `pausedSeconds`。
        let isRunning: Bool
        /// 正计时起点；倒计时中也作为推算结束时间的时间锚点。
        let timerStart: Date
        /// 倒计时预计结束时间；自由计时没有结束时间，因此为 `nil`。
        let timerEnd: Date?
        /// 暂停状态下需要显示的固定秒数。
        let pausedSeconds: Int
    }

    /// 一段计时的稳定标识，用来避免把旧实时活动的按钮操作应用到新时段。
    let sessionID: UUID
}
