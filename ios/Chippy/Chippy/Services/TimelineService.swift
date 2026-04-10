import Foundation

struct HealthEventDTO: Decodable, Identifiable {
    let id: String
    let documentId: String
    let title: String
    let category: String
    let eventDate: Date?
    let summary: String?
    let createdAt: Date
}

actor TimelineService {
    static let shared = TimelineService()

    private let dateDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            // Try ISO8601 with fractional seconds (timestamps)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: str) { return date }
            // Plain date (YYYY-MM-DD from event_date column)
            let plain = DateFormatter()
            plain.dateFormat = "yyyy-MM-dd"
            plain.timeZone = TimeZone(identifier: "UTC")
            if let date = plain.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(),
                debugDescription: "Cannot parse date: \(str)")
        }
        return d
    }()

    func fetchEvents(token: String) async throws -> [HealthEventDTO] {
        var request = URLRequest(url: Constants.baseURL.appendingPathComponent("/timeline"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.invalidResponse
        }
        return try dateDecoder.decode([HealthEventDTO].self, from: data)
    }
}
