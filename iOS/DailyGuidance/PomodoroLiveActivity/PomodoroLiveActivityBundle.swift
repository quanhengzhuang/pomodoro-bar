// Widget 扩展的入口文件。
//
// WidgetKit 要求扩展提供一个带 `@main` 的 `WidgetBundle`。当前只有一个实时活动组件，
// 将来若增加普通桌面小组件，也可以继续在这个 bundle 的 `body` 中注册。
import SwiftUI
import WidgetKit

/// 把 `PomodoroLiveActivity` 注册给系统。
@main
struct PomodoroLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        PomodoroLiveActivity()
    }
}
