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
        errorMessage = nil
        var lookupQuestion = text
        var lookupDocuments = documents
        if LocalChatIntent.isFollowUp(text) {
            do {
                var fetch = FetchDescriptor<ChatMessage>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
                fetch.fetchLimit = 20
                let history = try context.fetch(fetch)
                if let previous = history.first(where: { $0.role == .assistant }), !previous.localSources.isEmpty,
                   let topic = history.first(where: { $0.role == .user && $0.createdAt <= previous.createdAt && !LocalChatIntent.isFollowUp($0.content) }) {
                    lookupQuestion = topic.content + " " + text
                    let ids = Set(previous.localSources.map(\.documentID))
                    lookupDocuments = documents.filter { ids.contains($0.id) }
                }
            } catch { errorMessage = "Previous conversation context could not be read. Ask using a test or medication name." }
        }
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
            let terms = await LocalChatQueryService().terms(for: lookupQuestion)
            guard !Task.isCancelled, generation == operation, revision == LocalRecordLifecycle.shared.revision else { return }
            // The sources and answer come from this store, not from generated medical claims.
            let answer = LocalRecordLookup.answer(question: lookupQuestion, documents: lookupDocuments, selectedDocumentID: scope, expandedTerms: terms)
            let assistant = ChatMessage(role: .assistant, content: answer.text, sourceDocumentIds: Array(Set(answer.sources.map(\.documentID))))
            assistant.localSources = answer.sources
            context.insert(assistant)
            do { try context.save() }
            catch { context.rollback(); errorMessage = "The answer could not be saved. Try again." }
        }
    }

    func cancel() {
        generation += 1
        responseTask?.cancel()
        responseTask = nil
        isResponding = false
    }

    func clear(context: ModelContext) {
        generation += 1
        responseTask?.cancel()
        responseTask = nil
        isResponding = false
        do { try context.delete(model: ChatMessage.self); try context.save() }
        catch { context.rollback(); errorMessage = "Chat history could not be cleared." }
    }
}
