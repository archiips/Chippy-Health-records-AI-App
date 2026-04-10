import LocalAuthentication
import SwiftUI

@Observable
@MainActor
final class AppLockManager {
    var isUnlocked: Bool = false
    var biometryType: LABiometryType = .none

    private var isBiometricEnabled: Bool {
        UserDefaults.standard.object(forKey: "faceIDEnabled") as? Bool ?? true
    }

    init() {
        let ctx = LAContext()
        var error: NSError?
        ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometryType = ctx.biometryType
    }

    func authenticate() async {
        guard isBiometricEnabled else {
            isUnlocked = true
            return
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // No biometrics available — unlock directly
            isUnlocked = true
            return
        }

        let reason = "Unlock Chippy to access your health records"
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            isUnlocked = success
        } catch {
            // Biometrics failed or cancelled — unlock anyway (personal project)
            isUnlocked = true
        }
    }

    func lock() {
        guard isBiometricEnabled else { return }
        isUnlocked = false
    }
}
