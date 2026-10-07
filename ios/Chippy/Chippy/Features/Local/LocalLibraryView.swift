import SwiftUI
import SwiftData
import VisionKit

struct LocalLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \HealthDocument.uploadedAt, order: .reverse) private var documents: [HealthDocument]
    @State private var importer = LocalImportViewModel()
    @State private var showFiles = false
    @State private var showScanner = false
    @State private var showPhotos = false
    @State private var pendingDelete: HealthDocument?
    @State private var errorMessage: String?
    @State private var search = ""
    @State private var type: DocumentType?
    @State private var oldestFirst = false
    private var filtered: [HealthDocument] {
        let matches = documents.filter { doc in (type == nil || doc.documentType == type) && (search.isEmpty || doc.filename.localizedCaseInsensitiveContains(search) || doc.pages.contains { $0.text.localizedCaseInsensitiveContains(search) }) }
        return oldestFirst ? matches.reversed() : matches
    }

    var body: some View {
        List {
            Section {
                Label("Your records stay on this device", systemImage: "lock.shield")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if documents.isEmpty {
                ContentUnavailableView("Your records, together", systemImage: "doc.text",
                    description: Text("Import a PDF, photo, or scan. Review the original before confirming facts."))
            }
            Section {
                HStack(spacing: 12) {
                    Button("Take a Scan", systemImage: "camera") { showScanner = true }.disabled(!VNDocumentCameraViewController.isSupported)
                    Spacer()
                    Button("Add Photo", systemImage: "photo.badge.plus") { showPhotos = true }
                }.font(.subheadline).padding(.vertical, 6).disabled(importer.isProcessing)
            }
            if !documents.isEmpty && filtered.isEmpty { ContentUnavailableView.search(text: search) }
            ForEach(filtered) { document in
                NavigationLink { RecordReviewView(document: document) } label: {
                    LocalDocumentRow(document: document)
                }
                .swipeActions { Button("Delete", role: .destructive) { pendingDelete = document } }
            }
            if importer.isProcessing { ProgressView("Reading every page on this device…") }
        }
        .navigationTitle("Records")
        .searchable(text: $search, prompt: "Find a record or words on a page")
        .toolbar {
            Menu("Filter Records", systemImage: "line.3.horizontal.decrease") {
                Button("All Document Types") { type = nil }
                ForEach(DocumentType.allCases, id: \.self) { kind in Button(kind.displayName) { type = kind } }
                Divider()
                Button(oldestFirst ? "Newest First" : "Oldest First") { oldestFirst.toggle() }
            }
            NavigationLink { LocalSearchView() } label: { Label("Search Pages", systemImage: "doc.text.magnifyingglass") }
            Menu("Import", systemImage: "plus") {
                Button("Import PDF", systemImage: "doc") { showFiles = true }
                Button("Import Photo", systemImage: "photo") { showPhotos = true }
                Button("Scan Pages", systemImage: "camera") { showScanner = true }
                    .disabled(!VNDocumentCameraViewController.isSupported)
            }.disabled(importer.isProcessing)
        }
        .sheet(isPresented: $showFiles) {
            FilePicker { url in
                showFiles = false
                Task { await importer.importFile(url, context: context) }
            } onCancellation: { showFiles = false }
        }
        .sheet(isPresented: $showPhotos) {
            PhotoPicker { image in
                showPhotos = false
                Task { await importer.importImages([image], context: context) }
            } onCancellation: { showPhotos = false }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { images in
                showScanner = false
                Task { await importer.importImages(images, filename: "Document scan", context: context) }
            } onCancellation: { showScanner = false }
                .interactiveDismissDisabled()
        }
        .alert("Delete this record?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) {
                guard let document = pendingDelete else { return }
                LocalRecordLifecycle.shared.invalidatePendingWork()
                do {
                    try LocalDocumentFiles().remove(document.resolvedFileURL)
                    let messages = try context.fetch(FetchDescriptor<ChatMessage>())
                    for message in messages where message.sourceDocumentIds.contains(document.id) || message.localSources.contains(where: { $0.documentID == document.id }) { context.delete(message) }
                    context.delete(document)
                    try context.save()
                } catch { context.rollback(); errorMessage = error.localizedDescription }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { Text("The original, page text, and reviewed facts will be removed from this device.") }
        .alert("Import or cleanup failed", isPresented: Binding(get: { importer.errorMessage != nil || errorMessage != nil }, set: { if !$0 { importer.errorMessage = nil; errorMessage = nil } })) {
            Button("OK") { importer.errorMessage = nil; errorMessage = nil }
        } message: { Text(errorMessage ?? importer.errorMessage ?? "") }
    }
}
