// DataBentoProvider.swift
// MarketCompanion
//
// DataBento API adapter. Auth via API key in Authorization header (Basic).
// Premium historical + live streaming (scaffold). Institutional-grade data.

import Foundation

final class DataBentoProvider: BaseAPIProvider, MarketDataProvider, @unchecked Sendable {
    let providerID: ProviderID = .dataBento
    let capabilities = ProviderCapabilities(
        supportsRealtimeQuotes: true,
        supportsIntradayBars: true,
        supportsDailyBars: true,
        supportsWebSocketStreaming: true,
        supportsOptionsData: true
    )
    let isLive = true

    private let base = "https://hist.databento.com/v0"

    init() { super.init(id: .dataBento) }

    private func authHeaders() throws -> [String: String] {
        let key = try apiKey()
        let encoded = Data("\(key):".utf8).base64EncodedString()
        return ["Authorization": "Basic \(encoded)"]
    }

    // MARK: - Health Check

    func healthCheck() async throws -> ProviderHealth {
        guard hasCredentials() else { return .noCredentials() }
        let headers = try authHeaders()
        return try await performHealthCheck(
            testURL: "\(base)/metadata.list_datasets",
            headers: headers
        )
    }

    // MARK: - Quotes (via latest record)

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        let headers = try authHeaders()
        var quotes: [Quote] = []

        for symbol in symbols {
            guard let req = APIRequest.get(
                "\(base)/timeseries.get_range?dataset=XNAS.ITCH&symbols=\(symbol)&schema=ohlcv-1d&limit=2&stype_in=raw_symbol",
                provider: .dataBento,
                headers: headers
            ) else { continue }

            do {
                let resp = try await httpClient.execute(req)
                guard let json = try JSONSerialization.jsonObject(with: resp.data) as? [[String: Any]],
                      let latest = json.last,
                      let close = latest["close"] as? Double else { continue }

                let prev = json.first?["close"] as? Double ?? close
                let high = latest["high"] as? Double ?? close
                let low = latest["low"] as? Double ?? close
                let volume = latest["volume"] as? Int64 ?? 0
                let changePct = prev > 0 ? ((close - prev) / prev) * 100 : 0

                quotes.append(Quote(
                    symbol: symbol,
                    last: close / 1e9,  // DataBento uses fixed-point pricing
                    changePct: round(changePct * 100) / 100,
                    volume: volume,
                    avgVolume: volume,
                    dayHigh: high / 1e9,
                    dayLow: low / 1e9
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
        let fromStr = Self.dateOnly.string(from: from)
        let toStr = Self.dateOnly.string(from: to)

        guard let req = APIRequest.get(
            "\(base)/timeseries.get_range?dataset=XNAS.ITCH&symbols=\(symbol)&schema=ohlcv-1d&start=\(fromStr)&end=\(toStr)&stype_in=raw_symbol",
            provider: .dataBento,
            headers: headers
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        guard let records = try JSONSerialization.jsonObject(with: resp.data) as? [[String: Any]] else {
            return []
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")

        return records.compactMap { record in
            guard let tsNanos = record["ts_event"] as? Int64,
                  let o = record["open"] as? Double,
                  let h = record["high"] as? Double,
                  let l = record["low"] as? Double,
                  let c = record["close"] as? Double,
                  let v = record["volume"] as? Int64 else { return nil }

            let date = Date(timeIntervalSince1970: TimeInterval(tsNanos) / 1e9)
            // DataBento uses fixed-point pricing (divide by 1e9)
            return DailyBar(
                symbol: symbol,
                date: date,
                open: o / 1e9, high: h / 1e9, low: l / 1e9, close: c / 1e9,
                volume: v
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - Intraday

    func fetchIntradayPrices(symbol: String) async throws -> [IntradayPoint] {
        let headers = try authHeaders()
        let from = Self.dateOnly.string(from: Date().addingTimeInterval(-86400))

        guard let req = APIRequest.get(
            "\(base)/timeseries.get_range?dataset=XNAS.ITCH&symbols=\(symbol)&schema=ohlcv-5m&start=\(from)&stype_in=raw_symbol&limit=200",
            provider: .dataBento,
            headers: headers
        ) else { throw MarketDataError.invalidResponse }

        let resp = try await httpClient.execute(req)
        guard let records = try JSONSerialization.jsonObject(with: resp.data) as? [[String: Any]] else {
            return []
        }

        return records.compactMap { record in
            guard let tsNanos = record["ts_event"] as? Int64,
                  let c = record["close"] as? Double,
                  let v = record["volume"] as? Int64 else { return nil }

            return IntradayPoint(
                symbol: symbol,
                timestamp: Date(timeIntervalSince1970: TimeInterval(tsNanos) / 1e9),
                price: c / 1e9,
                volume: v
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
}
