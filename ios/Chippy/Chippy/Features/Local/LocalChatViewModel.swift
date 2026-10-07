import SwiftUI
import SwiftData

@Observable
@MainActor
final class LocalChatViewModel {
    var input = ""
    var isResponding = false
    var errorMessage: String?
    var selectedDocumentID: String?
    private var generation = 0
    private var responseTask: Task<Void, Never>?

    func send(_ question: String? = nil, documents: [HealthDocument], context: ModelContext) {
        let text = (question ?? input).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding else { return }
        generation += 1
        let operation = generation
        input = ""
        isResponding = true
        let revision = LocalRecordLifecycle.shared.revision
        let scope = selectedDocumentID
        let user = ChatMessage(role: .user, content: text)
        context.insert(user)
        do { try context.save() }
        catch { context.rollback(); errorMessage = "Your message could not be saved."; isResponding = false; return }
        responseTask = Task {
            defer { if generation == operation { isResponding = false; responseTask = nil } }
            let terms = await LocalChatQueryService().terms(for: text)
            guard !Task.isCancelled, generation == operation, revision == LocalRecordLifecycle.shared.revision else { return }
            // The sources and answer come from this store, not from generated medical claims.
            let answer = LocalRecordLookup.answer(question: text, documents: documents, selectedDocumentID: scope, expandedTerms: terms)
            let assistant = ChatMessage(role: .assistant, content: answer.text, sourceDocumentIds: Array(Set(answer.sources.map(\.documentID))))
            assistant.localSources = answer.sources
            context.insert(assistant)
            do { try context.save() }
            catch { context.rollback(); errorMessage = "The answer could not be saved. Try again." }
        }
    }

    func cancel() { responseTask?.cancel() }

    func clear(context: ModelContext) {
        generation += 1
        responseTask?.cancel()
        responseTask = nil
        isResponding = false
        do { try context.delete(model: ChatMessage.self); try context.save() }
        catch { context.rollback(); errorMessage = "Chat history could not be cleared." }
    }
}
