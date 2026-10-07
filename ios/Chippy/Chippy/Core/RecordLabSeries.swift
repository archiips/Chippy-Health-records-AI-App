import Foundation

enum RecordLabSeries {
    static func groups(_ facts: [RecordFact]) -> [String: [RecordFact]] {
        Dictionary(grouping: facts.filter {
            $0.isConfirmed && $0.kind == "lab" && $0.eventDate != nil && Double($0.value) != nil &&
                !($0.unit?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }) { "\($0.name) (\($0.unit ?? ""))" }
    }
}
