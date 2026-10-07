import Testing
import Foundation
import UIKit
import SwiftData
@testable import Chippy

@MainActor
struct RecordExperienceTests {
    private func fact(document: String, name: String = "Glucose", value: String = "105", date: String? = "2026-09-18", kind: String = "lab", confirmed: Bool = true) -> RecordFact {
        let result = RecordFact(documentID: document, pageNumber: 1, kind: kind, name: name, value: value,
            unit: "mg/dL", referenceRange: "70-100", quote: "\(name) \(value) mg/dL range 70-100", dateText: date)
        result.isConfirmed = confirmed
        return result
    }

    @Test func photographedLabOCRPreservesValuesAndPageOrder() async throws {
        let url = try #require(Bundle(for: LocalModelEvaluationTests.self).url(forResource: "photographed-lab", withExtension: "png"))
        let data = try Data(contentsOf: url)
        let processor = DocumentTextProcessor()
        let pages = try await processor.imagePages([data, data])
        #expect(pages.map(\.number) == [1, 2])
        for page in pages {
            #expect(page.text.contains("SYNTHETIC"))
            #expect(page.text.localizedCaseInsensitiveContains("Glucose"))
            #expect(page.text.contains("105"))
            #expect(page.text.contains("13.8"))
            #expect(page.text.contains("0.9"))
            #expect(page.text.contains("70-100"))
        }
    }

    @Test func photographedMedicationRecordPreservesDoses() async throws {
        let url = try #require(Bundle(for: LocalModelEvaluationTests.self).url(forResource: "photographed-medications", withExtension: "png"))
        let pages = try await DocumentTextProcessor().imagePages([Data(contentsOf: url)])
        let text = try #require(pages.first?.text)
        #expect(text.contains("SYNTHETIC"))
        #expect(text.contains("Loratadine"))
        #expect(text.contains("10 mg"))
        #expect(text.contains("1000 IU"))
        #expect(text.contains("2026-08-12"))
    }

    @Test func unambiguousRecordDatesNormalizeWithoutGuessingNumericLocale() {
        #expect(fact(document: "a", date: "September 18, 2026").eventDate == fact(document: "a").eventDate)
        #expect(fact(document: "a", date: "18 Sep 2026").eventDate == fact(document: "a").eventDate)
        #expect(fact(document: "a", date: "09/08/2026").eventDate == nil)
        #expect(fact(document: "a", date: "February 30, 2026").eventDate == nil)
    }

    @Test func authenticProviderSampleImageIsRecognized() async throws {
        let url = try #require(Bundle(for: LocalModelEvaluationTests.self).url(forResource: "provider-sample-lab", withExtension: "jpg"))
        let pages = try await DocumentTextProcessor().imagePages([Data(contentsOf: url)])
        let text = try #require(pages.first?.text)
        #expect(text.localizedCaseInsensitiveContains("HAEMOGLOBIN"))
        #expect(text.contains("147"))
        #expect(text.contains("g/L"))
        #expect(text.localizedCaseInsensitiveContains("CREATININE"))
        #expect(text.contains("97"))
        #expect(text.contains("59 - 104")) // Creatinine reference range; diagonal watermark is not medical content.
    }

    @Test func namedLatestLabFiltersTheTestBeforeSelectingADate() {
        let document = HealthDocument(id: "a", filename: "Lab photo", fileURL: URL(filePath: "/tmp/a"))
        document.recordFacts = [fact(document: "a", date: "2025-01-02"), fact(document: "a", name: "Creatinine", value: "0.9", date: "2026-09-18")]
        let answer = LocalRecordLookup.answer(question: "What is my latest glucose lab result?", documents: [document])
        #expect(answer.text.contains("Glucose: 105"))
        #expect(!answer.text.contains("Creatinine"))
        #expect(answer.text.contains("2025-01-02"))
    }

    @Test func namedMedicationDoesNotReturnOtherMedicationMentions() {
        let document = HealthDocument(id: "a", filename: "Medication photo", fileURL: URL(filePath: "/tmp/a"))
        document.recordFacts = [fact(document: "a", name: "Loratadine", value: "10", kind: "medication"), fact(document: "a", name: "Amoxicillin", value: "500", kind: "medication")]
        let answer = LocalRecordLookup.answer(question: "What is recorded about Loratadine medication?", documents: [document])
        #expect(answer.text.contains("Loratadine"))
        #expect(!answer.text.contains("Amoxicillin"))
    }

    @Test func clearingChatDoesNotInvalidatePendingRecordImports() throws {
        let schema = Schema([HealthDocument.self, RecordFact.self, ChatMessage.self, HealthEvent.self, AnalysisResult.self])
        let store = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let revision = LocalRecordLifecycle.shared.revision
        LocalChatViewModel().clear(context: store.mainContext)
        #expect(LocalRecordLifecycle.shared.revision == revision)
    }

    @Test func equivalentDatesShareAnEventAndUnknownUnitsAreNotCompared() {
        let a = fact(document: "a")
        let b = fact(document: "a", name: "Creatinine", date: "September 18, 2026")
        #expect(RecordTimeline.events(from: [a, b]).count == 1)
        b.unit = nil
        #expect(RecordLabSeries.groups([a, b]).values.flatMap { $0 }.count == 1)
    }

    @Test func timelineGroupsRelatedFactsButNeverUsesImportDate() {
        let facts = [fact(document: "a"), fact(document: "a", name: "Creatinine"), fact(document: "b"),
                     fact(document: "a", date: nil), fact(document: "a", confirmed: false)]
        let events = RecordTimeline.events(from: facts)
        #expect(events.count == 3)
        #expect(events[0].facts.count == 2)
        #expect(events.last?.date == nil)
        #expect(events.flatMap(\.facts).count == 4)
        #expect(RecordTimeline.events(from: facts, kind: "medication").isEmpty)
        #expect(RecordTimeline.events(from: facts, after: .now).isEmpty)
    }

    @Test func chatAnswersMedicationMentionsWithSourcesAndNeverClaimsCurrentUse() {
        let document = HealthDocument(id: "a", filename: "Prescription photo", fileURL: URL(filePath: "/tmp/a"))
        let mention = fact(document: "a", name: "Loratadine", value: "10", kind: "medication")
        document.recordFacts = [mention]
        let answer = LocalRecordLookup.answer(question: "What medications are mentioned in my records?", documents: [document])
        #expect(answer.sources.count == 1)
        #expect(answer.sources[0].documentID == "a" && answer.sources[0].pageNumber == 1)
        #expect(answer.text.contains("Loratadine"))
        #expect(answer.text.contains("do not establish current use"))
    }

    @Test func chatSearchScopesToSelectedRecordAndCannotInventMissingResults() {
        let a = HealthDocument(id: "a", filename: "Lab photo", fileURL: URL(filePath: "/tmp/a"))
        a.pages = [DocumentPage(number: 1, text: "Glucose 105 mg/dL Reference range 70-100")]
        let b = HealthDocument(id: "b", filename: "Other photo", fileURL: URL(filePath: "/tmp/b"))
        b.pages = [DocumentPage(number: 1, text: "Creatinine 0.9 mg/dL")]
        let answer = LocalRecordLookup.answer(question: "Find glucose", documents: [a, b], selectedDocumentID: "a")
        #expect(answer.sources.map(\.documentID) == ["a"])
        #expect(answer.text.contains("105"))
        #expect(answer.text.contains("OCR"))
        let missing = LocalRecordLookup.answer(question: "Find creatinine", documents: [a, b], selectedDocumentID: "a")
        #expect(missing.sources.isEmpty)
        #expect(!missing.text.contains("0.9"))
    }

    @Test func latestLabsUseRecordDatesAndPreserveRanges() {
        let a = HealthDocument(id: "a", filename: "Old lab", fileURL: URL(filePath: "/tmp/a"), uploadedAt: .now)
        a.recordFacts = [fact(document: "a", value: "99", date: "2025-01-02")]
        let b = HealthDocument(id: "b", filename: "Recent lab", fileURL: URL(filePath: "/tmp/b"), uploadedAt: .distantPast)
        b.recordFacts = [fact(document: "b", date: "2026-09-18")]
        let answer = LocalRecordLookup.answer(question: "When was my last lab work?", documents: [a, b])
        #expect(answer.text.contains("2026-09-18"))
        #expect(answer.text.contains("70-100"))
        #expect(answer.sources.map(\.documentID) == ["b"])
    }

    @Test func chatPersistenceRetainsPageCitations() throws {
        let schema = Schema([HealthDocument.self, RecordFact.self, ChatMessage.self, HealthEvent.self, AnalysisResult.self])
        let store = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let message = ChatMessage(role: .assistant, content: "Quoted result")
        message.localSources = [LocalRecordSource(documentID: "a", pageNumber: 2, excerpt: "Glucose 105", reviewed: false)]
        store.mainContext.insert(message)
        try store.mainContext.save()
        let saved = try #require(store.mainContext.fetch(FetchDescriptor<ChatMessage>()).first)
        #expect(saved.localSources.first?.pageNumber == 2)
        #expect(saved.localSources.first?.excerpt == "Glucose 105")
    }
}
