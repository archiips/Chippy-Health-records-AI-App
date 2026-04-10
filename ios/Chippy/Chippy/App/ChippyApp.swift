import SwiftUI
import SwiftData

@main
struct ChippyApp: App {
    @State private var authManager = AuthManager()
    @State private var lockManager = AppLockManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(AppModelContainer.shared)
                .environment(authManager)
                .environment(lockManager)
        }
    }
}
