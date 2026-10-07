import SwiftUI
import SwiftData
import PDFKit

struct FactEditorView: View {
    let document: HealthDocument
    let pageNumber: Int
    let fact: RecordFact?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var kind: String
    @State private var name: String
    @State private var value: String
    @State private var unit: String
    @State private var range: String
    @State private var date: String
    @State private var quote: String
    @State private var checked = false
    @State private var showOriginal = false
    @State private var deleting = false
    @State private var errorMessage: String?

    init(document: HealthDocument, pageNumber: Int, fact: RecordFact?) {
        self.document = document; self.pageNumber = pageNumber; self.fact = fact
        _kind = State(initialValue: fact?.kind ?? "finding")
        _name = State(initialValue: fact?.name ?? "")
        _value = State(initialValue: fact?.value ?? "")
        _unit = State(initialValue: fact?.unit ?? "")
        _range = State(initialValue: fact?.referenceRange ?? "")
        _date = State(initialValue: fact?.dateText ?? "")
        _quote = State(initialValue: fact?.quote ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Verify against page \(pageNumber)") {
                    Button("Open Original Page") { showOriginal = true }
                    DisclosureGroup("Read Page Text") {
                        Text(document.pages.first { $0.number == pageNumber }?.text ?? "")
                            .font(.subheadline).textSelection(.enabled)
                    }
                    TextField("Quote from original", text: $quote, axis: .vertical)
                        .accessibilityIdentifier("fact-source-quote")
                }
                Section("Recorded Fact") {
                    if let original = fact?.originalCandidate, fact?.wasCorrected == true {
                        Text("Before your corrections: \(original.name), \(original.value) \(original.unit ?? ""), date \(original.dateText ?? "not recorded"). Evidence: \(original.quote)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Picker("Category", selection: $kind) {
                        ForEach(["lab", "medication", "diagnosis", "finding", "visit"], id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    TextField("Name", text: $name)
                    TextField("Value as recorded", text: $value)
                    TextField("Unit, if recorded", text: $unit)
                    TextField("Reference range, if recorded", text: $range)
                    TextField("Date as recorded (YYYY-MM-DD if known)", text: $date)
                    Text("Leave missing fields blank. Other date formats remain visible without a guessed timeline date. Historical medication mentions do not imply current use.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("I checked these fields against the original page", isOn: $checked)
                    Button("Save Reviewed Fact") { save() }
                        .disabled(!checked || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if fact != nil { Button("Remove Fact…", role: .destructive) { deleting = true } }
                }
            }.navigationTitle("Review Fact")
                .toolbar { Button("Cancel") { dismiss() } }
                .sheet(isPresented: $showOriginal) {
                    NavigationStack {
                        OriginalPageView(url: document.resolvedFileURL, pageNumber: pageNumber)
                            .toolbar { Button("Done") { showOriginal = false } }
                    }
                }
                .alert("Remove this fact?", isPresented: $deleting) {
                    Button("Remove", role: .destructive) {
                        guard let fact else { return }
                        do { context.delete(fact); try context.save(); dismiss() }
                        catch { context.rollback(); errorMessage = error.localizedDescription }
                    }
                    Button("Cancel", role: .cancel) {}
                }
                .alert("Could not save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                    Button("OK") { errorMessage = nil }
                } message: { Text(errorMessage ?? "") }
        }
    }

    private func save() {
        do {
            let target = fact ?? RecordFact(documentID: document.id, pageNumber: pageNumber, kind: kind, name: name, value: value,
                unit: unit.isEmpty ? nil : unit, referenceRange: range.isEmpty ? nil : range, quote: quote,
                dateText: date.isEmpty ? nil : date)
            target.confirm(FactCandidate(kind: kind, name: name, value: value, unit: unit.isEmpty ? nil : unit,
                referenceRange: range.isEmpty ? nil : range, dateText: date.isEmpty ? nil : date, quote: quote))
            target.document = document
            context.insert(target)
            try context.save()
            dismiss()
        } catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}
