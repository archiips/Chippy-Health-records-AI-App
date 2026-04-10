import SwiftUI

struct ExplainerView: View {
    let document: HealthDocument
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var displayText: String = ""
    @State private var isStreaming: Bool = false
    @State private var hasError: Bool = false
    @State private var streamTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Disclaimer banner
                        Label(
                            "For informational purposes only. Not a substitute for professional medical advice.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.lavendorTint, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor.opacity(0.2), lineWidth: 1))

                        if hasError {
                            VStack(spacing: 16) {
                                ContentUnavailableView(
                                    "Explanation Unavailable",
                                    systemImage: "exclamationmark.triangle",
                                    description: Text("Could not generate an explanation. Please try again.")
                                )
                                Button("Try Again") {
                                    Task { await startExplanation() }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else if displayText.isEmpty && !isStreaming {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .controlSize(.large)
                                Spacer()
                            }
                            .padding(.top, 40)
                        } else {
                            HStack(alignment: .bottom, spacing: 4) {
                                Text((try? AttributedString(markdown: displayText, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(displayText))
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .id("explanationText")

                                if isStreaming {
                                    PhaseAnimator([true, false]) { isOn in
                                        RoundedRectangle(cornerRadius: 1)
                                            .frame(width: 2, height: 16)
                                            .foregroundStyle(isOn ? Color.primary : Color.clear)
                                    } animation: { _ in .linear(duration: 0.5) }
                                }
                            }
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                }
                .onChange(of: displayText) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .navigationTitle("Explanation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !displayText.isEmpty && !isStreaming {
                        ShareLink(item: displayText) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .task {
            await startExplanation()
        }
        .onDisappear {
            streamTask?.cancel()
        }
    }

    private func startExplanation() async {
        guard let token = await authManager.validToken(), let remoteId = document.remoteId else {
            hasError = true
            return
        }

        isStreaming = true
        hasError = false
        displayText = ""

        streamTask = Task {
            var request = URLRequest(
                url: Constants.baseURL.appendingPathComponent("/documents/\(remoteId)/explain")
            )
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            for await chunk in await StreamingService.shared.stream(request: request) {
                guard !Task.isCancelled else { break }
                // Detect server-side error payload
                if chunk.hasPrefix("{\"error\":") {
                    hasError = true
                    break
                }
                displayText += chunk
            }

            if displayText.isEmpty && !Task.isCancelled {
                hasError = true
            }
            isStreaming = false
        }

        await streamTask?.value
    }
}
