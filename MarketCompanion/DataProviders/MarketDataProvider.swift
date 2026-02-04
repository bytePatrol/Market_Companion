// MarketDataProvider.swift
// MarketCompanion
//
// Pluggable protocol for fetching market data.
// Defines the unified domain layer that all providers conform to.

import Foundation

// MARK: - Provider Identity

enum ProviderID: String, Codable, CaseIterable, Identifiable, Hashable {
    case mock = "mock"
    case finnhub = "finnhub"
    case alpaca = "alpaca"
    case alphaVantage = "alpha_vantage"
    case marketStack = "market_stack"
    case eodhd = "eodhd"
    case massive = "massive"
    case dataBento = "data_bento"
    case thetaData = "theta_data"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mock: return "Demo Data"
        case .finnhub: return "Finnhub"
        case .alpaca: return "Alpaca"
        case .alphaVantage: return "Alpha Vantage"
        case .marketStack: return "MarketStack"
        case .eodhd: return "EODHD"
        case .massive: return "Massive"
        case .dataBento: return "DataBento"
        case .thetaData: return "ThetaData"
        }
    }
}

// MARK: - Provider Capabilities

struct ProviderCapabilities: Sendable {
    var supportsRealtimeQuotes: Bool = false
    var supportsIntradayBars: Bool = false
    var supportsDailyBars: Bool = false
    var supportsCompanyNews: Bool = false
    var supportsEarningsCalendar: Bool = false
    var supportsWebSocketStreaming: Bool = false
    var supportsOptionsData: Bool = false
    var maxSymbolsPerRequest: Int? = nil

    static let none = ProviderCapabilities()

    static let full = ProviderCapabilities(
        supportsRealtimeQuotes: true,
        supportsIntradayBars: true,
        supportsDailyBars: true,
        supportsCompanyNews: true,
        supportsEarningsCalendar: true,
        supportsWebSocketStreaming: true,
        supportsOptionsData: true
    )
}

// MARK: - Provider Health

enum ProviderHealthStatus: String, Sendable {
    case healthy = "Healthy"
    case degraded = "Degraded"
    case unavailable = "Unavailable"
    case noCredentials = "No Credentials"
    case rateLimited = "Rate Limited"
    case error = "Error"
}

struct ProviderHealth: Sendable {
    let status: ProviderHealthStatus
    let latencyMs: Int?
    let message: String?
    let timestamp: Date

    static func healthy(latencyMs: Int) -> ProviderHealth {
        ProviderHealth(status: .healthy, latencyMs: latencyMs, message: nil, timestamp: Date())
    }

    static func error(_ message: String) -> ProviderHealth {
        ProviderHealth(status: .error, latencyMs: nil, message: message, timestamp: Date())
    }

    static func noCredentials() -> ProviderHealth {
        ProviderHealth(status: .noCredentials, latencyMs: nil, message: "API key not configured", timestamp: Date())
    }
}

// MARK: - Domain Models for Extended API

struct DateRange: Sendable {
    let from: Date
    let to: Date

    static func lastDays(_ count: Int) -> DateRange {
        let to = Date()
        let from = Calendar.current.date(byAdding: .day, value: -count, to: to)!
        return DateRange(from: from, to: to)
    }
}

enum CandleInterval: String, Sendable, CaseIterable {
    case oneMinute = "1min"
    case fiveMinutes = "5min"
    case fifteenMinutes = "15min"
    case thirtyMinutes = "30min"
    case oneHour = "1h"
    case fourHours = "4h"
    case daily = "1d"
    case weekly = "1w"
}

struct Candle: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(symbol)-\(timestamp.timeIntervalSince1970)" }
    let symbol: String
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int64
}

struct NewsItem: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(source)-\(publishedAt.timeIntervalSince1970)" }
    let headline: String
    let summary: String
    let source: String
    let url: String
    let publishedAt: Date
    let relatedSymbols: [String]
    let sentiment: String?
}

struct CalendarEvent: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(symbol)-\(eventType)-\(date.timeIntervalSince1970)" }
    let symbol: String
    let eventType: String
    let date: Date
    let description: String
    let estimatedEPS: Double?
    let actualEPS: Double?
}

struct SectorSnapshot: Codable, Identifiable, Hashable, Sendable {
    var id: String { sector }
    let sector: String
    let changePct: Double
    let marketCap: Double?
    let leaderSymbol: String?
    let leaderChangePct: Double?
}

// MARK: - Provider Protocol

protocol MarketDataProvider: Sendable {
    var providerID: ProviderID { get }
    var displayName: String { get }
    var capabilities: ProviderCapabilities { get }
    var isLive: Bool { get }

    func healthCheck() async throws -> ProviderHealth
    func fetchQuotes(symbols: [String]) async throws -> [Quote]
    func fetchDailyBars(symbol: String, from: Date, to: Date) async throws -> [DailyBar]
    func fetchMarketOverview() async throws -> MarketOverview
    func fetchIntradayPrices(symbol: String) async throws -> [IntradayPoint]

    // Extended API (optional — default implementations provided)
    func fetchCandles(symbol: String, range: DateRange, interval: CandleInterval) async throws -> [Candle]
    func fetchCompanyNews(symbol: String, range: DateRange) async throws -> [NewsItem]
    func fetchCalendar(range: DateRange) async throws -> [CalendarEvent]
    func fetchMarketSectorsSnapshot() async throws -> [SectorSnapshot]
}

// Default implementations for optional methods
extension MarketDataProvider {
    var displayName: String { providerID.displayName }

    func fetchCandles(symbol: String, range: DateRange, interval: CandleInterval) async throws -> [Candle] {
        throw MarketDataError.providerUnavailable
    }

    func fetchCompanyNews(symbol: String, range: DateRange) async throws -> [NewsItem] {
        throw MarketDataError.providerUnavailable
    }

    func fetchCalendar(range: DateRange) async throws -> [CalendarEvent] {
        throw MarketDataError.providerUnavailable
    }

    func fetchMarketSectorsSnapshot() async throws -> [SectorSnapshot] {
        throw MarketDataError.providerUnavailable
    }
}

// MARK: - Backward-compatible alias

extension MarketDataProvider {
    var name: String { displayName }
}

// MARK: - Intraday Point

struct IntradayPoint: Codable, Identifiable, Hashable {
    var id: String { "\(symbol)-\(timestamp.timeIntervalSince1970)" }
    var symbol: String
    var timestamp: Date
    var price: Double
    var volume: Int64
}

// MARK: - Provider Errors

enum MarketDataError: LocalizedError {
    case noAPIKey
    case networkError(String)
    case invalidResponse
    case rateLimited
    case symbolNotFound(String)
    case providerUnavailable
    case authenticationFailed
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Add your key in Settings."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .invalidResponse:
            return "Received an invalid response from the data provider."
        case .rateLimited:
            return "Rate limited. Try again in a moment."
        case .symbolNotFound(let symbol):
            return "Symbol '\(symbol)' not found."
        case .providerUnavailable:
            return "The data provider is currently unavailable."
        case .authenticationFailed:
            return "Authentication failed. Check your API key."
        case .decodingError(let msg):
            return "Failed to decode response: \(msg)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .rateLimited, .networkError, .providerUnavailable:
            return true
        case .noAPIKey, .authenticationFailed, .symbolNotFound, .invalidResponse, .decodingError:
            return false
        }
    }
}

