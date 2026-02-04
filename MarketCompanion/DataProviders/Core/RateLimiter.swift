// RateLimiter.swift
// MarketCompanion
//
// Per-provider rate limiting with sliding window and burst protection.

import Foundation

// MARK: - Rate Limit Configuration

struct RateLimitConfig: Sendable {
    let requestsPerSecond: Double
    let requestsPerMinute: Int
    let requestsPerDay: Int?
    let burstLimit: Int

    static let unlimited = RateLimitConfig(requestsPerSecond: .infinity, requestsPerMinute: .max, requestsPerDay: nil, burstLimit: .max)

    static func perSecond(_ rps: Double, perMinute: Int, perDay: Int? = nil) -> RateLimitConfig {
        RateLimitConfig(requestsPerSecond: rps, requestsPerMinute: perMinute, requestsPerDay: perDay, burstLimit: max(1, Int(rps * 2)))
    }
}

// MARK: - Rate Limiter

actor RateLimiter {
    private let config: RateLimitConfig
    private let providerID: ProviderID

    private var requestTimestamps: [Date] = []
    private var dailyCount: Int = 0
    private var dailyResetDate: Date

    private var rateLimitedUntil: Date?

    init(provider: ProviderID, config: RateLimitConfig) {
        self.providerID = provider
        self.config = config
        self.dailyResetDate = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
    }

    // MARK: - Check & Acquire

    var isRateLimited: Bool {
        if let until = rateLimitedUntil, Date() < until {
            return true
        }
        return false
    }

    func waitIfNeeded() async throws {
        // Check if externally rate-limited (from 429 response)
        if let until = rateLimitedUntil {
            if Date() < until {
                let waitTime = until.timeIntervalSinceNow
                if waitTime > 30 {
                    throw MarketDataError.rateLimited
                }
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
            rateLimitedUntil = nil
        }

        // Reset daily counter if new day
        let now = Date()
        if now >= dailyResetDate {
            dailyCount = 0
            dailyResetDate = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
        }

        // Check daily limit
        if let dailyLimit = config.requestsPerDay, dailyCount >= dailyLimit {
            throw MarketDataError.rateLimited
        }

        // Clean old timestamps (keep last minute)
        let oneMinuteAgo = now.addingTimeInterval(-60)
        requestTimestamps.removeAll { $0 < oneMinuteAgo }

        // Check per-minute limit
        if requestTimestamps.count >= config.requestsPerMinute {
            let oldestInWindow = requestTimestamps.first!
            let waitTime = 60 - now.timeIntervalSince(oldestInWindow)
            if waitTime > 0 {
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }

        // Check per-second limit (sliding window)
        let oneSecondAgo = now.addingTimeInterval(-1)
        let recentCount = requestTimestamps.filter { $0 >= oneSecondAgo }.count
        if Double(recentCount) >= config.requestsPerSecond {
            let waitTime = 1.0 / config.requestsPerSecond
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }

        // Record this request
        requestTimestamps.append(Date())
        dailyCount += 1
    }

    // MARK: - External Rate Limit Signal

    func markRateLimited(retryAfterSeconds: Int? = nil) {
        let delay = TimeInterval(retryAfterSeconds ?? 60)
        rateLimitedUntil = Date().addingTimeInterval(delay)
    }

    // MARK: - Statistics

    var dailyRequestCount: Int { dailyCount }

    var remainingDailyRequests: Int? {
        guard let limit = config.requestsPerDay else { return nil }
        return max(0, limit - dailyCount)
    }

    func reset() {
        requestTimestamps.removeAll()
        dailyCount = 0
        rateLimitedUntil = nil
    }
}

// MARK: - Default Rate Limits Per Provider

extension RateLimitConfig {
    static func forProvider(_ id: ProviderID) -> RateLimitConfig {
        switch id {
        case .mock:
            return .unlimited
        case .finnhub:
            // Finnhub free: 60 calls/min, 30 calls/sec
            return .perSecond(30, perMinute: 60)
        case .alpaca:
            // Alpaca: 200 calls/min
            return .perSecond(3, perMinute: 200)
        case .alphaVantage:
            // Alpha Vantage free: 5/min, 500/day; premium varies
            return .perSecond(0.08, perMinute: 5, perDay: 500)
        case .marketStack:
            // MarketStack free: 100/month → ~3/day; paid varies
            return .perSecond(1, perMinute: 10, perDay: 1000)
        case .eodhd:
            // EODHD: per-symbol cost, ~100k calls/day on All World
            return .perSecond(5, perMinute: 100, perDay: 100_000)
        case .massive:
            // Massive (Polygon rebrand): 5/min free, paid unlimited
            return .perSecond(5, perMinute: 300)
        case .dataBento:
            // DataBento: usage-based, no hard rate limit documented
            return .perSecond(10, perMinute: 300)
        case .thetaData:
            // ThetaData: varies by plan
            return .perSecond(5, perMinute: 100)
        }
    }
}
