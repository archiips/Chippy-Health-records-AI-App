import Foundation

/// Parses a server-sent events stream and emits text chunks.
actor StreamingService {
    static let shared = StreamingService()
    private init() {}

    /// Returns an `AsyncStream<String>` of decoded text chunks.
    /// Chunks are the raw text content between `data: ` and `\n\n`.
    /// The stream ends when `[DONE]` is received or the request completes.
    func stream(request: URLRequest) -> AsyncStream<String> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        continuation.finish()
                        return
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard payload != "[DONE]" else { break }
                        // Restore newlines that were escaped server-side
                        let text = payload.replacing("\\n", with: "\n")
                        continuation.yield(text)
                    }
                } catch {
                    // Network error or cancellation — just close the stream
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
