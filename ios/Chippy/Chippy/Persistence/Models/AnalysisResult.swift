import Foundation
import SwiftData

@Model
final class AnalysisResult {
    @Attribute(.unique) var id: String
    var documentId: String
    var summary: String?
    var explainerText: String?
    var documentDate: Date?
    var providerName: String?
    var diagnoses: [String]
    var medications: [String]
    var labValues: Data      // JSON-encoded [LabValue]
    var keyFindings: [String]
    var createdAt: Date

    var document: HealthDocument?

    init(
        id: String = UUID().uuidString,
        documentId: String,
        summary: String? = nil,
        explainerText: String? = nil,
        documentDate: Date? = nil,
        providerName: String? = nil,
        diagnoses: [String] = [],
        medications: [String] = [],
        labValues: Data = Data(),
        keyFindings: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.documentId = documentId
        self.summary = summary
        self.explainerText = explainerText
        self.documentDate = documentDate
        self.providerName = providerName
        self.diagnoses = diagnoses
        self.medications = medications
        self.labValues = labValues
        self.keyFindings = keyFindings
        self.createdAt = createdAt
    }
}

struct LabValue: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var value: String
    var unit: String?
    var referenceRange: String?
    var isAbnormal: Bool
}

extension AnalysisResult {
    var decodedLabValues: [LabValue] {
        (try? JSONDecoder().decode([LabValue].self, from: labValues)) ?? []
    }

    /// True if the analysis contains at least some extracted content.
    var hasContent: Bool {
        let hasText = summary?.isEmpty == false
        let hasItems = !diagnoses.isEmpty || !medications.isEmpty || !keyFindings.isEmpty || !decodedLabValues.isEmpty
        return hasText || hasItems
    }
}
