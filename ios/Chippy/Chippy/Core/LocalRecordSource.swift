import Foundation

struct LocalRecordSource: Codable, Identifiable, Sendable {
    let documentID: String
    let pageNumber: Int
    let excerpt: String
    let reviewed: Bool
    var id: String { "\(documentID)-\(pageNumber)-\(excerpt)" }
}

struct LocalRecordAnswer {
    let text: String
    let sources: [LocalRecordSource]
}
