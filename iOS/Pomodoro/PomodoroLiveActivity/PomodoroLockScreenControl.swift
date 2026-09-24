// iOS 18 起可添加到锁屏底部的快捷控制，与计时中的实时活动相互独立。
import AppIntents
import SwiftUI
import WidgetKit

/// 使用静态资源显示番茄标记；锁屏控制不支持把任意 SwiftUI 绘图当作图标。
@available(iOS 18.0, *)
struct PomodoroLockScreenControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "local.codex.PomodoroBar.open-app") {
            ControlWidgetButton(action: OpenPomodoroAppIntent()) {
                Label("打开 Pomodoro", image: "TomatoControlIcon")
            }
        }
        .displayName("打开 Pomodoro")
        .description("从锁屏打开番茄钟，不自动开始计时。")
    }
}
