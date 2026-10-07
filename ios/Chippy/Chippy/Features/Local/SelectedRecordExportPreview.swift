import SwiftUI

struct SelectedRecordExportPreview: View {
    let facts: [RecordFact]
    let documents: [HealthDocument]
    @Environment(\.dismiss) private var dismiss
    private var text: String { ReviewedRecordExport.text(facts: facts, filenames: Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0.filename) })) }
    var body: some View {
        NavigationStack {
            ScrollView { Text(text).font(.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(20) }
                .navigationTitle("Selected Facts")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { ShareLink(item: text) { Label("Share Selected Facts", systemImage: "square.and.arrow.up") } }
                }
        }
    }
}
