// Widget 扩展的入口文件。
//
// WidgetKit 要求扩展提供一个带 `@main` 的 `WidgetBundle`；同时注册实时活动和
// iOS 18+ 可自定义的锁屏快捷控制。
import SwiftUI
import WidgetKit

/// 将实时活动与 iOS 18+ 锁屏快捷控制注册给系统。
@main
struct PomodoroLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        PomodoroLiveActivity()
        if #available(iOS 18.0, *) {
            PomodoroLockScreenControl()
        }
    }
}
