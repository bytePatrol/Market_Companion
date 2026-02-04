// HTTPClient.swift
// MarketCompanion
//
// Shared HTTP client for all provider adapters.
// Handles request building, response decoding, 429 awareness, and logging.

import Foundation

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

// MARK: - API Request

struct APIRequest {
    let url: URL
    let method: HTTPMethod
    var headers: [String: String] = [:]
    var body: Data? = nil
    let providerID: ProviderID

    static func get(_ urlString: String, provider: ProviderID, headers: [String: String] = [:]) -> APIRequest? {
        guard let url = URL(string: urlString) else { return nil }
        return APIRequest(url: url, method: .get, headers: headers, providerID: provider)
    }
}

// MARK: - API Response

struct APIResponse {
    let data: Data
    let statusCode: Int
    let headers: [AnyHashable: Any]

    var rateLimitRemaining: Int? {
        // Common rate limit headers across providers
        for key in ["X-RateLimit-Remaining", "x-ratelimit-remaining", "X-Ratelimit-Remaining"] {
            if let value = headers[key] as? String, let remaining = Int(value) {
                return remaining
            }
        }
        return nil
    }

    var rateLimitResetTimestamp: Date? {
        for key in ["X-RateLimit-Reset", "x-ratelimit-reset", "X-Ratelimit-Reset"] {
            if let value = headers[key] as? String, let epoch = TimeInterval(value) {
                return Date(timeIntervalSince1970: epoch)
            }
        }
        return nil
    }

    var retryAfterSeconds: Int? {
        if let value = headers["Retry-After"] as? String, let seconds = Int(value) {
            return seconds
        }
        return nil
    }
}

// MARK: - HTTP Client

actor HTTPClient {
    static let shared = HTTPClient()

    private let session: URLSession
    private var requestLog: [RequestLogEntry] = []
    private let maxLogEntries = 200

    struct RequestLogEntry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let provider: ProviderID
        let method: String
        let url: String
        let statusCode: Int?
        let latencyMs: Int
        let error: String?
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "MarketCompanion/1.0"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Execute

    func execute(_ request: APIRequest) async throws -> APIResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let start = Date()

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw MarketDataError.invalidResponse
            }

            let latencyMs = Int(Date().timeIntervalSince(start) * 1000)
            let apiResponse = APIResponse(
                data: data,
                statusCode: httpResponse.statusCode,
                headers: httpResponse.allHeaderFields
            )

            // Log (redact URL query parameters for security)
            logRequest(
                provider: request.providerID,
                method: request.method.rawValue,
                url: redactURL(request.url),
                statusCode: httpResponse.statusCode,
                latencyMs: latencyMs,
                error: nil
            )

            // Handle common HTTP errors
            switch httpResponse.statusCode {
            case 200...299:
                return apiResponse
            case 401, 403:
                throw MarketDataError.authenticationFailed
            case 429:
                throw MarketDataError.rateLimited
            case 404:
                throw MarketDataError.invalidResponse
            default:
                throw MarketDataError.networkError("HTTP \(httpResponse.statusCode)")
            }

        } catch let error as MarketDataError {
            let latencyMs = Int(Date().timeIntervalSince(start) * 1000)
            logRequest(
                provider: request.providerID,
                method: request.method.rawValue,
                url: redactURL(request.url),
                statusCode: nil,
                latencyMs: latencyMs,
                error: error.localizedDescription
            )
            throw error
        } catch {
            let latencyMs = Int(Date().timeIntervalSince(start) * 1000)
            logRequest(
                provider: request.providerID,
                method: request.method.rawValue,
                url: redactURL(request.url),
                statusCode: nil,
                latencyMs: latencyMs,
                error: error.localizedDescription
            )
            throw MarketDataError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Convenience Decode

    func executeAndDecode<T: Decodable>(_ request: APIRequest, as type: T.Type, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        let response = try await execute(request)
        do {
            return try decoder.decode(T.self, from: response.data)
        } catch {
            throw MarketDataError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Request Log

    func getLog() -> [RequestLogEntry] {
        requestLog
    }

    func clearLog() {
        requestLog.removeAll()
    }

    private func logRequest(provider: ProviderID, method: String, url: String, statusCode: Int?, latencyMs: Int, error: String?) {
        let entry = RequestLogEntry(
            timestamp: Date(),
            provider: provider,
            method: method,
            url: url,
            statusCode: statusCode,
            latencyMs: latencyMs,
            error: error
        )
        requestLog.append(entry)
        if requestLog.count > maxLogEntries {
            requestLog.removeFirst(requestLog.count - maxLogEntries)
        }
    }

    private func redactURL(_ url: URL) -> String {
        // Redact API keys and tokens from query parameters
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.host ?? "unknown"
        }
        let sensitiveParams = Set(["apikey", "api_key", "apiKey", "token", "access_key", "secret"])
        components.queryItems = components.queryItems?.map { item in
            if sensitiveParams.contains(item.name.lowercased()) || sensitiveParams.contains(item.name) {
                return URLQueryItem(name: item.name, value: "***REDACTED***")
            }
            return item
        }
        return components.string ?? url.host ?? "unknown"
    }
}
