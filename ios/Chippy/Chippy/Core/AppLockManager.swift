import LocalAuthentication
import SwiftUI

@Observable
@MainActor
final class AppLockManager {
    var isUnlocked: Bool = false
    var biometryType: LABiometryType = .none
    private var isAuthenticating = false

    private var isBiometricEnabled: Bool {
        UserDefaults.standard.object(forKey: "faceIDEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "faceIDEnabled")
    }

    init() {
        let ctx = LAContext()
        var error: NSError?
        ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometryType = ctx.biometryType
    }

    func authenticate() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        guard isBiometricEnabled else {
            isUnlocked = true
            return
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isUnlocked = false
            return
        }

        let reason = "Unlock Chippy to access your health records"
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            isUnlocked = success
        } catch {
            isUnlocked = false
        }
    }

    func lock() {
        guard isBiometricEnabled else { return }
        isUnlocked = false
    }
}
