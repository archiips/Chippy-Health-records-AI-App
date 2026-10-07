import Foundation

@MainActor
final class LocalRecordLifecycle {
    static let shared = LocalRecordLifecycle()
    private(set) var revision = 0
    func invalidatePendingWork() { revision += 1 }
}

struct CloudOperationScope {
    let userID: String
    let permissionRevision: Int

    @MainActor
    init(auth: AuthManager, preferences: ProcessingPreferences) throws {
        try self.init(userID: auth.currentUserId, preferences: preferences)
    }

    @MainActor
    init(userID: String?, preferences: ProcessingPreferences) throws {
        guard preferences.mode == .cloud, preferences.cloudConsentGranted else { throw ImportError.consentRequired }
        guard let userID else { throw ImportError.notAuthenticated }
        self.userID = userID
        self.permissionRevision = preferences.revision
    }

    @MainActor
    func isValid(userID currentUserID: String?, preferences: ProcessingPreferences) -> Bool {
        currentUserID == userID && preferences.mode == .cloud && preferences.cloudConsentGranted && preferences.revision == permissionRevision
    }

    @MainActor
    func token(auth: AuthManager, preferences: ProcessingPreferences) async throws -> String {
        guard isValid(userID: auth.currentUserId, preferences: preferences) else { throw CancellationError() }
        guard let token = await auth.validToken() else { throw ImportError.notAuthenticated }
        guard isValid(userID: auth.currentUserId, preferences: preferences) else { throw CancellationError() }
        return token
    }
}
