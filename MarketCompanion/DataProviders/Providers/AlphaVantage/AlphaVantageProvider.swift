// AlphaVantageProvider.swift
// MarketCompanion
//
// Alpha Vantage API adapter. API key via query param `apikey`.
// Free tier: 5 calls/min, 500/day. Must cache aggressively.

import Foundation

final class AlphaVantageProvider: BaseAPIProvider, MarketDataProvider, @unchecked Sendable {
    let providerID: ProviderID = .alphaVantage
    let capabilities = ProviderCapabilities(
        supportsRealtimeQuotes: true,
        supportsIntradayBars: true,
        supportsDailyBars: true,
        maxSymbolsPerRequest: 1
    )
    let isLive = true

    private let base = "https://www.alphavantage.co/query"

    init() { super.init(id: .alphaVantage) }

    func healthCheck() async throws -> ProviderHealth {
        guard hasCredentials() else { return .noCredentials() }
        let key = try apiKey()
        return try await performHealthCheck(
            testURL: "\(base)?function=GLOBAL_QUOTE&symbol=AAPL&apikey=\(key)"
        )
    }

    // MARK: - Quotes (one at a time)

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        let key = try apiKey()
        var quotes: [Quote] = []

        for symbol in symbols {
            guard let req = APIRequest.get(
                "\(base)?function=GLOBAL_QUOTE&symbol=\(symbol)&apikey=\(key)",
                provider: .alphaVantage
            ) else { continue }

            let resp = try await httpClient.execute(req)
            let result = try JSONDecoder().decode(AVGlobalQuoteResponse.self, from: resp.data)

            guard let gq = result.globalQuote, let last = Double(gq.price) else { continue }
            let changePct = Double(gq.changePercent.replacingOccurrences(of: "%", with: "")) ?? 0
            let volume = Int64(gq.volume) ?? 0
            let high = Double(gq.high) ?? last
            let low = Double(gq.low) ?? last

            quotes.append(Quote(
                symbol: symbol, last: last, changePct: changePct,
                volume: volume, avgVolume: volume,
                dayHigh: high, dayLow: low
            ))
        }
        return quotes
    }

    // MARK: - Daily Bars

    func fetchDailyBars(symbol: String, from: Date, to: Date) async throws -> [DailyBar] {
        let key = try apiKey()
        guard let req = APIRequest.get(
            "\(base)?function=TIME_SERIES_DAILY&symbol=\(symbol)&outputsize=compact&apikey=\(key)",
            provider: .alphaVantage
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        guard let json = try JSONSerialization.jsonObject(with: resp.data) as? [String: Any],
              let timeSeries = json["Time Series (Daily)"] as? [String: [String: String]] else {
            return []
        }

        let df = Self.dateOnly
        return timeSeries.compactMap { dateStr, values in
            guard let date = df.date(from: dateStr),
                  date >= from && date <= to,
                  let o = Double(values["1. open"] ?? ""),
                  let h = Double(values["2. high"] ?? ""),
                  let l = Double(values["3. low"] ?? ""),
                  let c = Double(values["4. close"] ?? ""),
                  let v = Int64(values["5. volume"] ?? "") else { return nil }
            return DailyBar(symbol: symbol, date: date, open: o, high: h, low: l, close: c, volume: v)
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Intraday

    func fetchIntradayPrices(symbol: String) async throws -> [IntradayPoint] {
        let key = try apiKey()
        guard let req = APIRequest.get(
            "\(base)?function=TIME_SERIES_INTRADAY&symbol=\(symbol)&interval=5min&outputsize=compact&apikey=\(key)",
            provider: .alphaVantage
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        guard let json = try JSONSerialization.jsonObject(with: resp.data) as? [String: Any],
              let timeSeries = json["Time Series (5min)"] as? [String: [String: String]] else {
            return []
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")

        return timeSeries.compactMap { dateStr, values in
            guard let ts = df.date(from: dateStr),
                  let c = Double(values["4. close"] ?? ""),
                  let v = Int64(values["5. volume"] ?? "") else { return nil }
            return IntradayPoint(symbol: symbol, timestamp: ts, price: c, volume: v)
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

    // MARK: - Response Models

    private struct AVGlobalQuoteResponse: Decodable {
        let globalQuote: AVGlobalQuote?

        enum CodingKeys: String, CodingKey {
            case globalQuote = "Global Quote"
        }
    }

    private struct AVGlobalQuote: Decodable {
        let symbol: String
        let price: String
        let high: String
        let low: String
        let volume: String
        let changePercent: String

        enum CodingKeys: String, CodingKey {
            case symbol = "01. symbol"
            case price = "05. price"
            case high = "03. high"
            case low = "04. low"
            case volume = "06. volume"
            case changePercent = "10. change percent"
        }
    }
}
