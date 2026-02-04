// MarketStackProvider.swift
// MarketCompanion
//
// MarketStack API adapter. Auth via `access_key` query param.
// Free tier: 100 requests/mo. Supports EOD, intraday (paid), tickers.

import Foundation

final class MarketStackProvider: BaseAPIProvider, MarketDataProvider, @unchecked Sendable {
    let providerID: ProviderID = .marketStack
    let capabilities = ProviderCapabilities(
        supportsRealtimeQuotes: true,
        supportsIntradayBars: true,
        supportsDailyBars: true
    )
    let isLive = true

    private let base = "https://api.marketstack.com/v1"

    init() { super.init(id: .marketStack) }

    // MARK: - Health Check

    func healthCheck() async throws -> ProviderHealth {
        guard hasCredentials() else { return .noCredentials() }
        let key = try apiKey()
        return try await performHealthCheck(
            testURL: "\(base)/eod/latest?access_key=\(key)&symbols=AAPL&limit=1"
        )
    }

    // MARK: - Quotes (via EOD latest)

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        let key = try apiKey()
        let symbolList = symbols.joined(separator: ",")
        guard let req = APIRequest.get(
            "\(base)/eod/latest?access_key=\(key)&symbols=\(symbolList)",
            provider: .marketStack
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let result = try JSONDecoder().decode(MSEodResponse.self, from: resp.data)

        return (result.data ?? []).compactMap { eod in
            guard let last = eod.close else { return nil }
            let prev = eod.open ?? last
            let changePct = prev > 0 ? ((last - prev) / prev) * 100 : 0
            return Quote(
                symbol: eod.symbol,
                last: last,
                changePct: round(changePct * 100) / 100,
                volume: Int64(eod.volume ?? 0),
                avgVolume: Int64(eod.volume ?? 0),
                dayHigh: eod.high ?? last,
                dayLow: eod.low ?? last
            )
        }
    }

    // MARK: - Daily Bars

    func fetchDailyBars(symbol: String, from: Date, to: Date) async throws -> [DailyBar] {
        let key = try apiKey()
        let fromStr = Self.dateOnly.string(from: from)
        let toStr = Self.dateOnly.string(from: to)

        guard let req = APIRequest.get(
            "\(base)/eod?access_key=\(key)&symbols=\(symbol)&date_from=\(fromStr)&date_to=\(toStr)&limit=1000",
            provider: .marketStack
        ) else { throw MarketDataError.invalidResponse }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let resp = try await httpClient.execute(req)
        let result = try decoder.decode(MSEodResponse.self, from: resp.data)

        return (result.data ?? []).compactMap { eod in
            guard let date = eod.date,
                  let o = eod.open, let h = eod.high,
                  let l = eod.low, let c = eod.close else { return nil }
            return DailyBar(
                symbol: symbol,
                date: date,
                open: o, high: h, low: l, close: c,
                volume: Int64(eod.volume ?? 0)
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Intraday

    func fetchIntradayPrices(symbol: String) async throws -> [IntradayPoint] {
        let key = try apiKey()
        guard let req = APIRequest.get(
            "\(base)/intraday?access_key=\(key)&symbols=\(symbol)&interval=5min&limit=100",
            provider: .marketStack
        ) else { throw MarketDataError.invalidResponse }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let resp = try await httpClient.execute(req)
        let result = try decoder.decode(MSIntradayResponse.self, from: resp.data)

        return (result.data ?? []).compactMap { point in
            guard let ts = point.date, let price = point.last else { return nil }
            return IntradayPoint(
                symbol: symbol,
                timestamp: ts,
                price: price,
                volume: Int64(point.volume ?? 0)
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

    // MARK: - Response Models

    private struct MSEodResponse: Decodable {
        let data: [MSEodItem]?
    }

    private struct MSEodItem: Decodable {
        let open: Double?
        let high: Double?
        let low: Double?
        let close: Double?
        let volume: Double?
        let symbol: String
        let date: Date?
    }

    private struct MSIntradayResponse: Decodable {
        let data: [MSIntradayItem]?
    }

    private struct MSIntradayItem: Decodable {
        let open: Double?
        let high: Double?
        let low: Double?
        let last: Double?
        let close: Double?
        let volume: Double?
        let date: Date?
        let symbol: String?
    }
}
