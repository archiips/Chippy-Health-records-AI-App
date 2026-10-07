import Foundation
import SwiftData
import Testing
@testable import Chippy

@MainActor
struct LocalChatBehaviorTests {
    private func lab() -> HealthDocument {
        let document = HealthDocument(id: "lab", filename: "September labs", fileURL: URL(filePath: "/tmp/lab"))
        let fact = RecordFact(documentID: "lab", pageNumber: 1, kind: "lab", name: "Glucose", value: "105", unit: "mg/dL", referenceRange: "70-100", quote: "Glucose 105 mg/dL range 70-100", dateText: "2026-09-18")
        fact.isConfirmed = true
        document.recordFacts = [fact]
        document.pages = [DocumentPage(number: 1, text: "Glucose 105 mg/dL range 70-100")]
        return document
    }

    @Test func ordinaryTestResultWordingFindsReviewedLabs() {
        let answer = LocalRecordLookup.answer(question: "Show me my test results", documents: [lab()])
        #expect(answer.text.contains("Glucose: 105"))
        #expect(answer.sources.first?.reviewed == true)
    }

    @Test func explainRecordsReturnsReviewedSummaryInsteadOfMissingMatch() {
        let answer = LocalRecordLookup.answer(question: "Can you explain my records?", documents: [lab()])
        #expect(answer.text.contains("105"))
        #expect(answer.sources.first?.documentID == "lab")
    }

    @Test func greetingWithoutRecordsProvidesHelpInsteadOfSearchFailure() {
        let answer = LocalRecordLookup.answer(question: "Hi", documents: [])
        #expect(answer.text.contains("Hi"))
        #expect(answer.text.contains("photo"))
        #expect(answer.sources.isEmpty)
    }

    @Test func normalityQuestionShowsRecordedContextWithoutJudgingHealth() {
        let answer = LocalRecordLookup.answer(question: "Are my labs normal?", documents: [lab()])
        #expect(answer.text.contains("105"))
        #expect(answer.text.contains("70-100"))
        #expect(answer.text.contains("cannot determine"))
    }

    @Test func duplicateOCRPagesDoNotProduceRepeatedWallOfText() {
        let a = lab(); a.recordFacts = []
        let b = HealthDocument(id: "copy", filename: "Copy", fileURL: URL(filePath: "/tmp/copy"))
        b.pages = a.pages
        let answer = LocalRecordLookup.answer(question: "Find glucose", documents: [a, b])
        #expect(answer.sources.count == 1)
        #expect(answer.text.count < 800)
        #expect(answer.text.contains("105"))
    }

    @Test func followUpReusesPreviousTopicFromPersistedConversation() async throws {
        let schema = Schema([HealthDocument.self, RecordFact.self, ChatMessage.self, HealthEvent.self, AnalysisResult.self])
        let store = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let document = lab()
        store.mainContext.insert(document)
        store.mainContext.insert(ChatMessage(role: .user, content: "Find glucose", createdAt: .distantPast))
        let previous = ChatMessage(role: .assistant, content: "Glucose: 105", createdAt: .distantPast.addingTimeInterval(1))
        previous.localSources = [LocalRecordSource(documentID: "lab", pageNumber: 1, excerpt: "Glucose 105", reviewed: true)]
        store.mainContext.insert(previous)
        try store.mainContext.save()
        let model = LocalChatViewModel()
        model.send("What about that result?", documents: [document], context: store.mainContext)
        for _ in 0..<100 where model.isResponding { await Task.yield() }
        let saved = try store.mainContext.fetch(FetchDescriptor<ChatMessage>(sortBy: [SortDescriptor(\.createdAt)]))
        #expect(saved.last?.content.contains("105") == true)
        #expect(saved.last?.localSources.first?.documentID == "lab")
    }

    @Test func stopImmediatelyRestoresComposer() throws {
        let schema = Schema([HealthDocument.self, RecordFact.self, ChatMessage.self, HealthEvent.self, AnalysisResult.self])
        let store = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let model = LocalChatViewModel()
        model.send("Find glucose", documents: [lab()], context: store.mainContext)
        model.cancel()
        #expect(!model.isResponding)
    }
}
