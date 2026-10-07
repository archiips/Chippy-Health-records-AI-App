import Foundation

struct ReviewedRecordEvent: Identifiable {
    let id: String
    let documentID: String
    let kind: String
    let date: Date?
    let dateText: String?
    let facts: [RecordFact]
}

enum RecordTimeline {
    static func dateLabel(_ date: Date, monthOnly: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = monthOnly ? "MMMM yyyy" : "MMM d, yyyy"
        return formatter.string(from: date)
    }
    static func events(from facts: [RecordFact], kind: String? = nil, after cutoff: Date? = nil) -> [ReviewedRecordEvent] {
        let eligible = facts.filter { fact in
            fact.isConfirmed && (kind == nil || fact.kind == kind) &&
                (cutoff == nil || (fact.eventDate.map { $0 >= cutoff! } ?? false))
        }
        let groups = Dictionary(grouping: eligible) {
            let day = $0.eventDate.map { String($0.timeIntervalSince1970) } ?? ($0.dateText ?? "undated")
            return "\($0.documentID)|\(day)|\($0.kind)"
        }
        return groups.map { key, values in
            let sorted = values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            let first = sorted[0]
            return ReviewedRecordEvent(id: key, documentID: first.documentID, kind: first.kind,
                date: first.eventDate, dateText: first.dateText, facts: sorted)
        }.sorted {
            if $0.date != $1.date { return ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            return $0.id < $1.id
        }
    }
}
