import SwiftUI
import UIKit
import UserNotifications

final class PomodoroAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct PomodoroBarApp: App {
    @UIApplicationDelegateAdaptor(PomodoroAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = PomodoroStore()
    @StateObject private var guidanceStore = GuidanceStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store, guidanceStore: guidanceStore)
                .task {
                    await store.prepare()
                }
        }
        .onChange(of: scenePhase) { phase in
            store.scenePhaseChanged(phase)
        }
    }
}
