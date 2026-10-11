import SwiftUI

@main
struct PhotoTimelineApp: App {
    @StateObject private var store = TripStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
