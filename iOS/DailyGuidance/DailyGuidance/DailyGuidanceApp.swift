import SwiftUI

@main
struct DailyGuidanceApp: App {
    @StateObject private var store = GuidanceStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
