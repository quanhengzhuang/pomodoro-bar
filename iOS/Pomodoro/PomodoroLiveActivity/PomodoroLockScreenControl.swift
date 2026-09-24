// iOS 18 起可添加到锁屏底部的快捷控制，与计时中的实时活动相互独立。
import AppIntents
import SwiftUI
import WidgetKit

/// 只打开 App，不擅自开始或改变当前计时。
@available(iOS 18.0, *)
struct OpenPomodoroAppIntent: AppIntent {
    static var title: LocalizedStringResource = "打开 Pomodoro"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// 小尺寸锁屏控制只显示图标；采用系统符号以适配锁屏的明暗和着色。
@available(iOS 18.0, *)
struct PomodoroLockScreenControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "local.codex.PomodoroBar.open-app") {
            ControlWidgetButton(action: OpenPomodoroAppIntent()) {
                Label("打开 Pomodoro", systemImage: "timer")
            }
        }
        .displayName("打开 Pomodoro")
        .description("从锁屏打开番茄钟，不自动开始计时。")
    }
}
