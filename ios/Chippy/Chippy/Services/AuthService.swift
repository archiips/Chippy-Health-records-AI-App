import Foundation

struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let email: String
}

actor AuthService {
    static let shared = AuthService()

    private let api = APIClient.shared

    func register(email: String, password: String) async throws -> TokenResponse {
        try await api.request(
            "/auth/register",
            method: "POST",
            body: AuthBody(email: email, password: password)
        )
    }

    func login(email: String, password: String) async throws -> TokenResponse {
        try await api.request(
            "/auth/login",
            method: "POST",
            body: AuthBody(email: email, password: password)
        )
    }

    func refreshToken(_ refreshToken: String) async throws -> TokenResponse {
        try await api.request(
            "/auth/refresh",
            method: "POST",
            body: RefreshBody(refreshToken: refreshToken)
        )
    }

    func logout(token: String) async throws {
        try await api.requestEmpty("/auth/logout", method: "POST", token: token)
    }
}

private struct AuthBody: Encodable, Sendable {
    let email: String
    let password: String
}

private struct RefreshBody: Encodable, Sendable {
    let refreshToken: String
}
