import Foundation
import Observation

@Observable
@MainActor
final class AuthManager {
    private(set) var isAuthenticated: Bool = false
    private(set) var accessToken: String?
    private(set) var currentUserId: String?
    private(set) var email: String?

    private let keychain = KeychainService()

    init() {
        restoreSession()
    }

    func signIn(accessToken: String, refreshToken: String, userId: String, email: String = "") {
        keychain.save(token: accessToken, forKey: .accessToken)
        keychain.save(token: refreshToken, forKey: .refreshToken)
        keychain.save(token: userId, forKey: .userId)
        if !email.isEmpty { keychain.save(token: email, forKey: .email) }
        self.accessToken = accessToken
        self.currentUserId = userId
        self.email = email.isEmpty ? nil : email
        self.isAuthenticated = true
    }

    func signOut() {
        keychain.delete(key: .accessToken)
        keychain.delete(key: .refreshToken)
        keychain.delete(key: .userId)
        keychain.delete(key: .email)
        self.accessToken = nil
        self.currentUserId = nil
        self.email = nil
        self.isAuthenticated = false
    }

    func updateTokens(accessToken: String, refreshToken: String) {
        keychain.save(token: accessToken, forKey: .accessToken)
        keychain.save(token: refreshToken, forKey: .refreshToken)
        self.accessToken = accessToken
    }

    /// Returns true if the stored access token is missing or within 60 seconds of expiry.
    var isTokenExpiredOrMissing: Bool {
        guard let token = accessToken else { return true }
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return true }
        var base64 = String(parts[1])
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else { return true }
        return Date().timeIntervalSince1970 >= exp - 60  // refresh 60s before expiry
    }

    /// Returns a valid access token, refreshing first if the current token is expired or close to expiry.
    func validToken() async -> String? {
        if isTokenExpiredOrMissing {
            return await refreshIfNeeded()
        }
        return accessToken
    }

    /// Attempt a token refresh. Returns the new access token, or nil if refresh fails (forces sign-out).
    func refreshIfNeeded() async -> String? {
        guard let storedRefresh = keychain.load(key: .refreshToken) else {
            signOut()
            return nil
        }
        do {
            let response = try await AuthService.shared.refreshToken(storedRefresh)
            updateTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
            return response.accessToken
        } catch {
            signOut()
            return nil
        }
    }

    private func restoreSession() {
        guard
            let token = keychain.load(key: .accessToken),
            let userId = keychain.load(key: .userId)
        else { return }
        self.accessToken = token
        self.currentUserId = userId
        self.email = keychain.load(key: .email)
        self.isAuthenticated = true
    }
}
