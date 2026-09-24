// iOS 主应用入口。
//
// SwiftUI 负责创建界面层级；UIApplicationDelegate 仍用于接入通知等传统 UIKit 生命周期能力。
// 本文件只做“组装”：创建全局 Store、注入首页，并把系统生命周期事件转发给业务层。
import SwiftUI
import UIKit
import UserNotifications

/// UIKit 应用代理。
///
/// SwiftUI 的 `App` 协议没有直接提供前台通知展示回调，所以通过
/// `UIApplicationDelegateAdaptor` 把这个代理接回 UIKit 生命周期。
final class PomodoroAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// 应用启动完成后，把通知中心的代理设为自己。
    ///
    /// 如果不设置代理，App 正在前台时收到的本地通知通常不会显示横幅和声音。
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// 决定 App 位于前台时如何展示通知。
    /// `.banner` 和 `.sound` 让倒计时完成提醒在用户正使用 App 时也能被看到、听到。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

/// iOS 应用的 SwiftUI 入口。
///
/// `@main` 表示系统从这里启动 App。两个 `StateObject` 在应用场景存续期间只创建一次，
/// 因而页面刷新不会丢失计时状态或已选择的今日指引文件授权。
@main
struct PomodoroBarApp: App {
    /// 把上面的 UIKit 代理接入 SwiftUI 应用。
    @UIApplicationDelegateAdaptor(PomodoroAppDelegate.self) private var appDelegate
    /// 当前场景状态：前台活跃、暂时非活跃或进入后台。
    @Environment(\.scenePhase) private var scenePhase
    /// 番茄钟的唯一业务状态源。
    @StateObject private var store = PomodoroStore()
    /// 今日指引文件授权、读取、保存与历史数据的状态源。
    @StateObject private var guidanceStore = GuidanceStore()

    var body: some Scene {
        WindowGroup {
            // 首页只观察 Store，不自行保存业务数据。
            ContentView(store: store, guidanceStore: guidanceStore)
                .task {
                    // 首次显示页面时恢复本地计时、记录和实时活动。
                    await store.prepare()
                }
        }
        .onChange(of: scenePhase) { phase in
            // 计时不能只依赖界面上的一秒 Timer；从后台回来时要根据真实时间重新计算。
            store.scenePhaseChanged(phase)
            if phase == .active, guidanceStore.hasSelectedFile {
                // Mac 或其他设备可能已修改 iCloud 文件，回到前台时主动重新读取。
                guidanceStore.refresh()
            }
        }
    }
}
