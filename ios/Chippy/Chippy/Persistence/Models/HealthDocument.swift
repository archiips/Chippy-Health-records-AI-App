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
    var pageTextData: Data?

    @Relationship(deleteRule: .cascade, inverse: \RecordFact.document)
    var recordFacts: [RecordFact] = []

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
        let parent = fileURL.deletingLastPathComponent()
        if parent.deletingLastPathComponent().lastPathComponent == "cloud-record-files" {
            return URL.applicationSupportDirectory.appending(path: "cloud-record-files", directoryHint: .isDirectory)
                .appending(path: parent.lastPathComponent, directoryHint: .isDirectory).appending(path: fileURL.lastPathComponent)
        }
        let folder = fileURL.deletingLastPathComponent().lastPathComponent == "local-record-files" ? "local-record-files" : "documents"
        let dir = URL.applicationSupportDirectory.appending(path: folder, directoryHint: .isDirectory)
        return dir.appending(path: fileURL.lastPathComponent)
    }

    var pages: [DocumentPage] {
        get { pageTextData.flatMap { try? JSONDecoder().decode([DocumentPage].self, from: $0) } ?? [] }
        set { pageTextData = try? JSONEncoder().encode(newValue) }
    }
}
