import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var context
    @Environment(AuthManager.self) private var authManager

    @State private var viewModel = ChatViewModel()
    @State private var showClearConfirmation = false

    private let starterQuestions = [
        "What medications am I on?",
        "When was my last lab work?",
        "Summarize my recent visits.",
        "Do I have any abnormal lab results?",
    ]

    var body: some View {
        Group {
            if viewModel.messages.isEmpty && !viewModel.isStreaming {
                emptyState
            } else {
                messageList
            }
        }
        .navigationTitle("Chat")
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) {
            inputBar
        }
        .task {
            viewModel.loadHistory(context: context)
        }
        .confirmationDialog("Clear chat history?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) {
                Task { await viewModel.clearHistory(authManager: authManager, context: context) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all messages.")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                Image(systemName: "stethoscope")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Ask about your health records")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("I can answer questions about your uploaded documents — lab results, diagnoses, medications, and more.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 10) {
                    ForEach(starterQuestions, id: \.self) { question in
                        Button {
                            viewModel.inputText = question
                            Task { await viewModel.sendMessage(authManager: authManager, context: context) }
                        } label: {
                            Text(question)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.lavendorTint, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal)
                Spacer(minLength: 40)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(message: message, isStreaming: false)
                            .id(message.id)
                    }
                    if viewModel.isStreaming {
                        ChatBubble(streamingText: viewModel.streamingText)
                            .id("streaming")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation { proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom) }
            }
            .onChange(of: viewModel.streamingText) {
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") { viewModel.errorMessage = nil }
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.85))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Divider()
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Ask about your records…", text: $viewModel.inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.lavendorTint, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
                    .disabled(viewModel.isStreaming)
                    .accessibilityLabel("Message input")

                if viewModel.isStreaming {
                    Button("Stop", systemImage: "stop.circle.fill") {
                        viewModel.cancelStreaming()
                    }
                    .font(.title2)
                    .foregroundStyle(.red)
                    .labelStyle(.iconOnly)
                } else {
                    let canSend = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Button("Send", systemImage: "arrow.up.circle.fill") {
                        Task { await viewModel.sendMessage(authManager: authManager, context: context) }
                    }
                    .font(.title2)
                    .foregroundStyle(canSend ? .blue : .secondary)
                    .labelStyle(.iconOnly)
                    .disabled(!canSend)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if !viewModel.messages.isEmpty {
                Button("Clear", systemImage: "trash") {
                    showClearConfirmation = true
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Chat bubble

private struct ChatBubble: View {
    var message: ChatMessage? = nil
    var streamingText: String? = nil
    var isStreaming: Bool = false

    private var isUser: Bool { message?.role == .user }
    private var displayText: String {
        if let msg = message { return msg.content }
        return streamingText ?? ""
    }
    private var isStreamingBubble: Bool { message == nil }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 6) {
                if isUser { Spacer(minLength: 60) }

                VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                    HStack(alignment: .bottom, spacing: 4) {
                        if !displayText.isEmpty || isStreamingBubble {
                            Group {
                                if isUser {
                                    Text(displayText.isEmpty ? " " : displayText)
                                } else {
                                    Text(displayText.isEmpty ? AttributedString(" ") : (try? AttributedString(markdown: displayText, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(displayText))
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(isUser ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                isUser ? Color.accentColor : Color.lavendorCard,
                                in: RoundedRectangle(cornerRadius: 18)
                            )
                        }

                        if isStreamingBubble {
                            PhaseAnimator([true, false]) { isOn in
                                RoundedRectangle(cornerRadius: 1)
                                    .frame(width: 2, height: 14)
                                    .foregroundStyle(isOn ? Color.primary : Color.clear)
                            } animation: { _ in .linear(duration: 0.5) }
                        }
                    }

                    if !isUser && !isStreamingBubble {
                        Text("Not medical advice. Consult your doctor.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }

                if !isUser { Spacer(minLength: 60) }
            }
        }
        .accessibilityElement(children: isStreamingBubble ? .ignore : .combine)
        .accessibilityLabel(isStreamingBubble ? "Assistant is responding" : "\(isUser ? "You" : "Assistant"): \(displayText)")
        .transition(.asymmetric(
            insertion: .move(edge: isUser ? .trailing : .leading).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.spring(duration: 0.3), value: displayText)
    }
}
