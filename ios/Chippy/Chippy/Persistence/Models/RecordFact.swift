import Foundation
import SwiftData

@Model
final class RecordFact {
    @Attribute(.unique) var id: String
    var documentID: String
    var pageNumber: Int
    var kind: String
    var name: String
    var value: String
    var unit: String?
    var referenceRange: String?
    var dateText: String?
    var quote: String
    var originalValue: String
    var originalCandidateData: Data?
    var isConfirmed: Bool
    var wasCorrected: Bool
    var document: HealthDocument?

    init(documentID: String, pageNumber: Int, kind: String, name: String, value: String,
         unit: String? = nil, referenceRange: String? = nil, quote: String, dateText: String? = nil) {
        self.id = UUID().uuidString
        self.documentID = documentID
        self.pageNumber = pageNumber
        self.kind = kind
        self.name = name
        self.value = value
        self.originalValue = value
        self.originalCandidateData = try? JSONEncoder().encode(FactCandidate(kind: kind, name: name, value: value,
            unit: unit, referenceRange: referenceRange, dateText: dateText, quote: quote))
        self.unit = unit
        self.referenceRange = referenceRange
        self.dateText = dateText
        self.quote = quote
        self.isConfirmed = false
        self.wasCorrected = false
    }

    var originalCandidate: FactCandidate? {
        originalCandidateData.flatMap { try? JSONDecoder().decode(FactCandidate.self, from: $0) }
    }

    func confirm(_ candidate: FactCandidate) {
        wasCorrected = wasCorrected || kind != candidate.kind || name != candidate.name || value != candidate.value ||
            unit != candidate.unit || referenceRange != candidate.referenceRange || dateText != candidate.dateText || quote != candidate.quote
        kind = candidate.kind; name = candidate.name; value = candidate.value
        unit = candidate.unit; referenceRange = candidate.referenceRange; dateText = candidate.dateText
        quote = candidate.quote; isConfirmed = true
    }

    var eventDate: Date? {
        guard let dateText else { return nil }
        let normalized = dateText.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        // Only round-trip explicit, unambiguous forms; locale-dependent numeric dates stay undated.
        for format in ["yyyy-MM-dd", "yyyy/MM/dd", "MMM d, yyyy", "MMMM d, yyyy", "d MMM yyyy", "d MMMM yyyy", "MMM d yyyy", "MMMM d yyyy"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            formatter.isLenient = false
            if let date = formatter.date(from: normalized), formatter.string(from: date).caseInsensitiveCompare(normalized) == .orderedSame { return date }
        }
        return nil
    }
}
