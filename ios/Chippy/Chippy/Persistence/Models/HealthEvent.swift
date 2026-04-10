import Foundation
import SwiftData

@Model
final class HealthEvent {
    @Attribute(.unique) var id: String
    var documentId: String
    var title: String
    var category: EventCategory
    var eventDate: Date
    var summary: String?

    var document: HealthDocument?

    init(
        id: String = UUID().uuidString,
        documentId: String,
        title: String,
        category: EventCategory,
        eventDate: Date,
        summary: String? = nil
    ) {
        self.id = id
        self.documentId = documentId
        self.title = title
        self.category = category
        self.eventDate = eventDate
        self.summary = summary
    }
}

enum EventCategory: String, Codable, CaseIterable {
    case diagnosis
    case medication
    case lab
    case procedure
    case visit
    case imaging
    case insurance

    var displayName: String {
        switch self {
        case .diagnosis: "Diagnosis"
        case .medication: "Medication"
        case .lab: "Lab"
        case .procedure: "Procedure"
        case .visit: "Visit"
        case .imaging: "Imaging"
        case .insurance: "Insurance"
        }
    }

    var systemImage: String {
        switch self {
        case .diagnosis: "stethoscope"
        case .medication: "pill"
        case .lab: "testtube.2"
        case .procedure: "scissors"
        case .visit: "calendar"
        case .imaging: "rays"
        case .insurance: "doc.text"
        }
    }
}
