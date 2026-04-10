import SwiftUI
import SwiftData
import QuickLook

struct DocumentDetailView: View {
    let document: HealthDocument
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @State private var showQuickLook = false
    @State private var showFileNotFoundAlert = false
    @State private var showDeleteConfirmation = false
    @State private var showExplainer = false
    @State private var cachedLabValues: [LabValue] = []

    var body: some View {
        List {
            previewSection
            if let analysis = document.analysisResult, analysis.hasContent {
                analysisSection(analysis)
            } else {
                noAnalysisSection
            }
            deleteSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(document.filename)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: document.resolvedFileURL, subject: Text(document.filename)) {
                    Label("Share document", systemImage: "square.and.arrow.up")
                }
            }
        }
        .confirmationDialog(
            "Delete \"\(document.filename)\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteDocument() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the document and its analysis.")
        }
        .task(id: document.id) {
            cachedLabValues = document.analysisResult?.decodedLabValues ?? []
        }
        .sheet(isPresented: $showQuickLook) {
            QuickLookPreview(url: document.resolvedFileURL)
                .ignoresSafeArea()
        }
        .alert("File Not Found", isPresented: $showFileNotFoundAlert) {
        } message: {
            Text("The original document file could not be found on this device.")
        }
        .safeAreaInset(edge: .bottom) {
            if document.analysisResult?.hasContent == true {
                explainButton
            }
        }
        .sheet(isPresented: $showExplainer) {
            ExplainerView(document: document)
        }
    }

    // MARK: - Sections

    private var previewSection: some View {
        Section {
            Button {
                guard FileManager.default.fileExists(atPath: document.resolvedFileURL.path) else {
                    showFileNotFoundAlert = true
                    return
                }
                showQuickLook = true
            } label: {
                HStack {
                    if let data = document.thumbnailData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .frame(width: 44, height: 56)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(document.filename)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text("Tap to view document")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityLabel("View \(document.filename)")
            .accessibilityHint("Opens the original document")
        }
    }

    @ViewBuilder
    private func analysisSection(_ analysis: AnalysisResult) -> some View {
        if let summary = analysis.summary, !summary.isEmpty {
            Section("Summary") {
                Text(summary)
                    .font(.subheadline)
            }
        }

        if !analysis.keyFindings.isEmpty {
            Section("Key Findings") {
                ForEach(analysis.keyFindings, id: \.self) { finding in
                    Label(finding, systemImage: "lightbulb")
                        .font(.subheadline)
                }
            }
        }

        if !analysis.diagnoses.isEmpty {
            Section("Diagnoses") {
                ForEach(analysis.diagnoses, id: \.self) { diagnosis in
                    Text(diagnosis)
                        .font(.subheadline)
                }
            }
        }

        if !analysis.medications.isEmpty {
            Section("Medications") {
                ForEach(analysis.medications, id: \.self) { med in
                    Label(med, systemImage: "pill")
                        .font(.subheadline)
                }
            }
        }

        if !cachedLabValues.isEmpty {
            Section("Lab Values") {
                ForEach(cachedLabValues) { lab in
                    LabValueRow(labValue: lab)
                }
            }
        }

        Section {
            Text("For informational purposes only. Not a substitute for professional medical advice.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var noAnalysisSection: some View {
        Section {
            switch document.processingStatus {
            case .processing:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Analyzing document…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            case .failed:
                Label("Analysis failed. Try retrying the document.", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Analysis failed. Go back and swipe the document to retry.")
                    .accessibilityAddTraits(.isStaticText)
            case .complete:
                Label("No analysis available.", systemImage: "doc.questionmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Document", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func deleteDocument() async {
        guard let token = authManager.accessToken, let remoteId = document.remoteId else { return }
        try? await DocumentService.shared.deleteDocument(id: remoteId, token: token)
        try? DocumentRepository(context: context).delete(document)
        dismiss()
    }

    private var explainButton: some View {
        Button {
            showExplainer = true
        } label: {
            Label("Explain This Document", systemImage: "sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

// MARK: - Lab Value Row

private struct LabValueRow: View {
    let labValue: LabValue

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(labValue.name)
                    .font(.subheadline)
                Text("Ref: \(labValue.referenceRange?.isEmpty == false ? labValue.referenceRange! : "Not available")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(labValue.value)\(labValue.unit.map { " \($0)" } ?? "")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(labValue.isAbnormal ? .red : .primary)
                if labValue.isAbnormal {
                    Text("Abnormal")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(labValueAccessibilityLabel)
    }

    private var labValueAccessibilityLabel: String {
        let valueWithUnit = "\(labValue.value)\(labValue.unit.map { " \($0)" } ?? "")"
        let status = labValue.isAbnormal ? "Abnormal: outside reference range." : "Normal."
        let range = labValue.referenceRange.map { "Reference range: \($0)." } ?? ""
        return "\(labValue.name): \(valueWithUnit). \(status) \(range)"
    }
}

// MARK: - QuickLook wrapper

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
