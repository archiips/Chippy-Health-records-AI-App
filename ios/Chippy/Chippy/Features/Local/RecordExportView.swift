import SwiftUI

struct RecordExportView: View {
    let facts: [RecordFact]
    let documents: [HealthDocument]
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String> = []
    @State private var showPreview = false
    private var selected: [RecordFact] { facts.filter { selection.contains($0.id) } }
    var body: some View {
        NavigationStack {
            List {
                Text("Select the reviewed facts to share. Check the preview before sending it to anyone.").font(.subheadline).foregroundStyle(.secondary)
                ForEach(facts) { fact in
                    Toggle(isOn: Binding(get: { selection.contains(fact.id) }, set: {
                        if $0 { selection.insert(fact.id) } else { selection.remove(fact.id) }
                    })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(fact.name): \(fact.value) \(fact.unit ?? "")").font(.subheadline).bold()
                            Text("\(documents.first { $0.id == fact.documentID }?.filename ?? "Document") · page \(fact.pageNumber)").font(.caption).foregroundStyle(.secondary)
                            if fact.kind == "lab" { Text("Recorded range: \(fact.referenceRange ?? "not recorded")").font(.caption).foregroundStyle(.secondary) }
                        }.accessibilityElement(children: .combine)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Review Selected Facts (\(selected.count))") { showPreview = true }
                    .accessibilityIdentifier("review-selected-facts")
                    .buttonStyle(.borderedProminent).frame(maxWidth: .infinity).padding(16).background(.bar)
                    .disabled(selected.isEmpty)
            }
            .navigationTitle("Appointment Summary")
            .toolbar { Button("Done") { dismiss() } }
            .sheet(isPresented: $showPreview) { SelectedRecordExportPreview(facts: selected, documents: documents) }
        }
    }
}
