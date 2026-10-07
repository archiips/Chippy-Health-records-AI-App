import SwiftUI
import SwiftData

struct LocalChatView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ChatMessage.createdAt) private var messages: [ChatMessage]
    @Query(sort: \HealthDocument.uploadedAt, order: .reverse) private var documents: [HealthDocument]
    @State private var model = LocalChatViewModel()
    @State private var clearConfirmation = false
    @FocusState private var inputFocused: Bool
    private let starters = [("Latest labs", "When was my last lab work?"), ("Medications", "What medications are mentioned in my records?"), ("Summary", "Summarize my records.")]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if messages.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Image(systemName: "bubble.left.and.text.bubble.right").font(.largeTitle).foregroundStyle(Color.accentColor)
                            Text(documents.isEmpty ? "Start with a record" : "Ask about your records").font(.title2).bold()
                            Text(documents.isEmpty ? "Add a medical document from Records, then ask about a test result or medication." : "Try a question below, or type a test or medication name. Open the cited page to check the original.").foregroundStyle(.secondary)
                            if documents.isEmpty {
                                NavigationLink("Add a photo or scan", destination: LocalLibraryView())
                                    .buttonStyle(.borderedProminent)
                            }
                        }.padding(.vertical, 24)
                    }
                    ForEach(messages) { message in
                        LocalChatMessageView(message: message, documents: documents).id(message.id)
                    }
                    if model.isResponding { ProgressView("Finding source pages…").id("response") }
                    if let error = model.errorMessage { Text(error).foregroundStyle(.red).font(.subheadline) }
                }.padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .onChange(of: messages.count) { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            .onChange(of: model.isResponding) { _, responding in
                proxy.scrollTo(responding ? "response" : messages.last?.id, anchor: .bottom)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear Chat", systemImage: "trash") { clearConfirmation = true }.disabled(messages.isEmpty)
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Menu {
                        Button("All Records") { model.cancel(); model.selectedDocumentID = nil }
                        ForEach(documents) { doc in Button(doc.filename) { model.cancel(); model.selectedDocumentID = doc.id } }
                    } label: {
                        Label(model.selectedDocumentID.flatMap { id in documents.first { $0.id == id }?.filename } ?? "All Records", systemImage: "doc.text.magnifyingglass")
                            .font(.subheadline).lineLimit(1)
                    }.accessibilityLabel("Choose chat records")
                    Spacer()
                    Text("\(documents.count) records").font(.caption).foregroundStyle(.secondary)
                }
                Text("Offline record lookup").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("How Chat Works") {
                    Text(LocalChatQueryService.modeDescription + " Replies show recorded facts or short OCR excerpts, with links to the originals. Review imported fields for clearer answers. Chat does not diagnose, recommend treatment, or upload your records.")
                        .font(.caption).foregroundStyle(.secondary)
                }.font(.caption)
            }.padding(.horizontal, 20).padding(.vertical, 10).background(.bar)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(starters, id: \.0) { starter in
                            Button(starter.0) { inputFocused = false; model.send(starter.1, documents: documents, context: context) }
                                .buttonStyle(.bordered).font(.caption).disabled(model.isResponding || documents.isEmpty)
                        }
                    }
                }.scrollIndicators(.hidden)
                Text("Answers quote your records. Not medical advice.").font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Ask about your records…", text: $model.input, axis: .vertical)
                        .lineLimit(1...5).padding(12).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                        .accessibilityIdentifier("local-chat-input").focused($inputFocused).onSubmit(send)
                    if model.isResponding {
                        Button("Stop", systemImage: "stop.circle.fill") { model.cancel() }.labelStyle(.iconOnly).font(.title).frame(minWidth: 44, minHeight: 44)
                    } else {
                        Button("Send", systemImage: "arrow.up.circle.fill", action: send)
                            .labelStyle(.iconOnly).font(.title).frame(minWidth: 44, minHeight: 44)
                            .disabled(model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }.padding(.horizontal, 20).padding(.vertical, 10).background(.bar)
        }
        .confirmationDialog("Clear chat history?", isPresented: $clearConfirmation, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { model.clear(context: context) }
        } message: { Text("This removes the conversation from this device. Your records stay intact.") }
        .onDisappear { model.cancel() }
        .onChange(of: documents.map(\.id)) {
            if let id = model.selectedDocumentID, !documents.contains(where: { $0.id == id }) { model.selectedDocumentID = nil }
        }
    }
    private func send() {
        inputFocused = false
        model.send(documents: documents, context: context)
    }
}
