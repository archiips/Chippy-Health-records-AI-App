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

    func sendMessage(authManager: AuthManager, context: ModelContext, documentIds: [String]? = nil) async {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isStreaming else { return }
        inputText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Append user message locally
        let userMsg = ChatMessage(role: .user, content: query, sourceDocumentIds: documentIds ?? [])
        context.insert(userMsg)
        messages.append(userMsg)

        // Get a valid (non-expired) token, refreshing if needed
        guard let token = await authManager.validToken() else {
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

            var request = URLRequest(url: Constants.baseURL.appendingPathComponent("/chat/stream"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "query": query,
                "document_ids": documentIds as Any
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            for await chunk in await StreamingService.shared.stream(request: request) {
                guard !Task.isCancelled else { break }
                // Detect server-side error payload (e.g. {"error": "503 ..."})
                if chunk.hasPrefix("{\"error\":") {
                    errorMessage = "Service temporarily unavailable. Please try again."
                    streamingText = ""
                    return
                }
                streamingText += chunk
            }

            guard !Task.isCancelled, !streamingText.isEmpty else { return }
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

    func clearHistory(authManager: AuthManager, context: ModelContext) async {
        guard let token = authManager.accessToken else { return }
        // Clear locally
        for msg in messages { context.delete(msg) }
        messages = []
        try? context.save()
        // Clear on server (best-effort)
        var request = URLRequest(url: Constants.baseURL.appendingPathComponent("/chat/history"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: request)
    }
}
