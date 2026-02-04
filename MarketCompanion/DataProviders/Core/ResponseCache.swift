// ResponseCache.swift
// MarketCompanion
//
// In-memory response cache with TTL to avoid redundant API calls.

import Foundation

actor ResponseCache {
    static let shared = ResponseCache()

    private struct CacheEntry {
        let data: Any
        let expiresAt: Date
    }

    private var cache: [String: CacheEntry] = [:]

    // MARK: - TTL Defaults

    enum CacheTTL {
        static let quote: TimeInterval = 15           // 15 seconds
        static let dailyBars: TimeInterval = 300       // 5 minutes
        static let intradayPrices: TimeInterval = 30   // 30 seconds
        static let marketOverview: TimeInterval = 60   // 1 minute
        static let news: TimeInterval = 300            // 5 minutes
        static let calendar: TimeInterval = 3600       // 1 hour
        static let sectors: TimeInterval = 60          // 1 minute
    }

    // MARK: - Get / Set

    func get<T>(_ key: String) -> T? {
        guard let entry = cache[key] else { return nil }
        if Date() > entry.expiresAt {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.data as? T
    }

    func set<T>(_ key: String, value: T, ttl: TimeInterval) {
        cache[key] = CacheEntry(data: value, expiresAt: Date().addingTimeInterval(ttl))
    }

    // MARK: - Key Builders

    static func quoteKey(symbols: [String]) -> String {
        "quotes:\(symbols.sorted().joined(separator: ","))"
    }

    static func dailyBarsKey(symbol: String, from: Date, to: Date) -> String {
        "dailyBars:\(symbol):\(Int(from.timeIntervalSince1970)):\(Int(to.timeIntervalSince1970))"
    }

    static func intradayKey(symbol: String) -> String {
        "intraday:\(symbol)"
    }

    static func overviewKey() -> String {
        "marketOverview"
    }

    static func newsKey(symbol: String) -> String {
        "news:\(symbol)"
    }

    static func calendarKey(from: Date, to: Date) -> String {
        "calendar:\(Int(from.timeIntervalSince1970)):\(Int(to.timeIntervalSince1970))"
    }

    static func sectorsKey() -> String {
        "sectors"
    }

    // MARK: - Eviction

    func evictAll() {
        cache.removeAll()
    }

    func evict(prefix: String) {
        cache = cache.filter { !$0.key.hasPrefix(prefix) }
    }

    func evictExpired() {
        let now = Date()
        cache = cache.filter { $0.value.expiresAt > now }
    }

    var entryCount: Int {
        cache.count
    }
}
