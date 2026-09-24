// iOS 18 起可添加到锁屏底部的快捷控制，与计时中的实时活动相互独立。
import AppIntents
import SwiftUI
import WidgetKit

/// 锁屏控制直接复用实时活动中的番茄标记，保持两处造型一致。
@available(iOS 18.0, *)
struct PomodoroLockScreenControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "local.codex.PomodoroBar.open-app") {
            ControlWidgetButton(action: OpenPomodoroAppIntent()) {
                Label {
                    Text("打开 Pomodoro")
                } icon: {
                    TomatoMark(size: 22)
                }
            }
        }
        .displayName("打开 Pomodoro")
        .description("从锁屏打开番茄钟，不自动开始计时。")
    }
}
