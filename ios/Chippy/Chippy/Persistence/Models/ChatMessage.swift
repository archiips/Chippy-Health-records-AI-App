import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique) var id: String
    var role: MessageRole
    var content: String
    var sourceDocumentIds: [String]
    var createdAt: Date
    var isStreaming: Bool  // true while SSE is in progress

    init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        sourceDocumentIds: [String] = [],
        createdAt: Date = .now,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.sourceDocumentIds = sourceDocumentIds
        self.createdAt = createdAt
        self.isStreaming = isStreaming
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}
