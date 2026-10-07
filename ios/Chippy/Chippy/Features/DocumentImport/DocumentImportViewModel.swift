import SwiftUI
import SwiftData
import PDFKit
import UIKit

enum ImportSource { case scanner, files, photos }
enum ImportError: LocalizedError {
    case accessDenied, conversionFailed, notAuthenticated, consentRequired
    var errorDescription: String? {
        switch self {
        case .accessDenied: "Could not access the file."
        case .conversionFailed: "Could not process the document."
        case .notAuthenticated: "Please sign in again."
        case .consentRequired: "Choose cloud mode and allow cloud processing before uploading."
        }
    }
}

@Observable
@MainActor
final class DocumentImportViewModel {
    var isProcessing = false
    var showSourceSheet = false
    var showScanner = false
    var showFilePicker = false
    var showPhotoPicker = false
    var errorMessage: String?
    var showError = false
    private let processor = DocumentTextProcessor()

    func handleScannedImages(_ images: [UIImage], context: ModelContext, authManager: AuthManager, preferences: ProcessingPreferences) async {
        showScanner = false
        await process(auth: authManager, preferences: preferences) { scope in
            let data = try images.map { image in
                guard let data = image.pngData() else { throw ImportError.conversionFailed }
                return data
            }
            let pages = try await self.processor.imagePages(data)
            let pdf = PDFDocument()
            for (index, image) in images.enumerated() {
                guard let page = PDFPage(image: image) else { throw ImportError.conversionFailed }
                pdf.insert(page, at: index)
            }
            guard let pdfData = pdf.dataRepresentation() else { throw ImportError.conversionFailed }
            try await self.uploadAndSave(data: pdfData, filename: "Scan.pdf", pages: pages,
                context: context, auth: authManager, preferences: preferences, scope: scope)
        }
    }

    func handlePickedFile(_ url: URL, context: ModelContext, authManager: AuthManager, preferences: ProcessingPreferences) async {
        await process(auth: authManager, preferences: preferences) { scope in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let pages = try await self.processor.pdfPages(data)
            try await self.uploadAndSave(data: data, filename: url.lastPathComponent, pages: pages,
                context: context, auth: authManager, preferences: preferences, scope: scope)
        }
    }

    func handlePickedPhoto(_ image: UIImage, context: ModelContext, authManager: AuthManager, preferences: ProcessingPreferences) async {
        await handleScannedImages([image], context: context, authManager: authManager, preferences: preferences)
    }

    private func process(auth: AuthManager, preferences: ProcessingPreferences, _ work: (CloudOperationScope) async throws -> Void) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            let scope = try CloudOperationScope(auth: auth, preferences: preferences)
            try await work(scope)
        }
        catch { errorMessage = error.localizedDescription; showError = true }
    }

    private func uploadAndSave(data: Data, filename: String, pages: [DocumentPage], context: ModelContext,
                               auth: AuthManager, preferences: ProcessingPreferences, scope: CloudOperationScope) async throws {
        guard preferences.mode == .cloud, preferences.cloudConsentGranted else { throw ImportError.consentRequired }
        var token = try await scope.token(auth: auth, preferences: preferences)
        let userID = scope.userID
        let files = try CloudDocumentFiles.store(userID: userID)
        let url = try files.save(data, extension: "pdf")
        let text = pages.map(\.text).joined(separator: "\n\n")
        var remoteID: String?
        do {
            do {
                remoteID = try await DocumentService.shared.upload(fileURL: url, ocrText: text,
                    mimeType: "application/pdf", token: token, filename: filename)
            } catch APIError.httpError(let code, _) where code == 401 {
                guard scope.isValid(userID: auth.currentUserId, preferences: preferences), let refreshed = await auth.refreshIfNeeded(), scope.isValid(userID: auth.currentUserId, preferences: preferences) else { throw CancellationError() }
                token = refreshed
                remoteID = try await DocumentService.shared.upload(fileURL: url, ocrText: text,
                    mimeType: "application/pdf", token: token, filename: filename)
            }
            guard scope.isValid(userID: auth.currentUserId, preferences: preferences) else { throw CancellationError() }
            guard let remoteID else { throw ImportError.conversionFailed }
            let thumbnail = PDFDocument(data: data)?.page(at: 0)?.thumbnail(of: CGSize(width: 112, height: 144), for: .mediaBox).jpegData(compressionQuality: 0.8)
            let document = HealthDocument(id: remoteID, filename: filename, fileURL: url,
                processingStatus: .processing, thumbnailData: thumbnail, ocrText: text, remoteId: remoteID)
            document.pages = pages
            context.insert(document)
            try context.save()
        } catch {
            context.rollback()
            if remoteID == nil { try files.remove(url) }
            // If upload succeeded, retain the file for recovery and surface the failure.
            throw error
        }
    }
}
