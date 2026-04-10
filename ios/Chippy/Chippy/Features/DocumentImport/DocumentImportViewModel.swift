import SwiftUI
import SwiftData
import Vision
import PDFKit
import QuickLookThumbnailing
import UIKit

enum ImportSource { case scanner, files, photos }
enum ImportError: LocalizedError {
    case accessDenied, conversionFailed, notAuthenticated

    var errorDescription: String? {
        switch self {
        case .accessDenied:      "Could not access the file."
        case .conversionFailed:  "Could not process the document."
        case .notAuthenticated:  "Please sign in again."
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

    // MARK: - Entry points

    func handleScannedImages(_ images: [UIImage], context: ModelContext, authManager: AuthManager) async {
        showScanner = false
        await process {
            let pdfURL = try self.saveImagesToPDF(images)
            let ocrText = await self.extractOCR(from: images.first)
            try await self.uploadAndSave(fileURL: pdfURL, ocrText: ocrText, mimeType: "application/pdf", context: context, authManager: authManager)
        }
    }

    func handlePickedFile(_ url: URL, context: ModelContext, authManager: AuthManager) async {
        await process {
            guard url.startAccessingSecurityScopedResource() else { throw ImportError.accessDenied }
            defer { url.stopAccessingSecurityScopedResource() }
            let destURL = try self.copyToAppSupport(from: url)
            try await self.uploadAndSave(fileURL: destURL, ocrText: "", mimeType: "application/pdf", context: context, authManager: authManager)
        }
    }

    func handlePickedPhoto(_ image: UIImage, context: ModelContext, authManager: AuthManager) async {
        await process {
            guard let jpegData = image.jpegData(compressionQuality: 0.8) else { throw ImportError.conversionFailed }
            let filename = "photo_\(Int(Date.now.timeIntervalSince1970)).jpg"
            let destURL = try self.saveData(jpegData, filename: filename)
            let ocrText = await self.extractOCR(from: image)
            try await self.uploadAndSave(fileURL: destURL, ocrText: ocrText, mimeType: "image/jpeg", context: context, authManager: authManager)
        }
    }

    // MARK: - Private helpers

    private func process(_ work: @escaping () async throws -> Void) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await work()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func uploadAndSave(fileURL: URL, ocrText: String, mimeType: String, context: ModelContext, authManager: AuthManager) async throws {
        guard var validToken = await authManager.validToken() else { throw ImportError.notAuthenticated }

        let thumbnailData = await generateThumbnail(from: fileURL)
        let documentId: String
        do {
            documentId = try await DocumentService.shared.upload(
                fileURL: fileURL,
                ocrText: ocrText,
                mimeType: mimeType,
                token: validToken
            )
        } catch APIError.httpError(let code, _) where code == 401 {
            // Token expired — refresh once and retry
            guard let refreshed = await authManager.refreshIfNeeded() else { throw ImportError.notAuthenticated }
            validToken = refreshed
            documentId = try await DocumentService.shared.upload(
                fileURL: fileURL,
                ocrText: ocrText,
                mimeType: mimeType,
                token: validToken
            )
        }

        let doc = HealthDocument(
            id: documentId,
            filename: fileURL.lastPathComponent,
            fileURL: fileURL,
            processingStatus: .processing,
            thumbnailData: thumbnailData,
            ocrText: ocrText.isEmpty ? nil : ocrText,
            remoteId: documentId
        )
        try DocumentRepository(context: context).insert(doc)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func saveImagesToPDF(_ images: [UIImage]) throws -> URL {
        let pdf = PDFDocument()
        for (i, img) in images.enumerated() {
            if let page = PDFPage(image: img) { pdf.insert(page, at: i) }
        }
        let url = try appSupportURL("scan_\(Int(Date.now.timeIntervalSince1970)).pdf")
        guard pdf.write(to: url) else { throw ImportError.conversionFailed }
        try setProtection(on: url)
        return url
    }

    private func copyToAppSupport(from url: URL) throws -> URL {
        let dest = try appSupportURL(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: url, to: dest)
        try setProtection(on: dest)
        return dest
    }

    private func saveData(_ data: Data, filename: String) throws -> URL {
        let url = try appSupportURL(filename)
        try data.write(to: url, options: .completeFileProtection)
        return url
    }

    private func appSupportURL(_ filename: String) throws -> URL {
        let dir = URL.applicationSupportDirectory.appending(path: "documents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: filename)
    }

    private func setProtection(on url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }

    private func extractOCR(from image: UIImage?) async -> String {
        guard let cgImage = image?.cgImage else { return "" }
        return await Task.detached(priority: .utility) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
            return (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }.value
    }

    private func generateThumbnail(from url: URL) async -> Data? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 112, height: 144),
            scale: 2,
            representationTypes: .thumbnail
        )
        let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        return rep?.uiImage.jpegData(compressionQuality: 0.8)
    }
}
