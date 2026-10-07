import Foundation
import SwiftData

@MainActor
enum DocumentDeletionService {
    static func deleteCloud(_ document: HealthDocument, context: ModelContext,
                            auth: AuthManager, preferences: ProcessingPreferences) async throws {
        let scope = try CloudOperationScope(auth: auth, preferences: preferences)
        let token = try await scope.token(auth: auth, preferences: preferences)
        let userID = scope.userID
        guard let remoteID = document.remoteId else { throw ImportError.notAuthenticated }
        do { try await DocumentService.shared.deleteDocument(id: remoteID, token: token) }
        catch APIError.httpError(let status, _) where status == 404 {
            // A previous cleanup may have removed the server record before local cleanup failed.
        }
        try CloudDocumentFiles.store(userID: userID).remove(document.resolvedFileURL)
        try DocumentRepository(context: context).delete(document)
    }
}
