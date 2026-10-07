import SwiftUI
import SwiftData

struct RecordDetailsEditor: View {
    let document: HealthDocument
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var type: DocumentType
    @State private var errorMessage: String?
    init(document: HealthDocument) {
        self.document = document
        _name = State(initialValue: document.filename)
        _type = State(initialValue: document.documentType)
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Record name", text: $name)
                Picker("Document type", selection: $type) { ForEach(DocumentType.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                Text("Choose a name and type that help you find this record. The original stays unchanged.").font(.subheadline).foregroundStyle(.secondary)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }.navigationTitle("Record Details").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
    private func save() {
        document.filename = name.trimmingCharacters(in: .whitespacesAndNewlines)
        document.documentType = type
        do { try context.save(); dismiss() }
        catch { context.rollback(); errorMessage = "Record details could not be saved." }
    }
}
