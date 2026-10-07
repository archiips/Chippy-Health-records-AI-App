import SwiftUI
import SwiftData

@main
struct ChippyApp: App {
    @State private var authManager = AuthManager()
    @State private var lockManager = AppLockManager()
    @State private var preferences = ProcessingPreferences()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(lockManager)
                .environment(preferences)
        }
    }
}
