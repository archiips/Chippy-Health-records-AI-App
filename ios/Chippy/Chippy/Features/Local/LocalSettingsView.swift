import SwiftUI
import SwiftData
import VisionKit

struct LocalSettingsView: View {
    @Environment(ProcessingPreferences.self) private var preferences
    @Environment(\.modelContext) private var context
    @AppStorage("faceIDEnabled") private var lockEnabled = true
    @State private var consent = false
    @State private var deleting = false
    @State private var deletingLegacy = false
    @State private var hasLegacyFiles = LegacyCacheCleanup().hasLegacyFiles
    @State private var errorMessage: String?
    var body: some View {
        Form {
            Section("Processing") {
                LabeledContent("Mode", value: "On this device")
                Text("Apple on-device AI suggests facts when available. You confirm them against the source. Unsupported devices can import, search, and review manually.")
                Button("Use Cloud Mode…") { consent = true }
            }
            Section("Security") { Toggle("Device Authentication Lock", isOn: $lockEnabled) }
            Section("Local Data") {
                Text("Records are stored locally with device file protection and excluded from backup. Keep a copy of your originals elsewhere.")
                Button("Delete Local Records…", role: .destructive) { deleting = true }
            }
            if hasLegacyFiles {
                Section("Older Build Cache") {
                    Text("The older build used a shared cache without account ownership. It is kept out of both modes. Re-import originals from your copies or recover cloud records by signing in. You can explicitly remove the old cache here.")
                    Button("Remove Older Build Cache…", role: .destructive) { deletingLegacy = true }
                }
            }
            Text("For informational purposes only. Consult your doctor.").font(.footnote)
        }.navigationTitle("Settings")
            .sheet(isPresented: $consent) {
                NavigationStack {
                    Form {
                        Text("Cloud mode sends newly imported originals, OCR text, and questions to the Chippy server. Google Gemini processes extraction and answers; Supabase stores records and chats, and the configured vector store stores retrieval data. Local records are not transferred automatically.")
                        Text("Use only synthetic records until a deployed server, provider privacy terms, access controls, and deletion behavior have been verified. This development build uses a local server address.")
                        Button("Allow Cloud Processing and Continue") { preferences.enterCloud(); consent = false }
                        Button("Keep Using This Device", role: .cancel) { consent = false }
                    }.navigationTitle("Cloud Data Permission")
                }
            }
            .alert("Delete all local records?", isPresented: $deleting) {
                Button("Delete", role: .destructive) {
                    LocalRecordLifecycle.shared.invalidatePendingWork()
                    do {
                        try LocalDocumentFiles().removeAll()
                        try context.delete(model: ChatMessage.self)
                        try context.delete(model: RecordFact.self)
                        try context.delete(model: HealthDocument.self)
                        try context.save()
                    } catch { context.rollback(); errorMessage = error.localizedDescription }
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This removes local originals, source text, reviewed facts, and chat history. Cloud records are separate.") }
            .alert("Deletion failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .alert("Remove the older shared cache?", isPresented: $deletingLegacy) {
                Button("Remove Cache", role: .destructive) {
                    do { try LegacyCacheCleanup().remove(); hasLegacyFiles = false }
                    catch { errorMessage = error.localizedDescription }
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This removes the previous build’s local originals and shared database for all accounts on this device. New local records and account-specific cloud caches stay intact. Make sure you have copies of those originals first.") }
    }
}
