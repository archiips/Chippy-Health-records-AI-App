import SwiftUI
import SwiftData

struct LocalChatView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ChatMessage.createdAt) private var messages: [ChatMessage]
    @Query(sort: \HealthDocument.uploadedAt, order: .reverse) private var documents: [HealthDocument]
    @State private var model = LocalChatViewModel()
    @State private var clearConfirmation = false
    @FocusState private var inputFocused: Bool
    private let starters = ["What medications are mentioned in my records?", "When was my last lab work?", "Summarize my records."]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Label("Your records. On this device.", systemImage: "lock.shield")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if messages.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Image(systemName: "bubble.left.and.text.bubble.right").font(.largeTitle).foregroundStyle(Color.accentColor)
                            Text("Make sense of your records").font(.title2).bold()
                            Text("Find recorded results and medication mentions, with the original page a tap away.").foregroundStyle(.secondary)
                            ForEach(starters, id: \.self) { question in
                                Button { model.send(question, documents: documents, context: context) } label: {
                                    HStack { Text(question).multilineTextAlignment(.leading); Spacer(); Image(systemName: "arrow.up.left") }
                                        .font(.subheadline).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.lavendorTint, in: RoundedRectangle(cornerRadius: 16))
                                }.buttonStyle(.plain).disabled(model.isResponding)
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
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("All Records") { model.selectedDocumentID = nil }
                    ForEach(documents) { doc in Button(doc.filename) { model.selectedDocumentID = doc.id } }
                } label: {
                    Label(model.selectedDocumentID.flatMap { id in documents.first { $0.id == id }?.filename } ?? "All Records", systemImage: "doc.text.magnifyingglass")
                        .lineLimit(1)
                }.accessibilityLabel("Choose chat records")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear Chat", systemImage: "trash") { clearConfirmation = true }.disabled(messages.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
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
