import SwiftUI

enum RecordKindStyle {
    static let kinds = ["lab", "medication", "diagnosis", "finding", "visit"]
    static func name(_ kind: String) -> String {
        switch kind {
        case "lab": "Lab results"
        case "medication": "Medications"
        case "diagnosis": "Diagnoses"
        case "visit": "Visits"
        default: "Findings"
        }
    }
    static func icon(_ kind: String) -> String {
        switch kind {
        case "lab": "testtube.2"
        case "medication": "pills"
        case "diagnosis": "cross.case"
        case "visit": "stethoscope"
        default: "doc.text.magnifyingglass"
        }
    }
    static func color(_ kind: String) -> Color {
        switch kind {
        case "lab": .purple
        case "medication": .blue
        case "diagnosis": .pink
        case "visit": .teal
        default: .indigo
        }
    }
}
