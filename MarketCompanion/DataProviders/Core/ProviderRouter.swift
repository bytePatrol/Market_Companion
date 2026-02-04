// ProviderRouter.swift
// MarketCompanion
//
// Routes data requests to the best available provider.
// Implements primary/fallback selection, capability routing, caching, rate limiting.

import Foundation

// MARK: - Data Mode

enum DataMode: String, Codable {
    case demo = "Demo"
    case live = "Live"
}

// MARK: - Provider Router

final class ProviderRouter: MarketDataProvider, @unchecked Sendable {
    let providerID: ProviderID = .mock // Router itself doesn't have an ID used externally
    let capabilities = ProviderCapabilities.full
    let isLive: Bool

    private let registry: ProviderRegistry
    private let cache: ResponseCache
    private let retryPolicy: RetryPolicy

    // User-selected providers (persisted via UserDefaults)
    private(set) var primaryProviderID: ProviderID {
        didSet { UserDefaults.standard.set(primaryProviderID.rawValue, forKey: "primaryProviderID") }
    }
    private(set) var fallbackProviderID: ProviderID? {
        didSet { UserDefaults.standard.set(fallbackProviderID?.rawValue, forKey: "fallbackProviderID") }
    }
    private(set) var dataMode: DataMode {
        didSet { UserDefaults.standard.set(dataMode.rawValue, forKey: "dataMode") }
    }

    var displayName: String {
        if dataMode == .demo { return "Demo Data" }
        return registry.provider(for: primaryProviderID)?.displayName ?? "Unknown"
    }

    init(
        registry: ProviderRegistry = .shared,
        cache: ResponseCache = .shared,
        retryPolicy: RetryPolicy = .default
    ) {
        self.registry = registry
        self.cache = cache
        self.retryPolicy = retryPolicy

        // Load persisted selections
        let savedPrimary = UserDefaults.standard.string(forKey: "primaryProviderID")
            .flatMap { ProviderID(rawValue: $0) }
        let savedFallback = UserDefaults.standard.string(forKey: "fallbackProviderID")
            .flatMap { ProviderID(rawValue: $0) }
        let savedMode = UserDefaults.standard.string(forKey: "dataMode")
            .flatMap { DataMode(rawValue: $0) }

        self.primaryProviderID = savedPrimary ?? .mock
        self.fallbackProviderID = savedFallback
        self.dataMode = savedMode ?? .demo
        self.isLive = (savedMode ?? .demo) == .live
    }

    // MARK: - Configuration

    func setPrimary(_ id: ProviderID) {
        primaryProviderID = id
    }

    func setFallback(_ id: ProviderID?) {
        fallbackProviderID = id
    }

    func setDataMode(_ mode: DataMode) {
        dataMode = mode
    }

    // MARK: - Provider Resolution

    private var effectiveProviderIDs: [ProviderID] {
        if dataMode == .demo {
            return [.mock]
        }
        var ids = [primaryProviderID]
        if let fallback = fallbackProviderID, fallback != primaryProviderID {
            ids.append(fallback)
        }
        // Always fall back to mock as last resort
        if !ids.contains(.mock) {
            ids.append(.mock)
        }
        return ids
    }

    private func resolveProvider(
        needing capability: KeyPath<ProviderCapabilities, Bool>? = nil
    ) -> [(MarketDataProvider, RateLimiter)] {
        return effectiveProviderIDs.compactMap { id in
            guard let provider = registry.provider(for: id),
                  let limiter = registry.rateLimiter(for: id) else { return nil }
            if let cap = capability, !provider.capabilities[keyPath: cap] {
                return nil
            }
            return (provider, limiter)
        }
    }

    // MARK: - Routing Helper

    private func route<T>(
        capability: KeyPath<ProviderCapabilities, Bool>? = nil,
        cacheKey: String? = nil,
        cacheTTL: TimeInterval = 0,
        operation: (MarketDataProvider) async throws -> T
    ) async throws -> T {
        // Check cache first
        if let key = cacheKey, cacheTTL > 0 {
            if let cached: T = await cache.get(key) {
                return cached
            }
        }

        let candidates = resolveProvider(needing: capability)
        guard !candidates.isEmpty else {
            throw MarketDataError.providerUnavailable
        }

        var lastError: Error?

        for (provider, limiter) in candidates {
            do {
                try await limiter.waitIfNeeded()

                let result = try await retryPolicy.execute {
                    try await operation(provider)
                }

                // Cache the result
                if let key = cacheKey, cacheTTL > 0 {
                    await cache.set(key, value: result, ttl: cacheTTL)
                }

                return result
            } catch let error as MarketDataError where error == .rateLimited {
                await limiter.markRateLimited()
                lastError = error
                continue // Try next provider
            } catch let error as MarketDataError where error.isRetryable {
                lastError = error
                continue // Try next provider
            } catch {
                lastError = error
                // Non-retryable error: still try fallback
                continue
            }
        }

        throw lastError ?? MarketDataError.providerUnavailable
    }

    // MARK: - Protocol Implementation

    func healthCheck() async throws -> ProviderHealth {
        guard let provider = registry.provider(for: primaryProviderID) else {
            return .error("Provider not found")
        }
        return try await provider.healthCheck()
    }

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        try await route(
            capability: \.supportsRealtimeQuotes,
            cacheKey: ResponseCache.quoteKey(symbols: symbols),
            cacheTTL: ResponseCache.CacheTTL.quote
        ) { provider in
            try await provider.fetchQuotes(symbols: symbols)
        }
    }

    func fetchDailyBars(symbol: String, from: Date, to: Date) async throws -> [DailyBar] {
        try await route(
            capability: \.supportsDailyBars,
            cacheKey: ResponseCache.dailyBarsKey(symbol: symbol, from: from, to: to),
            cacheTTL: ResponseCache.CacheTTL.dailyBars
        ) { provider in
            try await provider.fetchDailyBars(symbol: symbol, from: from, to: to)
        }
    }

    func fetchMarketOverview() async throws -> MarketOverview {
        try await route(
            cacheKey: ResponseCache.overviewKey(),
            cacheTTL: ResponseCache.CacheTTL.marketOverview
        ) { provider in
            try await provider.fetchMarketOverview()
        }
    }

    func fetchIntradayPrices(symbol: String) async throws -> [IntradayPoint] {
        try await route(
            capability: \.supportsIntradayBars,
            cacheKey: ResponseCache.intradayKey(symbol: symbol),
            cacheTTL: ResponseCache.CacheTTL.intradayPrices
        ) { provider in
            try await provider.fetchIntradayPrices(symbol: symbol)
        }
    }

    func fetchCandles(symbol: String, range: DateRange, interval: CandleInterval) async throws -> [Candle] {
        try await route(capability: \.supportsIntradayBars) { provider in
            try await provider.fetchCandles(symbol: symbol, range: range, interval: interval)
        }
    }

    func fetchCompanyNews(symbol: String, range: DateRange) async throws -> [NewsItem] {
        try await route(
            capability: \.supportsCompanyNews,
            cacheKey: ResponseCache.newsKey(symbol: symbol),
            cacheTTL: ResponseCache.CacheTTL.news
        ) { provider in
            try await provider.fetchCompanyNews(symbol: symbol, range: range)
        }
    }

    func fetchCalendar(range: DateRange) async throws -> [CalendarEvent] {
        try await route(
            capability: \.supportsEarningsCalendar,
            cacheKey: ResponseCache.calendarKey(from: range.from, to: range.to),
            cacheTTL: ResponseCache.CacheTTL.calendar
        ) { provider in
            try await provider.fetchCalendar(range: range)
        }
    }

    func fetchMarketSectorsSnapshot() async throws -> [SectorSnapshot] {
        try await route(
            cacheKey: ResponseCache.sectorsKey(),
            cacheTTL: ResponseCache.CacheTTL.sectors
        ) { provider in
            try await provider.fetchMarketSectorsSnapshot()
        }
    }

    // MARK: - Diagnostics

    func runDiagnostics() async -> [(ProviderID, ProviderHealth)] {
        var results: [(ProviderID, ProviderHealth)] = []
        for id in ProviderID.allCases {
            guard let provider = registry.provider(for: id) else { continue }
            do {
                let health = try await provider.healthCheck()
                results.append((id, health))
            } catch {
                results.append((id, .error(error.localizedDescription)))
            }
        }
        return results
    }
}

// MARK: - Equatable helper for MarketDataError

extension MarketDataError: Equatable {
    static func == (lhs: MarketDataError, rhs: MarketDataError) -> Bool {
        switch (lhs, rhs) {
        case (.noAPIKey, .noAPIKey): return true
        case (.rateLimited, .rateLimited): return true
        case (.invalidResponse, .invalidResponse): return true
        case (.providerUnavailable, .providerUnavailable): return true
        case (.authenticationFailed, .authenticationFailed): return true
        case (.networkError(let a), .networkError(let b)): return a == b
        case (.symbolNotFound(let a), .symbolNotFound(let b)): return a == b
        case (.decodingError(let a), .decodingError(let b)): return a == b
        default: return false
        }
    }
}
