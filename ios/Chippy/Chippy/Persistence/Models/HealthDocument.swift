import Foundation
import SwiftData

@Model
final class HealthDocument {
    @Attribute(.unique) var id: String
    var filename: String
    var fileURL: URL
    var documentType: DocumentType
    var processingStatus: ProcessingStatus
    var thumbnailData: Data?
    var ocrText: String?
    var uploadedAt: Date
    var remoteId: String?  // Supabase document UUID (same as id after upload)

    @Relationship(deleteRule: .cascade)
    var analysisResult: AnalysisResult?

    @Relationship(deleteRule: .cascade)
    var healthEvents: [HealthEvent] = []

    init(
        id: String = UUID().uuidString,
        filename: String,
        fileURL: URL,
        documentType: DocumentType = .unknown,
        processingStatus: ProcessingStatus = .processing,
        thumbnailData: Data? = nil,
        ocrText: String? = nil,
        uploadedAt: Date = .now,
        remoteId: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.fileURL = fileURL
        self.documentType = documentType
        self.processingStatus = processingStatus
        self.thumbnailData = thumbnailData
        self.ocrText = ocrText
        self.uploadedAt = uploadedAt
        self.remoteId = remoteId
    }
}

enum DocumentType: String, Codable, CaseIterable {
    case labResult = "lab_result"
    case radiology = "radiology"
    case dischargeSummary = "discharge_summary"
    case clinicalNote = "clinical_note"
    case insurance = "insurance"
    case prescription = "prescription"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .labResult: "Lab Result"
        case .radiology: "Radiology"
        case .dischargeSummary: "Discharge Summary"
        case .clinicalNote: "Clinical Note"
        case .insurance: "Insurance / EOB"
        case .prescription: "Prescription"
        case .unknown: "Document"
        }
    }
}

enum ProcessingStatus: String, Codable {
    case processing
    case complete
    case failed
}

extension HealthDocument {
    /// Returns the file URL resolved against the current app support directory.
    /// The stored `fileURL` contains an absolute path whose container UUID can change
    /// after iOS updates or device restores. Re-deriving from just the filename
    /// ensures the path is always valid as long as the file exists.
    var resolvedFileURL: URL {
        let dir = URL.applicationSupportDirectory.appending(path: "documents", directoryHint: .isDirectory)
        return dir.appending(path: fileURL.lastPathComponent)
    }
}
