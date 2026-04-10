import SwiftUI
import SwiftData
import VisionKit

struct DocumentLibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(AuthManager.self) private var authManager
    @Query(sort: \HealthDocument.uploadedAt, order: .reverse) private var documents: [HealthDocument]

    @State private var importVM = DocumentImportViewModel()
    @State private var documentToDelete: HealthDocument?
    @State private var pollingTask: Task<Void, Never>?
    @State private var activeFilter: DocumentType? = nil
    @State private var sortOldestFirst = false
    @State private var isInitialLoad = true

    private var filteredDocuments: [HealthDocument] {
        let base = activeFilter.map { f in documents.filter { $0.documentType == f } } ?? documents
        return sortOldestFirst ? base.sorted { $0.uploadedAt < $1.uploadedAt } : base
    }

    private var isDeletingDocument: Binding<Bool> {
        Binding(
            get: { documentToDelete != nil },
            set: { if !$0 { documentToDelete = nil } }
        )
    }

    var body: some View {
        Group {
            if isInitialLoad {
                skeletonList
            } else if filteredDocuments.isEmpty {
                emptyState
            } else {
                documentList
            }
        }
        .navigationTitle("Documents")
        .toolbar { toolbarContent }
        .confirmationDialog("Import Document", isPresented: $importVM.showSourceSheet) {
            if VNDocumentCameraViewController.isSupported {
                Button("Scan Document") { importVM.showScanner = true }
            }
            Button("Choose File") { importVM.showFilePicker = true }
            Button("Choose Photo") { importVM.showPhotoPicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $importVM.showScanner) {
            DocumentScannerView(
                onCompletion: { images in
                    Task { await importVM.handleScannedImages(images, context: context, authManager: authManager) }
                },
                onCancellation: { importVM.showScanner = false }
            )
            .interactiveDismissDisabled()
            .ignoresSafeArea()
        }
        .sheet(isPresented: $importVM.showFilePicker) {
            FilePicker(
                onCompletion: { url in
                    importVM.showFilePicker = false
                    Task { await importVM.handlePickedFile(url, context: context, authManager: authManager) }
                },
                onCancellation: { importVM.showFilePicker = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $importVM.showPhotoPicker) {
            PhotoPicker(
                onCompletion: { image in
                    importVM.showPhotoPicker = false
                    Task { await importVM.handlePickedPhoto(image, context: context, authManager: authManager) }
                },
                onCancellation: { importVM.showPhotoPicker = false }
            )
            .ignoresSafeArea()
        }
        .overlay {
            if importVM.isProcessing {
                processingOverlay
            }
        }
        .alert("Import Failed", isPresented: $importVM.showError) {
            Button("OK") { importVM.errorMessage = nil }
        } message: {
            Text(importVM.errorMessage ?? "")
        }
        .confirmationDialog(
            "Delete \"\(documentToDelete?.filename ?? "")\"?",
            isPresented: isDeletingDocument,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let doc = documentToDelete {
                    Task { await deleteDocument(doc) }
                }
                documentToDelete = nil
            }
            Button("Cancel", role: .cancel) { documentToDelete = nil }
        }
        .task {
            await syncAll()
            isInitialLoad = false
            startPolling()
        }
        .onDisappear { stopPolling() }
    }

    // MARK: - Subviews

    private var skeletonList: some View {
        List {
            ForEach(0..<6, id: \.self) { _ in
                SkeletonRow()
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
        .accessibilityLabel("Loading documents")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            activeFilter != nil ? "No \(activeFilter!.displayName) Documents" : "No Documents",
            systemImage: "doc.text",
            description: Text(
                activeFilter != nil
                    ? "No \(activeFilter!.displayName.lowercased()) documents found."
                    : "Tap + to import your first medical document."
            )
        )
    }

    private var documentList: some View {
        List {
            ForEach(filteredDocuments) { document in
                NavigationLink(value: Route.documentDetail(document)) {
                    DocumentCard(document: document)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        documentToDelete = document
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    if document.processingStatus == .failed {
                        Button {
                            Task { await retryDocument(document) }
                        } label: {
                            Label("Retry", systemImage: "arrow.counterclockwise")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await syncAll()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            sortMenu
        }

        ToolbarItem(placement: .topBarTrailing) {
            filterMenu
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Import document", systemImage: "plus") {
                importVM.showSourceSheet = true
            }
        }
    }

    private var filterMenu: some View {
        Menu(
            activeFilter.map { "Filter: \($0.displayName)" } ?? "Filter",
            systemImage: activeFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
        ) {
            Button {
                activeFilter = nil
            } label: {
                Label("All", systemImage: activeFilter == nil ? "checkmark" : "doc.text")
            }
            Divider()
            ForEach(DocumentType.allCases.filter { $0 != .unknown }, id: \.self) { type in
                Button {
                    activeFilter = activeFilter == type ? nil : type
                } label: {
                    if activeFilter == type {
                        Label(type.displayName, systemImage: "checkmark")
                    } else {
                        Text(type.displayName)
                    }
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu(
            sortOldestFirst ? "Sort: Oldest First" : "Sort: Newest First",
            systemImage: "arrow.up.arrow.down"
        ) {
            Button {
                sortOldestFirst = false
            } label: {
                Label("Newest First", systemImage: !sortOldestFirst ? "checkmark" : "arrow.down")
            }
            Button {
                sortOldestFirst = true
            } label: {
                Label("Oldest First", systemImage: sortOldestFirst ? "checkmark" : "arrow.up")
            }
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Importing…")
                    .foregroundStyle(.white)
                    .font(.subheadline)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                let repo = DocumentRepository(context: context)
                guard let processing = try? repo.fetchProcessing(), !processing.isEmpty else { continue }
                let ok = await syncAll()
                if !ok {
                    // Auth failure — wait longer before retrying to avoid hammering
                    try? await Task.sleep(for: .seconds(30))
                }
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Sync

    /// Syncs processing docs and complete docs missing analysis results.
    /// Returns false if the token is invalid (caller should stop polling).
    @discardableResult
    private func syncAll() async -> Bool {
        guard let token = await authManager.validToken() else { return false }

        let repo = DocumentRepository(context: context)
        let all = (try? repo.fetchAll()) ?? []

        let needsSync = all.filter {
            $0.processingStatus == .processing ||
            ($0.processingStatus == .complete && $0.analysisResult == nil)
        }
        for doc in needsSync {
            let ok = await syncDocument(doc, token: token)
            if !ok { return false }  // 401 — stop syncing this round
        }
        return true
    }

    /// Returns false on auth failure so the caller can stop polling.
    @discardableResult
    private func syncDocument(_ doc: HealthDocument, token: String) async -> Bool {
        guard let remoteId = doc.remoteId else { return true }
        let remote: DocumentDetailAPIModel
        do {
            remote = try await DocumentService.shared.fetchDocumentWithAnalysis(id: remoteId, token: token)
        } catch APIError.httpError(let code, _) where code == 401 {
            _ = await authManager.refreshIfNeeded()
            return false
        } catch {
            return true  // network or other error — keep polling
        }

        if remote.status == "complete" {
            doc.processingStatus = .complete
            if let typeString = remote.documentType {
                doc.documentType = DocumentType(rawValue: typeString) ?? doc.documentType
            }
            if let apiAnalysis = remote.analysisResult, doc.analysisResult == nil {
                let labData = (try? JSONEncoder().encode(
                    apiAnalysis.labValues.map {
                        LabValue(name: $0.name, value: $0.value, unit: $0.unit, referenceRange: $0.referenceRange, isAbnormal: $0.isAbnormal)
                    }
                )) ?? Data()
                let analysis = AnalysisResult(
                    id: UUID().uuidString,
                    documentId: remoteId,
                    summary: apiAnalysis.summary,
                    diagnoses: apiAnalysis.diagnoses,
                    medications: apiAnalysis.medications.map(\.displayString),
                    labValues: labData,
                    keyFindings: apiAnalysis.keyFindings
                )
                doc.analysisResult = analysis
                context.insert(analysis)
            }
        } else if remote.status == "failed" {
            doc.processingStatus = .failed
        }
        try? context.save()
        return true
    }

    // MARK: - Actions

    private func deleteDocument(_ document: HealthDocument) async {
        guard let token = authManager.accessToken, let remoteId = document.remoteId else { return }
        try? await DocumentService.shared.deleteDocument(id: remoteId, token: token)
        try? DocumentRepository(context: context).delete(document)
    }

    private func retryDocument(_ document: HealthDocument) async {
        guard let token = await authManager.validToken(), let remoteId = document.remoteId else { return }
        do {
            try await DocumentService.shared.retry(id: remoteId, token: token)
            document.processingStatus = .processing
            try? context.save()
        } catch {
            // Retry failed — leave status as .failed so the user can try again
        }
    }
}
