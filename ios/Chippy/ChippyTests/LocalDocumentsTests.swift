import Testing
import Foundation
import PDFKit
import UIKit
import SwiftData
import FoundationModels
@testable import Chippy

@MainActor
@Suite(.serialized)
struct LocalDocumentsTests {
    @Test func clearingRecordsInvalidatesAnImportSuspendedDuringOCR() async throws {
        let schema = Schema([HealthDocument.self, RecordFact.self, HealthEvent.self, AnalysisResult.self, ChatMessage.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let reader = SuspendedPageReader()
        let importer = LocalImportViewModel(readPDF: { data in await reader.read(data) })
        let source = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appendingPathExtension("pdf")
        try Data("synthetic reader fixture".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let task = Task { await importer.importFile(source, context: context) }
        await reader.waitForStart()
        LocalRecordLifecycle.shared.invalidatePendingWork()
        await reader.finish()
        await task.value
        #expect(try context.fetch(FetchDescriptor<HealthDocument>()).isEmpty)
        #expect(!importer.isProcessing)
    }

    @Test func cloudOperationCannotMoveToAnotherAccountOrRenewedPermission() throws {
        let preferences = ProcessingPreferences()
        #expect(throws: (any Error).self) { try CloudOperationScope(userID: "alpha", preferences: preferences) }
        preferences.enterCloud()
        let scope = try CloudOperationScope(userID: "alpha", preferences: preferences)
        #expect(scope.isValid(userID: "alpha", preferences: preferences))
        #expect(!scope.isValid(userID: "beta", preferences: preferences))
        preferences.useLocal()
        #expect(!scope.isValid(userID: "alpha", preferences: preferences))
        preferences.enterCloud()
        #expect(!scope.isValid(userID: "alpha", preferences: preferences))
    }
    @Test func legacyCleanupDoesNotRemoveNewStoresOrOriginals() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for name in ["default.store", "default.store-wal", "new-local.pdf"] { try Data("synthetic".utf8).write(to: root.appending(path: name)) }
        let current = root.appending(path: "local-record-files")
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: current.appending(path: "original.pdf"))
        let cleaner = LegacyCacheCleanup(root: root)
        #expect(cleaner.hasLegacyFiles)
        try cleaner.remove()
        #expect(!cleaner.hasLegacyFiles)
        #expect(FileManager.default.fileExists(atPath: current.appending(path: "original.pdf").path))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "new-local.pdf").path))
    }
    @Test func correctionsRetainInitialEvidenceAndRequireExplicitConfirmation() throws {
        let fact = RecordFact(documentID: "synthetic", pageNumber: 2, kind: "lab", name: "Glucose", value: "105", unit: "mg/dL", referenceRange: "70-100", quote: "Glucose 105 mg/dL range 70-100", dateText: nil)
        #expect(!fact.isConfirmed)
        let corrected = FactCandidate(kind: "lab", name: "Glucose", value: "106", unit: "mg/dL", referenceRange: "70-100", dateText: "2026-10-06", quote: "Glucose 106 mg/dL range 70-100 on 2026-10-06")
        fact.confirm(corrected)
        #expect(fact.isConfirmed && fact.wasCorrected)
        #expect(fact.value == "106")
        #expect(fact.originalCandidate?.value == "105")
        #expect(fact.originalCandidate?.dateText == nil)
        #expect(fact.originalCandidate?.quote == "Glucose 105 mg/dL range 70-100")
        fact.confirm(corrected)
        #expect(fact.originalValue == "105")
        let manual = RecordFact(documentID: "synthetic", pageNumber: 1, kind: corrected.kind, name: corrected.name, value: corrected.value,
            unit: corrected.unit, referenceRange: corrected.referenceRange, quote: corrected.quote, dateText: corrected.dateText)
        manual.confirm(corrected)
        #expect(manual.isConfirmed && !manual.wasCorrected)
    }
    @Test func cloudPermissionIsExplicitAndResetsOnLocalMode() {
        let preferences = ProcessingPreferences()
        #expect(preferences.mode == .local)
        #expect(!preferences.cloudConsentGranted)
        preferences.enterCloud()
        #expect(preferences.mode == .cloud && preferences.cloudConsentGranted)
        preferences.useLocal()
        #expect(preferences.mode == .local && !preferences.cloudConsentGranted)
        #expect(ProcessingPreferences().mode == .local)
    }

    @Test func localImportPersistsPagesWithoutAuthAndCascadesReviewedFacts() async throws {
        let schema = Schema([HealthDocument.self, RecordFact.self, HealthEvent.self, AnalysisResult.self, ChatMessage.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 500)).pdfData { ctx in
            for text in ["SYNTHETIC Glucose 105 mg/dL range 70-100", "SYNTHETIC visit 2026-10-06"] {
                ctx.beginPage()
                (text as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
            }
        }
        let original = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appendingPathExtension("pdf")
        try data.write(to: original)
        defer { try? FileManager.default.removeItem(at: original) }
        let importer = LocalImportViewModel()
        await importer.importFile(original, context: context)
        #expect(importer.errorMessage == nil)
        let document = try #require(context.fetch(FetchDescriptor<HealthDocument>()).first)
        defer { try? LocalDocumentFiles().remove(document.resolvedFileURL) }
        #expect(document.remoteId == nil)
        #expect(document.pages.count == 2)
        #expect(try Data(contentsOf: document.resolvedFileURL) == data)
        let fact = RecordFact(documentID: document.id, pageNumber: 1, kind: "lab", name: "Glucose", value: "105", quote: document.pages[0].text)
        fact.document = document
        context.insert(fact)
        try context.save()
        #expect(document.recordFacts.count == 1)
        context.delete(document)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<RecordFact>()).isEmpty)
    }

    @Test func unavailableAILeavesManualSourceDataUsable() async throws {
        guard !SystemLanguageModel.default.isAvailable else { return }
        let pages = [DocumentPage(number: 1, text: "SYNTHETIC Glucose 105")]
        await #expect(throws: LocalAnalysisError.self) { try await LocalAnalysisService().extract(pages: pages) }
        #expect(pages.first?.text == "SYNTHETIC Glucose 105")
    }

    @Test func invalidOrUnknownDatesAreNeverReplacedWithToday() {
        let fact = RecordFact(documentID: "synthetic", pageNumber: 1, kind: "visit", name: "Visit", value: "recorded", quote: "Visit recorded", dateText: "2026-02-30")
        #expect(fact.eventDate == nil)
        fact.dateText = "10/06/2026"
        #expect(fact.eventDate == nil)
        fact.dateText = "2026-10-06"
        #expect(fact.eventDate != nil)
    }

    @Test func clearingManagedFilesPreservesOtherDirectories() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let sibling = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory); try? FileManager.default.removeItem(at: sibling) }
        let files = LocalDocumentFiles(directory: directory)
        let file = try files.save(Data("synthetic".utf8), extension: "pdf")
        try Data("keep".utf8).write(to: sibling)
        try files.removeAll()
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(FileManager.default.fileExists(atPath: sibling.path))
    }

    @Test func duplicateDisplayNamesNeverOverwriteFiles() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let files = LocalDocumentFiles(directory: dir)
        let first = try files.save(Data("first".utf8), extension: "pdf")
        let second = try files.save(Data("second".utf8), extension: "pdf")
        #expect(first != second)
        #expect(try Data(contentsOf: first) == Data("first".utf8))
        #expect(try Data(contentsOf: second) == Data("second".utf8))
    }

    @Test func deletionRejectsAnUnmanagedFile() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let outside = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: outside) }
        try Data("keep".utf8).write(to: outside)
        let files = LocalDocumentFiles(directory: dir)
        #expect(throws: (any Error).self) { try files.remove(outside) }
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }

    @Test func pdfTextPreservesPageOrder() async throws {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 500)).pdfData { ctx in
            for text in ["SYNTHETIC first page", "SYNTHETIC second page"] {
                ctx.beginPage()
                (text as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: [.font: UIFont.systemFont(ofSize: 18)])
            }
        }
        let pages = try await DocumentTextProcessor().pdfPages(data)
        #expect(pages.map(\.number) == [1, 2])
        #expect(pages[0].text.contains("first page"))
        #expect(pages[1].text.contains("second page"))
    }

    @Test func corruptPDFDoesNotBecomeAnEmptySuccessfulImport() async {
        await #expect(throws: (any Error).self) {
            try await DocumentTextProcessor().pdfPages(Data("invalid".utf8))
        }
    }

    @Test func everyScannedPageIsRecognized() async throws {
        let images = ["SYNTHETIC ALPHA PAGE", "SYNTHETIC BETA PAGE"].map { text in
            UIGraphicsImageRenderer(size: CGSize(width: 900, height: 500)).image { ctx in
                UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 900, height: 500))
                (text as NSString).draw(at: CGPoint(x: 50, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 38), .foregroundColor: UIColor.black])
            }
        }
        let pages = try await DocumentTextProcessor().imagePages(images.compactMap { $0.pngData() })
        #expect(pages.count == 2)
        #expect(pages[0].text.contains("ALPHA"))
        #expect(pages[1].text.contains("BETA"))
        let scannedPDF = PDFDocument()
        for (index, image) in images.enumerated() {
            scannedPDF.insert(try #require(PDFPage(image: image)), at: index)
        }
        let recovered = try await DocumentTextProcessor().pdfPages(try #require(scannedPDF.dataRepresentation()))
        #expect(recovered.map(\.number) == [1, 2])
        #expect(recovered[0].text.contains("ALPHA"))
        #expect(recovered[1].text.contains("BETA"))
    }

    @Test func blankPDFKeepsItsPageForManualOriginalReview() async throws {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 500)).pdfData { context in context.beginPage() }
        let pages = try await DocumentTextProcessor().pdfPages(data)
        #expect(pages.count == 1)
        #expect(pages[0].number == 1 && pages[0].text.isEmpty)
        await #expect(throws: (any Error).self) { try await DocumentTextProcessor().imagePages([]) }
    }

    @Test func candidateMustQuoteSourceAndCannotInventAValue() {
        let page = DocumentPage(number: 1, text: "SYNTHETIC Glucose 105 mg/dL reference 70-100 on 2026-10-06")
        let good = FactCandidate(kind: "lab", name: "Glucose", value: "105", unit: "mg/dL", referenceRange: "70-100", dateText: "2026-10-06", quote: page.text)
        #expect(FactEvidence.validate(good, in: page))
        var bad = good; bad.value = "5"
        #expect(!FactEvidence.validate(bad, in: page))
        for recorded in ["-105", "<105", ">105", "≤105", "≥105", "+105", "< 105", "− 105", "1,105", "105×10^3"] {
            let signedPage = DocumentPage(number: 1, text: "Glucose \(recorded) mg/dL")
            let altered = FactCandidate(kind: "lab", name: "Glucose", value: "105", unit: "mg/dL", referenceRange: nil, dateText: nil, quote: signedPage.text)
            #expect(!FactEvidence.validate(altered, in: signedPage))
            var intact = altered; intact.value = recorded
            #expect(FactEvidence.validate(intact, in: signedPage))
        }
        bad = good; bad.quote = "Glucose 90 mg/dL"
        #expect(!FactEvidence.validate(bad, in: page))
    }

    @Test func exportIncludesConfirmedFactsOnlyAndKeepsPageEvidence() {
        let confirmed = RecordFact(documentID: "doc", pageNumber: 2, kind: "medication", name: "SYNTHETIC historical medicine", value: "5 mg", quote: "SYNTHETIC historical medicine 5 mg", dateText: nil)
        confirmed.isConfirmed = true
        let pending = RecordFact(documentID: "doc", pageNumber: 1, kind: "lab", name: "SYNTHETIC pending", value: "100", quote: "SYNTHETIC pending 100")
        let text = ReviewedRecordExport.text(facts: [confirmed, pending], filenames: ["doc": "report.pdf"])
        #expect(text.contains("historical medicine"))
        #expect(text.contains("report.pdf, page 2"))
        #expect(!text.contains("pending"))
        #expect(confirmed.eventDate == nil)
    }

    @Test func longPagesAreBoundedWithoutDroppingText() {
        let text = String(repeating: "SYNTHETIC value 105. ", count: 1000)
        let chunks = DocumentPage(number: 4, text: text).segments(maxCharacters: 2000)
        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { $0.number == 4 && $0.text.count <= 2000 })
        #expect(chunks.map(\.text).joined() == text)
    }
}

private actor SuspendedPageReader {
    private var continuation: CheckedContinuation<[DocumentPage], Never>?
    private var started: CheckedContinuation<Void, Never>?
    func read(_ data: Data) async -> [DocumentPage] {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started?.resume(); started = nil
        }
    }
    func waitForStart() async {
        if continuation != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func finish() {
        continuation?.resume(returning: [DocumentPage(number: 1, text: "SYNTHETIC Glucose 105")])
        continuation = nil
    }
}
