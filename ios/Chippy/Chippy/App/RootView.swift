import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AppLockManager.self) private var lockManager
    @Environment(ProcessingPreferences.self) private var preferences

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            } else if !lockManager.isUnlocked {
                LockScreenView()
            } else if preferences.mode == .local {
                LocalAppView().modelContainer(AppModelContainer.local)
            } else if !authManager.isAuthenticated {
                AuthView()
            } else {
                CloudAppView(userID: authManager.currentUserId ?? "")
                    .id(authManager.currentUserId)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                lockManager.lock()
            } else if newPhase == .active && !lockManager.isUnlocked {
                Task { await lockManager.authenticate() }
            }
        }
        .task { await lockManager.authenticate() }
        .onChange(of: authManager.isAuthenticated) { _, authenticated in
            if !authenticated { preferences.useLocal() }
        }
    }
}

private struct CloudAppView: View {
    @State private var container: ModelContainer
    init(userID: String) { _container = State(initialValue: AppModelContainer.cloud(for: userID)) }
    var body: some View { MainTabView().modelContainer(container) }
}
