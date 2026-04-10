import Foundation

// MARK: - API Models

struct DocumentUploadResponse: Decodable, Sendable {
    let documentId: String
}

struct DocumentAPIModel: Decodable, Sendable {
    let id: String
    let filename: String
    let status: String
    let documentType: String?
    let mimeType: String?
    let fileSize: Int?
    let createdAt: String
}

struct DocumentStatusAPIModel: Decodable, Sendable {
    let documentId: String
    let status: String
    let documentType: String?
    let errorMessage: String?
}

struct DocumentDetailAPIModel: Decodable, Sendable {
    let id: String
    let filename: String
    let status: String
    let documentType: String?
    let mimeType: String?
    let fileSize: Int?
    let createdAt: String
    let analysisResult: AnalysisAPIModel?
}

struct AnalysisAPIModel: Decodable, Sendable {
    let summary: String?
    let labValues: [LabValueAPI]
    let diagnoses: [String]
    let medications: [MedicationAPI]
    let keyFindings: [String]
}

struct LabValueAPI: Decodable, Sendable {
    let name: String
    let value: String
    let unit: String?
    let referenceRange: String?
    let isAbnormal: Bool
}

struct MedicationAPI: Decodable, Sendable {
    let name: String
    let dosage: String?
    let frequency: String?

    var displayString: String {
        var parts = [name]
        if let d = dosage, !d.isEmpty { parts.append(d) }
        if let f = frequency, !f.isEmpty { parts.append(f) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Service

actor DocumentService {
    static let shared = DocumentService()
    private let api = APIClient.shared

    func upload(fileURL: URL, ocrText: String, mimeType: String, token: String) async throws -> String {
        let fileData = try Data(contentsOf: fileURL)
        var fields: [String: String] = [:]
        if !ocrText.isEmpty { fields["ocr_text"] = ocrText }
        let response: DocumentUploadResponse = try await api.uploadMultipart(
            "/documents/upload",
            fileData: fileData,
            fileName: fileURL.lastPathComponent,
            mimeType: mimeType,
            fields: fields,
            token: token
        )
        return response.documentId
    }

    func fetchDocuments(token: String) async throws -> [DocumentAPIModel] {
        try await api.request("/documents", token: token)
    }

    func fetchDocument(id: String, token: String) async throws -> DocumentAPIModel {
        try await api.request("/documents/\(id)", token: token)
    }

    func fetchDocumentWithAnalysis(id: String, token: String) async throws -> DocumentDetailAPIModel {
        try await api.request("/documents/\(id)", token: token)
    }

    func pollStatus(id: String, token: String) async throws -> DocumentStatusAPIModel {
        try await api.request("/documents/\(id)/status", token: token)
    }

    func deleteDocument(id: String, token: String) async throws {
        try await api.requestEmpty("/documents/\(id)", method: "DELETE", token: token)
    }

    func retry(id: String, token: String) async throws {
        try await api.requestEmpty("/documents/\(id)/retry", method: "POST", token: token)
    }
}
