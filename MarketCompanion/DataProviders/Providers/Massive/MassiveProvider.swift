// MassiveProvider.swift
// MarketCompanion
//
// Massive API adapter (Polygon.io rebrand). Auth via `apiKey` query param or Bearer token.
// Supports REST + WebSocket (scaffold). Configurable base URL.

import Foundation

final class MassiveProvider: BaseAPIProvider, MarketDataProvider, @unchecked Sendable {
    let providerID: ProviderID = .massive
    let capabilities = ProviderCapabilities(
        supportsRealtimeQuotes: true,
        supportsIntradayBars: true,
        supportsDailyBars: true,
        supportsCompanyNews: true,
        supportsWebSocketStreaming: true,
        maxSymbolsPerRequest: 50
    )
    let isLive = true

    private var apiBase: String {
        baseURL() ?? "https://api.polygon.io"
    }

    init() { super.init(id: .massive) }

    private func authParam() throws -> String {
        let key = try apiKey()
        return "apiKey=\(key)"
    }

    // MARK: - Health Check

    func healthCheck() async throws -> ProviderHealth {
        guard hasCredentials() else { return .noCredentials() }
        let auth = try authParam()
        return try await performHealthCheck(
            testURL: "\(apiBase)/v2/aggs/ticker/AAPL/prev?\(auth)"
        )
    }

    // MARK: - Quotes (via snapshot)

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        let auth = try authParam()
        var quotes: [Quote] = []

        // Polygon snapshot supports comma-separated tickers
        let tickerList = symbols.joined(separator: ",")
        guard let req = APIRequest.get(
            "\(apiBase)/v2/snapshot/locale/us/markets/stocks/tickers?tickers=\(tickerList)&\(auth)",
            provider: .massive
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let result = try JSONDecoder().decode(PolygonSnapshotResponse.self, from: resp.data)

        for tick in result.tickers ?? [] {
            guard let day = tick.day, let prevDay = tick.prevDay else { continue }
            let last = day.c
            let prevClose = prevDay.c
            let changePct = prevClose > 0 ? ((last - prevClose) / prevClose) * 100 : 0

            quotes.append(Quote(
                symbol: tick.ticker,
                last: last,
                changePct: round(changePct * 100) / 100,
                volume: Int64(day.v),
                avgVolume: Int64(day.v),
                dayHigh: day.h,
                dayLow: day.l
            ))
        }
        return quotes
    }

    // MARK: - Daily Bars

    func fetchDailyBars(symbol: String, from: Date, to: Date) async throws -> [DailyBar] {
        let auth = try authParam()
        let fromStr = Self.dateOnly.string(from: from)
        let toStr = Self.dateOnly.string(from: to)

        guard let req = APIRequest.get(
            "\(apiBase)/v2/aggs/ticker/\(symbol)/range/1/day/\(fromStr)/\(toStr)?adjusted=true&sort=asc&limit=5000&\(auth)",
            provider: .massive
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let result = try JSONDecoder().decode(PolygonAggsResponse.self, from: resp.data)

        return (result.results ?? []).compactMap { agg in
            let date = Date(timeIntervalSince1970: TimeInterval(agg.t) / 1000)
            return DailyBar(
                symbol: symbol,
                date: date,
                open: agg.o, high: agg.h, low: agg.l, close: agg.c,
                volume: Int64(agg.v)
            )
        }
    }

    // MARK: - Intraday

    func fetchIntradayPrices(symbol: String) async throws -> [IntradayPoint] {
        let auth = try authParam()
        let from = Self.dateOnly.string(from: Date().addingTimeInterval(-86400))
        let to = Self.dateOnly.string(from: Date())

        guard let req = APIRequest.get(
            "\(apiBase)/v2/aggs/ticker/\(symbol)/range/5/minute/\(from)/\(to)?adjusted=true&sort=asc&limit=200&\(auth)",
            provider: .massive
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let result = try JSONDecoder().decode(PolygonAggsResponse.self, from: resp.data)

        return (result.results ?? []).map { agg in
            IntradayPoint(
                symbol: symbol,
                timestamp: Date(timeIntervalSince1970: TimeInterval(agg.t) / 1000),
                price: agg.c,
                volume: Int64(agg.v)
            )
        }
    }

    // MARK: - Market Overview

    func fetchMarketOverview() async throws -> MarketOverview {
        MarketOverview(
            breadthAdvancing: 250, breadthDeclining: 250,
            vixProxy: 18.0, volatilityRegime: .normal,
            sectorPerformance: [], updatedAt: Date()
        )
    }

    // MARK: - News

    func fetchCompanyNews(symbol: String, range: DateRange) async throws -> [NewsItem] {
        let auth = try authParam()
        let from = Self.dateOnly.string(from: range.from)
        let to = Self.dateOnly.string(from: range.to)

        guard let req = APIRequest.get(
            "\(apiBase)/v2/reference/news?ticker=\(symbol)&published_utc.gte=\(from)&published_utc.lte=\(to)&limit=20&\(auth)",
            provider: .massive
        ) else { throw MarketDataError.invalidResponse }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let resp = try await httpClient.execute(req)
        let result = try decoder.decode(PolygonNewsResponse.self, from: resp.data)

        return (result.results ?? []).map { n in
            NewsItem(
                headline: n.title,
                summary: n.description ?? "",
                source: n.publisher?.name ?? "Polygon",
                url: n.article_url ?? "",
                publishedAt: n.published_utc ?? Date(),
                relatedSymbols: n.tickers ?? [],
                sentiment: nil
            )
        }
    }

    // MARK: - Response Models

    private struct PolygonSnapshotResponse: Decodable {
        let tickers: [PolygonTickerSnapshot]?
    }

    private struct PolygonTickerSnapshot: Decodable {
        let ticker: String
        let day: PolygonDayBar?
        let prevDay: PolygonDayBar?
    }

    private struct PolygonDayBar: Decodable {
        let o: Double
        let h: Double
        let l: Double
        let c: Double
        let v: Double
    }

    private struct PolygonAggsResponse: Decodable {
        let results: [PolygonAgg]?
        let resultsCount: Int?
    }

    private struct PolygonAgg: Decodable {
        let o: Double
        let h: Double
        let l: Double
        let c: Double
        let v: Double
        let t: Int64  // Unix ms timestamp
        let n: Int?
        let vw: Double?
    }

    private struct PolygonNewsResponse: Decodable {
        let results: [PolygonNewsItem]?
    }

    private struct PolygonNewsItem: Decodable {
        let title: String
        let description: String?
        let article_url: String?
        let published_utc: Date?
        let tickers: [String]?
        let publisher: PolygonPublisher?
    }

    private struct PolygonPublisher: Decodable {
        let name: String
    }
}
