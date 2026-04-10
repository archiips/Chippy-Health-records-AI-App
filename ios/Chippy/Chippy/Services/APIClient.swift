import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .httpError(_, let message):
            return message
        case .decodingFailed:
            return "Failed to read server response."
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        token: String? = nil
    ) async throws -> T {
        var request = URLRequest(url: Constants.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            // Try to extract FastAPI's detail field
            let message = (try? decoder.decode(APIErrorBody.self, from: data))?.detail
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.httpError(statusCode: http.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    func requestEmpty(
        _ path: String,
        method: String,
        body: Encodable? = nil,
        token: String? = nil
    ) async throws {
        var request = URLRequest(url: Constants.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        let (_, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode, message: "Request failed")
        }
    }

    func uploadMultipart<T: Decodable>(
        _ path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fields: [String: String] = [:],
        token: String?
    ) async throws -> T {
        let boundary = UUID().uuidString
        var req = URLRequest(url: Constants.baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        var body = Data()
        let nl = "\r\n"
        for (key, value) in fields {
            body += "--\(boundary)\(nl)Content-Disposition: form-data; name=\"\(key)\"\(nl)\(nl)\(value)\(nl)".data(using: .utf8)!
        }
        body += "--\(boundary)\(nl)Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\(nl)Content-Type: \(mimeType)\(nl)\(nl)".data(using: .utf8)!
        body += fileData
        body += "\(nl)--\(boundary)--\(nl)".data(using: .utf8)!
        req.httpBody = body

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? decoder.decode(APIErrorBody.self, from: data))?.detail
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.httpError(statusCode: http.statusCode, message: message)
        }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decodingFailed(error) }
    }
}

private struct APIErrorBody: Decodable, Sendable {
    let detail: String
}
