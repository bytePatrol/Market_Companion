// FinnhubProvider.swift
// MarketCompanion
//
// Finnhub.io API adapter. API key auth via query param `token`.
// Free tier: 60 calls/min. Supports quotes, daily candles, news, earnings calendar.

import Foundation

final class FinnhubProvider: BaseAPIProvider, MarketDataProvider, @unchecked Sendable {
    let providerID: ProviderID = .finnhub
    let capabilities = ProviderCapabilities(
        supportsRealtimeQuotes: true,
        supportsIntradayBars: false,
        supportsDailyBars: true,
        supportsCompanyNews: true,
        supportsEarningsCalendar: true,
        supportsWebSocketStreaming: true
    )
    let isLive = true

    private let base = "https://finnhub.io/api/v1"

    init() { super.init(id: .finnhub) }

    // MARK: - Health Check

    func healthCheck() async throws -> ProviderHealth {
        guard hasCredentials() else { return .noCredentials() }
        let key = try apiKey()
        return try await performHealthCheck(testURL: "\(base)/quote?symbol=AAPL&token=\(key)")
    }

    // MARK: - Quotes

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        let key = try apiKey()
        var quotes: [Quote] = []

        for symbol in symbols {
            guard let req = APIRequest.get("\(base)/quote?symbol=\(symbol)&token=\(key)", provider: .finnhub) else { continue }
            let resp = try await httpClient.execute(req)
            let fq = try JSONDecoder().decode(FHQuote.self, from: resp.data)

            guard fq.c > 0 else { continue }
            quotes.append(Quote(
                symbol: symbol,
                last: fq.c,
                changePct: fq.dp,
                volume: Int64(fq.v ?? 0),
                avgVolume: Int64(fq.v ?? 0),
                dayHigh: fq.h,
                dayLow: fq.l
            ))
        }
        return quotes
    }

    // MARK: - Daily Bars

    func fetchDailyBars(symbol: String, from: Date, to: Date) async throws -> [DailyBar] {
        let key = try apiKey()
        let fromEpoch = Int(from.timeIntervalSince1970)
        let toEpoch = Int(to.timeIntervalSince1970)

        guard let req = APIRequest.get(
            "\(base)/stock/candle?symbol=\(symbol)&resolution=D&from=\(fromEpoch)&to=\(toEpoch)&token=\(key)",
            provider: .finnhub
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let candles = try JSONDecoder().decode(FHCandles.self, from: resp.data)

        guard candles.s == "ok", let timestamps = candles.t else { return [] }

        var bars: [DailyBar] = []
        for i in 0..<timestamps.count {
            bars.append(DailyBar(
                symbol: symbol,
                date: Date(timeIntervalSince1970: TimeInterval(timestamps[i])),
                open: candles.o?[i] ?? 0,
                high: candles.h?[i] ?? 0,
                low: candles.l?[i] ?? 0,
                close: candles.c?[i] ?? 0,
                volume: Int64(candles.v?[i] ?? 0)
            ))
        }
        return bars
    }

    // MARK: - Market Overview

    func fetchMarketOverview() async throws -> MarketOverview {
        // Finnhub doesn't have a single overview endpoint; return synthetic data
        return MarketOverview(
            breadthAdvancing: 250, breadthDeclining: 250,
            vixProxy: 18.0, volatilityRegime: .normal,
            sectorPerformance: [], updatedAt: Date()
        )
    }

    // MARK: - Intraday

    func fetchIntradayPrices(symbol: String) async throws -> [IntradayPoint] {
        throw MarketDataError.providerUnavailable
    }

    // MARK: - News

    func fetchCompanyNews(symbol: String, range: DateRange) async throws -> [NewsItem] {
        let key = try apiKey()
        let from = Self.dateOnly.string(from: range.from)
        let to = Self.dateOnly.string(from: range.to)

        guard let req = APIRequest.get(
            "\(base)/company-news?symbol=\(symbol)&from=\(from)&to=\(to)&token=\(key)",
            provider: .finnhub
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let items = try JSONDecoder().decode([FHNewsItem].self, from: resp.data)

        return items.prefix(20).map { n in
            NewsItem(
                headline: n.headline,
                summary: n.summary,
                source: n.source,
                url: n.url,
                publishedAt: Date(timeIntervalSince1970: TimeInterval(n.datetime)),
                relatedSymbols: n.related.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                sentiment: nil
            )
        }
    }

    // MARK: - Calendar

    func fetchCalendar(range: DateRange) async throws -> [CalendarEvent] {
        let key = try apiKey()
        let from = Self.dateOnly.string(from: range.from)
        let to = Self.dateOnly.string(from: range.to)

        guard let req = APIRequest.get(
            "\(base)/calendar/earnings?from=\(from)&to=\(to)&token=\(key)",
            provider: .finnhub
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let cal = try JSONDecoder().decode(FHEarningsCalendar.self, from: resp.data)

        return (cal.earningsCalendar ?? []).compactMap { e in
            guard let date = Self.dateOnly.date(from: e.date) else { return nil }
            return CalendarEvent(
                symbol: e.symbol,
                eventType: "earnings",
                date: date,
                description: "Q\(e.quarter ?? 0) Earnings",
                estimatedEPS: e.epsEstimate,
                actualEPS: e.epsActual
            )
        }
    }

    // MARK: - Response Models

    private struct FHQuote: Decodable {
        let c: Double     // current price
        let d: Double?    // change
        let dp: Double    // percent change
        let h: Double     // high
        let l: Double     // low
        let o: Double?    // open
        let pc: Double?   // previous close
        let t: Int?       // timestamp
        let v: Double?    // volume (Finnhub returns as Double)
    }

    private struct FHCandles: Decodable {
        let c: [Double]?
        let h: [Double]?
        let l: [Double]?
        let o: [Double]?
        let v: [Double]?
        let t: [Int]?
        let s: String     // "ok" or "no_data"
    }

    private struct FHNewsItem: Decodable {
        let category: String
        let datetime: Int
        let headline: String
        let id: Int
        let image: String
        let related: String
        let source: String
        let summary: String
        let url: String
    }

    private struct FHEarningsCalendar: Decodable {
        let earningsCalendar: [FHEarning]?
    }

    private struct FHEarning: Decodable {
        let date: String
        let epsActual: Double?
        let epsEstimate: Double?
        let hour: String?
        let quarter: Int?
        let revenueActual: Double?
        let revenueEstimate: Double?
        let symbol: String
    }
}
