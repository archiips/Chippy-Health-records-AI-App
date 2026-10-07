import SwiftUI

@Observable
@MainActor
final class ProcessingPreferences {
    enum Mode { case local, cloud }
    private(set) var mode: Mode = .local
    private(set) var cloudConsentGranted = false
    private(set) var revision = 0

    func enterCloud() {
        revision += 1
        cloudConsentGranted = true
        mode = .cloud
    }

    func useLocal() {
        revision += 1
        mode = .local
        cloudConsentGranted = false
    }
}
