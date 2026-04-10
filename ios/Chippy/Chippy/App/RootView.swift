import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AppLockManager.self) private var lockManager

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                if hasCompletedOnboarding {
                    AuthView()
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
            } else if !lockManager.isUnlocked {
                LockScreenView()
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                lockManager.lock()
            } else if newPhase == .active && authManager.isAuthenticated && !lockManager.isUnlocked {
                Task { await lockManager.authenticate() }
            }
        }
    }
}
