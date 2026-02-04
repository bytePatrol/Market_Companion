// EODHDProvider.swift
// MarketCompanion
//
// EODHD API adapter. Auth via `api_token` query param.
// Free tier: limited. Paid: EOD, intraday, fundamentals, dividends, news.
// Call-cost awareness: some endpoints cost more API credits.

import Foundation

final class EODHDProvider: BaseAPIProvider, MarketDataProvider, @unchecked Sendable {
    let providerID: ProviderID = .eodhd
    let capabilities = ProviderCapabilities(
        supportsRealtimeQuotes: true,
        supportsIntradayBars: true,
        supportsDailyBars: true,
        supportsCompanyNews: true
    )
    let isLive = true

    private let base = "https://eodhd.com/api"

    init() { super.init(id: .eodhd) }

    // MARK: - Health Check

    func healthCheck() async throws -> ProviderHealth {
        guard hasCredentials() else { return .noCredentials() }
        let key = try apiKey()
        return try await performHealthCheck(
            testURL: "\(base)/real-time/AAPL.US?api_token=\(key)&fmt=json"
        )
    }

    // MARK: - Quotes (real-time endpoint)

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        let key = try apiKey()
        var quotes: [Quote] = []

        for symbol in symbols {
            let ticker = symbol.contains(".") ? symbol : "\(symbol).US"
            guard let req = APIRequest.get(
                "\(base)/real-time/\(ticker)?api_token=\(key)&fmt=json",
                provider: .eodhd
            ) else { continue }

            let resp = try await httpClient.execute(req)
            let rt = try JSONDecoder().decode(EODRealTime.self, from: resp.data)

            guard let last = rt.close ?? rt.previousClose else { continue }
            let prev = rt.previousClose ?? last
            let changePct = prev > 0 ? ((last - prev) / prev) * 100 : 0

            quotes.append(Quote(
                symbol: symbol,
                last: last,
                changePct: round(changePct * 100) / 100,
                volume: Int64(rt.volume ?? 0),
                avgVolume: Int64(rt.volume ?? 0),
                dayHigh: rt.high ?? last,
                dayLow: rt.low ?? last
            ))
        }
        return quotes
    }

    // MARK: - Daily Bars

    func fetchDailyBars(symbol: String, from: Date, to: Date) async throws -> [DailyBar] {
        let key = try apiKey()
        let ticker = symbol.contains(".") ? symbol : "\(symbol).US"
        let fromStr = Self.dateOnly.string(from: from)
        let toStr = Self.dateOnly.string(from: to)

        guard let req = APIRequest.get(
            "\(base)/eod/\(ticker)?api_token=\(key)&from=\(fromStr)&to=\(toStr)&fmt=json",
            provider: .eodhd
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let items = try JSONDecoder().decode([EODBar].self, from: resp.data)

        return items.compactMap { bar in
            guard let date = Self.dateOnly.date(from: bar.date) else { return nil }
            return DailyBar(
                symbol: symbol,
                date: date,
                open: bar.open, high: bar.high, low: bar.low, close: bar.close,
                volume: Int64(bar.volume ?? 0)
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Intraday

    func fetchIntradayPrices(symbol: String) async throws -> [IntradayPoint] {
        let key = try apiKey()
        let ticker = symbol.contains(".") ? symbol : "\(symbol).US"

        guard let req = APIRequest.get(
            "\(base)/intraday/\(ticker)?api_token=\(key)&interval=5m&fmt=json",
            provider: .eodhd
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let items = try JSONDecoder().decode([EODIntradayItem].self, from: resp.data)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")

        return items.compactMap { item in
            guard let ts = df.date(from: item.datetime ?? "") else { return nil }
            return IntradayPoint(
                symbol: symbol,
                timestamp: ts,
                price: item.close,
                volume: Int64(item.volume ?? 0)
            )
        }.sorted { $0.timestamp < $1.timestamp }
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
        let key = try apiKey()
        let ticker = symbol.contains(".") ? symbol : "\(symbol).US"
        let from = Self.dateOnly.string(from: range.from)
        let to = Self.dateOnly.string(from: range.to)

        guard let req = APIRequest.get(
            "\(base)/news?s=\(ticker)&api_token=\(key)&from=\(from)&to=\(to)&limit=20&fmt=json",
            provider: .eodhd
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let items = try JSONDecoder().decode([EODNewsItem].self, from: resp.data)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        df.locale = Locale(identifier: "en_US_POSIX")

        return items.prefix(20).map { n in
            NewsItem(
                headline: n.title,
                summary: n.content?.prefix(300).description ?? "",
                source: n.source ?? "EODHD",
                url: n.link ?? "",
                publishedAt: df.date(from: n.date ?? "") ?? Date(),
                relatedSymbols: n.symbols?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? [symbol],
                sentiment: nil
            )
        }
    }

    // MARK: - Response Models

    private struct EODRealTime: Decodable {
        let close: Double?
        let previousClose: Double?
        let high: Double?
        let low: Double?
        let volume: Double?

        enum CodingKeys: String, CodingKey {
            case close, high, low, volume
            case previousClose = "previousClose"
        }
    }

    private struct EODBar: Decodable {
        let date: String
        let open: Double
        let high: Double
        let low: Double
        let close: Double
        let volume: Double?
    }

    private struct EODIntradayItem: Decodable {
        let datetime: String?
        let open: Double?
        let high: Double?
        let low: Double?
        let close: Double
        let volume: Double?
    }

    private struct EODNewsItem: Decodable {
        let date: String?
        let title: String
        let content: String?
        let link: String?
        let source: String?
        let symbols: String?
    }
}
