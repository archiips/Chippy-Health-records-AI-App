import Foundation
import SwiftData
import UIKit

@Observable
@MainActor
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var streamingText: String = ""
    var isStreaming: Bool = false
    var errorMessage: String?

    private var streamTask: Task<Void, Never>?

    // MARK: - Load history

    func loadHistory(context: ModelContext) {
        let descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        messages = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Send message

    func sendMessage(authManager: AuthManager, context: ModelContext, preferences: ProcessingPreferences, documentIds: [String]? = nil) async {
        guard let scope = try? CloudOperationScope(auth: authManager, preferences: preferences) else { errorMessage = "Cloud processing permission is required."; return }
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isStreaming else { return }
        inputText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Append user message locally
        let userMsg = ChatMessage(role: .user, content: query, sourceDocumentIds: documentIds ?? [])
        context.insert(userMsg)
        messages.append(userMsg)

        // Get a valid (non-expired) token, refreshing if needed
        guard let token = try? await scope.token(auth: authManager, preferences: preferences) else {
            errorMessage = "Please sign in again."
            return
        }

        isStreaming = true
        streamingText = ""
        errorMessage = nil

        streamTask = Task {
            defer {
                isStreaming = false
            }

            guard scope.isValid(userID: authManager.currentUserId, preferences: preferences) else { return }
            var request = URLRequest(url: Constants.baseURL.appendingPathComponent("/chat/stream"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            var body: [String: Any] = ["query": query]
            if let documentIds { body["document_ids"] = documentIds }
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            for await chunk in await StreamingService.shared.stream(request: request) {
                guard !Task.isCancelled, scope.isValid(userID: authManager.currentUserId, preferences: preferences) else { break }
                // Detect server-side error payload (e.g. {"error": "503 ..."})
                if chunk.hasPrefix("{\"error\":") {
                    errorMessage = "Service temporarily unavailable. Please try again."
                    streamingText = ""
                    return
                }
                streamingText += chunk
            }

            guard !Task.isCancelled, !streamingText.isEmpty, scope.isValid(userID: authManager.currentUserId, preferences: preferences) else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Persist completed assistant message
            let assistantMsg = ChatMessage(
                role: .assistant,
                content: streamingText,
                sourceDocumentIds: documentIds ?? []
            )
            context.insert(assistantMsg)
            messages.append(assistantMsg)
            streamingText = ""
            try? context.save()
        }

        await streamTask?.value
    }

    func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
        if !streamingText.isEmpty {
            streamingText = ""
        }
        isStreaming = false
    }

    func clearHistory(authManager: AuthManager, context: ModelContext, preferences: ProcessingPreferences) async {
        guard let scope = try? CloudOperationScope(auth: authManager, preferences: preferences),
              let token = try? await scope.token(auth: authManager, preferences: preferences) else { return }
        do {
            try await APIClient.shared.requestEmpty("/chat/history", method: "DELETE", token: token)
            guard scope.isValid(userID: authManager.currentUserId, preferences: preferences) else { return }
            for message in messages { context.delete(message) }
            try context.save()
            messages = []
        } catch { context.rollback(); errorMessage = "Could not delete chat history. Please retry." }
    }
}
