// 主 App 与快捷控制扩展共同注册的打开动作；只打开 App，不改变计时状态。
import AppIntents

@available(iOS 18.0, *)
struct OpenPomodoroAppIntent: AppIntent {
    static var title: LocalizedStringResource = "打开 Pomodoro"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
