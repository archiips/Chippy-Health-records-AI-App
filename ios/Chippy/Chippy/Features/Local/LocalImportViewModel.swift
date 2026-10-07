import SwiftUI
import SwiftData
import PDFKit

@Observable
@MainActor
final class LocalImportViewModel {
    var isProcessing = false
    var errorMessage: String?
    var importedDocument: HealthDocument?
    private let processor = DocumentTextProcessor()
    private let readPDF: @Sendable (Data) async throws -> [DocumentPage]

    init(readPDF: @escaping @Sendable (Data) async throws -> [DocumentPage] = { data in
        try await DocumentTextProcessor().pdfPages(data)
    }) { self.readPDF = readPDF }

    func importFile(_ url: URL, context: ModelContext) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        await perform(context: context, filename: url.lastPathComponent) {
            let data = try Data(contentsOf: url)
            return (data, try await self.readPDF(data))
        }
    }

    func importImages(_ images: [UIImage], filename: String = "Photo record", context: ModelContext, expectedRevision: Int? = nil) async {
        if let expectedRevision, expectedRevision != LocalRecordLifecycle.shared.revision { return }
        await perform(context: context, filename: filename) {
            let imageData = try images.map { image in
                guard let data = image.pngData() else { throw ImportError.conversionFailed }
                return data
            }
            let pdf = PDFDocument()
            for (index, image) in images.enumerated() {
                guard let page = PDFPage(image: image) else { throw ImportError.conversionFailed }
                pdf.insert(page, at: index)
            }
            guard let data = pdf.dataRepresentation() else { throw ImportError.conversionFailed }
            return (data, try await self.processor.imagePages(imageData))
        }
    }

    private func perform(context: ModelContext, filename: String,
                         work: () async throws -> (Data, [DocumentPage])) async {
        guard !isProcessing else { return }
        errorMessage = nil
        importedDocument = nil
        isProcessing = true
        let revision = LocalRecordLifecycle.shared.revision
        defer { isProcessing = false }
        var savedURL: URL?
        do {
            let (data, pages) = try await work()
            guard LocalRecordLifecycle.shared.revision == revision else { throw CancellationError() }
            try Task.checkCancellation()
            let files = LocalDocumentFiles()
            let url = try files.save(data, extension: "pdf")
            savedURL = url
            let document = HealthDocument(filename: filename, fileURL: url, processingStatus: .complete,
                ocrText: pages.map(\.text).joined(separator: "\n\n"))
            document.pages = pages
            document.thumbnailData = PDFDocument(data: data)?.page(at: 0)?.thumbnail(of: CGSize(width: 180, height: 240), for: .mediaBox).jpegData(compressionQuality: 0.8)
            context.insert(document)
            try context.save()
            importedDocument = document
        } catch is CancellationError {
            // A delete/reset invalidates in-flight imports before they write files or metadata.
        } catch {
            context.rollback()
            if let savedURL {
                do { try LocalDocumentFiles().remove(savedURL) }
                catch { errorMessage = "Import failed and file cleanup failed. Use Delete Local Records to retry cleanup."; return }
            }
            errorMessage = error.localizedDescription
        }
    }
}
