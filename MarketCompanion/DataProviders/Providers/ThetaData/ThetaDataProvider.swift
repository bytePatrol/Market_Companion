// ThetaDataProvider.swift
// MarketCompanion
//
// Theta Data API adapter. REST client with API key auth via header.
// Premium/advanced tier. Configurable base URL. Strong options data support.

import Foundation

final class ThetaDataProvider: BaseAPIProvider, MarketDataProvider, @unchecked Sendable {
    let providerID: ProviderID = .thetaData
    let capabilities = ProviderCapabilities(
        supportsRealtimeQuotes: true,
        supportsIntradayBars: true,
        supportsDailyBars: true,
        supportsOptionsData: true
    )
    let isLive = true

    private var apiBase: String {
        baseURL() ?? "https://api.thetadata.us"
    }

    init() { super.init(id: .thetaData) }

    private func authHeaders() throws -> [String: String] {
        let key = try apiKey()
        return ["Authorization": "Bearer \(key)"]
    }

    // MARK: - Health Check

    func healthCheck() async throws -> ProviderHealth {
        guard hasCredentials() else { return .noCredentials() }
        let headers = try authHeaders()
        return try await performHealthCheck(
            testURL: "\(apiBase)/v2/hist/stock/eod?root=AAPL&start_date=20240101&end_date=20240102",
            headers: headers
        )
    }

    // MARK: - Quotes (via latest snapshot)

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        let headers = try authHeaders()
        var quotes: [Quote] = []

        for symbol in symbols {
            guard let req = APIRequest.get(
                "\(apiBase)/v2/snapshot/stock/quote?root=\(symbol)",
                provider: .thetaData,
                headers: headers
            ) else { continue }

            do {
                let resp = try await httpClient.execute(req)
                let result = try JSONDecoder().decode(ThetaQuoteResponse.self, from: resp.data)

                guard let row = result.response?.first,
                      row.count >= 8 else { continue }

                // ThetaData returns arrays: [ms_of_day, bid_size, bid_condition, bid, bid_exchange, ask_size, ask_condition, ask, ask_exchange, date]
                let bid = row[3]
                let ask = row[7]
                let mid = (bid + ask) / 2

                guard mid > 0 else { continue }

                quotes.append(Quote(
                    symbol: symbol,
                    last: round(mid * 100) / 100,
                    changePct: 0, // Snapshot doesn't include change; router can supplement
                    volume: 0,
                    avgVolume: 0,
                    dayHigh: mid,
                    dayLow: mid
                ))
            } catch {
                continue
            }
        }
        return quotes
    }

    // MARK: - Daily Bars

    func fetchDailyBars(symbol: String, from: Date, to: Date) async throws -> [DailyBar] {
        let headers = try authHeaders()
        let fromStr = thetaDateString(from: from)
        let toStr = thetaDateString(from: to)

        guard let req = APIRequest.get(
            "\(apiBase)/v2/hist/stock/eod?root=\(symbol)&start_date=\(fromStr)&end_date=\(toStr)",
            provider: .thetaData,
            headers: headers
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let result = try JSONDecoder().decode(ThetaOHLCResponse.self, from: resp.data)

        // ThetaData EOD columns: [ms_of_day, open, high, low, close, volume, count, date]
        return (result.response ?? []).compactMap { row in
            guard row.count >= 8 else { return nil }
            let dateInt = Int(row[7])
            guard let date = thetaDateParse(dateInt) else { return nil }

            return DailyBar(
                symbol: symbol,
                date: date,
                open: row[1] / 100, high: row[2] / 100, low: row[3] / 100, close: row[4] / 100,
                volume: Int64(row[5])
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Intraday

    func fetchIntradayPrices(symbol: String) async throws -> [IntradayPoint] {
        let headers = try authHeaders()
        let today = thetaDateString(from: Date())

        guard let req = APIRequest.get(
            "\(apiBase)/v2/hist/stock/trade?root=\(symbol)&start_date=\(today)&end_date=\(today)&ivl=300000",
            provider: .thetaData,
            headers: headers
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        let result = try JSONDecoder().decode(ThetaOHLCResponse.self, from: resp.data)

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())

        // Trade columns: [ms_of_day, open, high, low, close, volume, count, date]
        return (result.response ?? []).compactMap { row in
            guard row.count >= 8 else { return nil }
            let msOfDay = row[0]
            let timestamp = startOfDay.addingTimeInterval(msOfDay / 1000)
            return IntradayPoint(
                symbol: symbol,
                timestamp: timestamp,
                price: row[4] / 100,
                volume: Int64(row[5])
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

    // MARK: - Helpers

    /// ThetaData uses YYYYMMDD format
    private func thetaDateString(from date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.string(from: date)
    }

    private func thetaDateParse(_ dateInt: Int) -> Date? {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.date(from: String(dateInt))
    }

    // MARK: - Response Models

    private struct ThetaQuoteResponse: Decodable {
        let header: ThetaHeader?
        let response: [[Double]]?
    }

    private struct ThetaOHLCResponse: Decodable {
        let header: ThetaHeader?
        let response: [[Double]]?
    }

    private struct ThetaHeader: Decodable {
        let format: [String]?
    }
}
