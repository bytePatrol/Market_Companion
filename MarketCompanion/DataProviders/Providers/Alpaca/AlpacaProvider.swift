// AlpacaProvider.swift
// MarketCompanion
//
// Alpaca Markets API adapter. Header-based auth with APCA-API-KEY-ID + APCA-API-SECRET-KEY.
// Market data via data.alpaca.markets. Supports quotes, bars (intraday + daily), news.

import Foundation

final class AlpacaProvider: BaseAPIProvider, MarketDataProvider, @unchecked Sendable {
    let providerID: ProviderID = .alpaca
    let capabilities = ProviderCapabilities(
        supportsRealtimeQuotes: true,
        supportsIntradayBars: true,
        supportsDailyBars: true,
        supportsCompanyNews: true,
        supportsWebSocketStreaming: true,
        maxSymbolsPerRequest: 100
    )
    let isLive = true

    private let dataBase = "https://data.alpaca.markets/v2"

    init() { super.init(id: .alpaca) }

    private func authHeaders() throws -> [String: String] {
        let key = try apiKey()
        let sec = secret() ?? ""
        return [
            "APCA-API-KEY-ID": key,
            "APCA-API-SECRET-KEY": sec
        ]
    }

    // MARK: - Health Check

    func healthCheck() async throws -> ProviderHealth {
        guard hasCredentials() else { return .noCredentials() }
        let headers = try authHeaders()
        return try await performHealthCheck(
            testURL: "\(dataBase)/stocks/AAPL/quotes/latest",
            headers: headers
        )
    }

    // MARK: - Quotes

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        let headers = try authHeaders()
        let symbolList = symbols.joined(separator: ",")
        guard let req = APIRequest.get(
            "\(dataBase)/stocks/snapshots?symbols=\(symbolList)",
            provider: .alpaca,
            headers: headers
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let snapshots = try JSONDecoder().decode([String: AlpacaSnapshot].self, from: resp.data)

        return snapshots.compactMap { symbol, snap in
            guard let trade = snap.latestTrade, let bar = snap.dailyBar else { return nil }
            let prevClose = snap.prevDailyBar?.c ?? bar.o
            let changePct = prevClose > 0 ? ((trade.p - prevClose) / prevClose) * 100 : 0

            return Quote(
                symbol: symbol,
                last: trade.p,
                changePct: round(changePct * 100) / 100,
                volume: Int64(bar.v),
                avgVolume: Int64(bar.v),
                dayHigh: bar.h,
                dayLow: bar.l
            )
        }
    }

    // MARK: - Daily Bars

    func fetchDailyBars(symbol: String, from: Date, to: Date) async throws -> [DailyBar] {
        let headers = try authHeaders()
        let fromStr = Self.dateOnly.string(from: from)
        let toStr = Self.dateOnly.string(from: to)

        guard let req = APIRequest.get(
            "\(dataBase)/stocks/\(symbol)/bars?timeframe=1Day&start=\(fromStr)&end=\(toStr)&limit=1000",
            provider: .alpaca,
            headers: headers
        ) else { throw MarketDataError.invalidResponse }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let resp = try await httpClient.execute(req)
        let result = try decoder.decode(AlpacaBarsResponse.self, from: resp.data)

        return (result.bars ?? []).map { bar in
            DailyBar(
                symbol: symbol,
                date: bar.t,
                open: bar.o,
                high: bar.h,
                low: bar.l,
                close: bar.c,
                volume: Int64(bar.v)
            )
        }
    }

    // MARK: - Intraday

    func fetchIntradayPrices(symbol: String) async throws -> [IntradayPoint] {
        let headers = try authHeaders()
        let from = Self.iso8601.string(from: Date().addingTimeInterval(-28800)) // 8 hours back

        guard let req = APIRequest.get(
            "\(dataBase)/stocks/\(symbol)/bars?timeframe=5Min&start=\(from)&limit=100",
            provider: .alpaca,
            headers: headers
        ) else { throw MarketDataError.invalidResponse }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let resp = try await httpClient.execute(req)
        let result = try decoder.decode(AlpacaBarsResponse.self, from: resp.data)

        return (result.bars ?? []).map { bar in
            IntradayPoint(symbol: symbol, timestamp: bar.t, price: bar.c, volume: Int64(bar.v))
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
        let headers = try authHeaders()
        let from = Self.iso8601.string(from: range.from)
        let to = Self.iso8601.string(from: range.to)

        guard let req = APIRequest.get(
            "\(dataBase.replacingOccurrences(of: "/v2", with: ""))/v1beta1/news?symbols=\(symbol)&start=\(from)&end=\(to)&limit=20",
            provider: .alpaca,
            headers: headers
        ) else { throw MarketDataError.invalidResponse }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let resp = try await httpClient.execute(req)
        let news = try decoder.decode(AlpacaNewsResponse.self, from: resp.data)

        return (news.news ?? []).map { n in
            NewsItem(
                headline: n.headline,
                summary: n.summary ?? "",
                source: n.source,
                url: n.url,
                publishedAt: n.created_at ?? Date(),
                relatedSymbols: n.symbols ?? [],
                sentiment: nil
            )
        }
    }

    // MARK: - Response Models

    private struct AlpacaSnapshot: Decodable {
        let latestTrade: AlpacaTrade?
        let dailyBar: AlpacaBar?
        let prevDailyBar: AlpacaBar?
    }

    private struct AlpacaTrade: Decodable {
        let p: Double  // price
        let s: Int?    // size
        let t: String? // timestamp
    }

    private struct AlpacaBar: Decodable {
        let o: Double
        let h: Double
        let l: Double
        let c: Double
        let v: Double
        let t: Date?
    }

    private struct AlpacaBarsResponse: Decodable {
        let bars: [AlpacaBarItem]?
        let next_page_token: String?
    }

    private struct AlpacaBarItem: Decodable {
        let o: Double
        let h: Double
        let l: Double
        let c: Double
        let v: Double
        let t: Date
        let n: Int?
        let vw: Double?
    }

    private struct AlpacaNewsResponse: Decodable {
        let news: [AlpacaNewsItem]?
    }

    private struct AlpacaNewsItem: Decodable {
        let headline: String
        let summary: String?
        let source: String
        let url: String
        let created_at: Date?
        let symbols: [String]?
    }
}
