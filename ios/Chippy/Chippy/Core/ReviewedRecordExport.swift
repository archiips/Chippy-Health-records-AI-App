import Foundation

enum ReviewedRecordExport {
    static func text(facts: [RecordFact], filenames: [String: String]) -> String {
        let confirmed = facts.filter(\.isConfirmed).sorted {
            ($0.eventDate ?? .distantPast) > ($1.eventDate ?? .distantPast)
        }
        let entries = confirmed.map { fact in
            let unit = fact.unit.map { " \($0)" } ?? ""
            let range = fact.referenceRange.map { "\nReference range as recorded: \($0)" } ?? (fact.kind == "lab" ? "\nReference range not recorded" : "")
            let correction = fact.wasCorrected ? "\nUser corrected this record. Initial value: \(fact.originalValue). Initial date: \(fact.originalCandidate?.dateText ?? "Not recorded"). Initial evidence: \(fact.originalCandidate?.quote ?? "Not retained")" : ""
            return "\(fact.name): \(fact.value)\(unit)\(range)\nDate as recorded: \(fact.dateText ?? "Not recorded")\nSource: \(filenames[fact.documentID] ?? "Document"), page \(fact.pageNumber)\nQuoted evidence: \(fact.quote)\(correction)"
        }
        return "Chippy — reviewed record summary\nHistorical record mentions; medication mentions do not establish current use.\nFor informational purposes only. Consult your doctor.\n\n" + entries.joined(separator: "\n\n")
    }
}
