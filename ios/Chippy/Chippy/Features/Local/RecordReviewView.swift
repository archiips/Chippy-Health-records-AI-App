import SwiftUI
import SwiftData
import PDFKit

struct RecordReviewView: View {
    let document: HealthDocument
    @Environment(\.modelContext) private var context
    @State private var selectedPage: Int
    @State private var editingFact: RecordFact?
    @State private var addingFact = false
    @State private var showOriginal = false
    @State private var showDetails = false
    @State private var analysisTask: Task<Void, Never>?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    init(document: HealthDocument, initialPage: Int = 1) {
        self.document = document
        _selectedPage = State(initialValue: initialPage)
    }

    var body: some View {
        List {
            Section("Source") {
                Picker("Page", selection: $selectedPage) {
                    ForEach(document.pages) { page in Text("Page \(page.number)").tag(page.number) }
                }
                RecordPagePreview(url: document.resolvedFileURL, pageNumber: selectedPage)
                Button("Open Original Page", systemImage: "doc.richtext") { showOriginal = true }
                DisclosureGroup("Read Page Text") {
                    Text(document.pages.first { $0.number == selectedPage }?.text ?? "No readable text on this page. Review the original.")
                        .font(.body).textSelection(.enabled)
                }
                Text("OCR can be wrong. Compare numbers, units, dates, and ranges with the original page.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Facts on page \(selectedPage)") {
                ForEach(document.recordFacts.filter { $0.pageNumber == selectedPage }) { fact in
                    Button { editingFact = fact } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(fact.name): \(fact.value) \(fact.unit ?? "")").font(.headline)
                            Label(fact.isConfirmed ? "Reviewed by you" : "Needs your review", systemImage: fact.isConfirmed ? "checkmark.shield" : "doc.viewfinder").font(.caption).foregroundStyle(fact.isConfirmed ? Color.secondary : Color.accentColor)
                            if let range = fact.referenceRange { Text("Recorded range: \(range)").font(.subheadline) }
                            if fact.kind == "lab" && fact.referenceRange == nil { Text("Reference range not recorded").font(.subheadline) }
                            Text(fact.quote).font(.subheadline).foregroundStyle(.secondary).lineLimit(4)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                }
                Button("Add Fact from Original", systemImage: "plus") { addingFact = true }
            }
            Section("On-device Suggestions") {
                Text("Suggestions remain unconfirmed until you review them. No diagnosis or treatment advice. Nothing is sent to a server.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if isAnalyzing {
                    ProgressView("Checking source evidence…")
                    Button("Cancel") { analysisTask?.cancel() }
                } else {
                    Button("Suggest Facts on This Device", systemImage: "sparkles") { analyze() }
                }
            }
        }.navigationTitle(document.filename).navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Record Details", systemImage: "slider.horizontal.3") { showDetails = true } }
            .sheet(isPresented: $showDetails) { RecordDetailsEditor(document: document) }
            .sheet(isPresented: $showOriginal) {
                NavigationStack {
                    OriginalPageView(url: document.resolvedFileURL, pageNumber: selectedPage)
                        .navigationTitle("Original · page \(selectedPage)")
                        .toolbar { Button("Done") { showOriginal = false } }
                }
            }
            .sheet(item: $editingFact) { fact in
                FactEditorView(document: document, pageNumber: fact.pageNumber, fact: fact)
            }
            .sheet(isPresented: $addingFact) { FactEditorView(document: document, pageNumber: selectedPage, fact: nil) }
            .alert("On-device Analysis", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onDisappear { analysisTask?.cancel() }
    }

    private func analyze() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        let pages = document.pages
        let revision = LocalRecordLifecycle.shared.revision
        analysisTask = Task {
            defer { isAnalyzing = false; analysisTask = nil }
            do {
                let results = try await LocalAnalysisService().extract(pages: pages)
                try Task.checkCancellation()
                guard revision == LocalRecordLifecycle.shared.revision else { throw CancellationError() }
                for result in results {
                    let candidate = result.candidate
                    guard !document.recordFacts.contains(where: {
                        $0.pageNumber == result.pageNumber && $0.name == candidate.name && $0.quote == candidate.quote
                    }) else { continue }
                    let fact = RecordFact(documentID: document.id, pageNumber: result.pageNumber,
                        kind: candidate.kind, name: candidate.name, value: candidate.value, unit: candidate.unit,
                        referenceRange: candidate.referenceRange, quote: candidate.quote, dateText: candidate.dateText)
                    fact.document = document
                    context.insert(fact)
                }
                try context.save()
            } catch is CancellationError {
                // Original and existing reviewed facts remain available.
            } catch {
                context.rollback()
                errorMessage = "\(error.localizedDescription)\nManual review is available. Nothing was uploaded."
            }
        }
    }
}
