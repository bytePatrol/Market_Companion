// BaseProvider.swift
// MarketCompanion
//
// Common base for API-backed providers. Handles keychain access, HTTP, rate limiting.

import Foundation

class BaseAPIProvider: @unchecked Sendable {
    let id: ProviderID
    let httpClient: HTTPClient
    let keychain: KeychainService

    init(id: ProviderID, httpClient: HTTPClient = .shared, keychain: KeychainService = .shared) {
        self.id = id
        self.httpClient = httpClient
        self.keychain = keychain
    }

    // MARK: - Credential Access

    func apiKey() throws -> String {
        guard let key = keychain.readProviderSecret(providerID: id, key: "api_key"), !key.isEmpty else {
            throw MarketDataError.noAPIKey
        }
        return key
    }

    func secret() -> String? {
        keychain.readProviderSecret(providerID: id, key: "api_secret")
    }

    func baseURL() -> String? {
        keychain.readProviderSecret(providerID: id, key: "base_url")
    }

    func hasCredentials() -> Bool {
        (try? apiKey()) != nil
    }

    // MARK: - Health Check Helper

    func performHealthCheck(testURL: String, headers: [String: String] = [:]) async throws -> ProviderHealth {
        guard hasCredentials() else {
            return .noCredentials()
        }
        guard let request = APIRequest.get(testURL, provider: id, headers: headers) else {
            return .error("Invalid URL")
        }
        let start = Date()
        _ = try await httpClient.execute(request)
        let latencyMs = Int(Date().timeIntervalSince(start) * 1000)
        return .healthy(latencyMs: latencyMs)
    }

    // MARK: - Date Formatting

    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func epochToDate(_ epoch: TimeInterval) -> Date {
        Date(timeIntervalSince1970: epoch)
    }
}
