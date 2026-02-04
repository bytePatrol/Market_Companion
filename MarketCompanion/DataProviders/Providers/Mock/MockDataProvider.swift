// MockDataProvider.swift
// MarketCompanion
//
// Ships demo data so the app works beautifully out of the box with no API keys.

import Foundation

// Type alias for backward compatibility
typealias MockMarketDataProvider = MockDataProvider

final class MockDataProvider: MarketDataProvider, @unchecked Sendable {
    let providerID: ProviderID = .mock
    let capabilities = ProviderCapabilities(
        supportsRealtimeQuotes: true,
        supportsIntradayBars: true,
        supportsDailyBars: true
    )
    let isLive = false

    func healthCheck() async throws -> ProviderHealth {
        return .healthy(latencyMs: 1)
    }

    // MARK: - Seed Data

    static let seedHoldings: [Holding] = [
        Holding(symbol: "AAPL", shares: 50, costBasis: 172.50, tags: "tech,core"),
        Holding(symbol: "NVDA", shares: 30, costBasis: 480.00, tags: "tech,growth"),
        Holding(symbol: "MSFT", shares: 25, costBasis: 378.00, tags: "tech,core"),
        Holding(symbol: "AMZN", shares: 20, costBasis: 178.00, tags: "consumer,core"),
        Holding(symbol: "GOOGL", shares: 40, costBasis: 142.00, tags: "tech,core"),
        Holding(symbol: "META", shares: 15, costBasis: 485.00, tags: "tech,growth"),
        Holding(symbol: "JPM", shares: 35, costBasis: 195.00, tags: "financials,dividend"),
        Holding(symbol: "XOM", shares: 45, costBasis: 108.00, tags: "energy,dividend"),
    ]

    static let seedWatchItems: [WatchItem] = [
        WatchItem(symbol: "TSLA", reasonTag: "Unusual volume", note: "Delivery numbers next week"),
        WatchItem(symbol: "AMD", reasonTag: "Sector momentum", note: "AI chip demand surge"),
        WatchItem(symbol: "CRM", reasonTag: "Earnings catalyst", note: "Reports Thursday AH"),
        WatchItem(symbol: "LLY", reasonTag: "Breakout candidate", note: "New ATH territory"),
        WatchItem(symbol: "BA", reasonTag: "Support level", note: "Testing 200-day MA"),
        WatchItem(symbol: "COST", reasonTag: "Sector momentum", note: "Retail strength"),
    ]

    // MARK: - Mock Quote Generation

    private struct MockStock {
        let symbol: String
        let basePrice: Double
        let avgVolume: Int64
        let volatility: Double

        func generateQuote() -> Quote {
            let changeBase = Double.random(in: -volatility...volatility)
            // Skew slightly positive for realism
            let changePct = changeBase + Double.random(in: -0.2...0.3)
            let last = basePrice * (1 + changePct / 100)
            let volumeMultiplier = Double.random(in: 0.7...2.0)
            let volume = Int64(Double(avgVolume) * volumeMultiplier)
            let dayRange = basePrice * volatility / 100
            let dayLow = last - Double.random(in: 0...dayRange)
            let dayHigh = last + Double.random(in: 0...dayRange)

            return Quote(
                symbol: symbol,
                last: round(last * 100) / 100,
                changePct: round(changePct * 100) / 100,
                volume: volume,
                avgVolume: avgVolume,
                dayHigh: round(dayHigh * 100) / 100,
                dayLow: round(dayLow * 100) / 100
            )
        }
    }

    private let mockStocks: [MockStock] = [
        MockStock(symbol: "AAPL", basePrice: 192.50, avgVolume: 55_000_000, volatility: 1.8),
        MockStock(symbol: "NVDA", basePrice: 875.00, avgVolume: 42_000_000, volatility: 3.2),
        MockStock(symbol: "MSFT", basePrice: 415.00, avgVolume: 22_000_000, volatility: 1.5),
        MockStock(symbol: "AMZN", basePrice: 188.00, avgVolume: 48_000_000, volatility: 2.2),
        MockStock(symbol: "GOOGL", basePrice: 155.00, avgVolume: 25_000_000, volatility: 1.9),
        MockStock(symbol: "META", basePrice: 520.00, avgVolume: 18_000_000, volatility: 2.8),
        MockStock(symbol: "TSLA", basePrice: 248.00, avgVolume: 95_000_000, volatility: 4.5),
        MockStock(symbol: "JPM", basePrice: 205.00, avgVolume: 10_000_000, volatility: 1.2),
        MockStock(symbol: "XOM", basePrice: 112.00, avgVolume: 15_000_000, volatility: 1.6),
        MockStock(symbol: "AMD", basePrice: 165.00, avgVolume: 55_000_000, volatility: 3.5),
        MockStock(symbol: "CRM", basePrice: 285.00, avgVolume: 6_000_000, volatility: 2.5),
        MockStock(symbol: "LLY", basePrice: 780.00, avgVolume: 3_500_000, volatility: 2.0),
        MockStock(symbol: "BA", basePrice: 215.00, avgVolume: 8_000_000, volatility: 2.8),
        MockStock(symbol: "COST", basePrice: 725.00, avgVolume: 2_500_000, volatility: 1.3),
        MockStock(symbol: "JNJ", basePrice: 158.00, avgVolume: 7_500_000, volatility: 0.9),
        MockStock(symbol: "V", basePrice: 282.00, avgVolume: 6_000_000, volatility: 1.1),
        MockStock(symbol: "UNH", basePrice: 530.00, avgVolume: 3_200_000, volatility: 1.4),
        MockStock(symbol: "HD", basePrice: 365.00, avgVolume: 4_000_000, volatility: 1.6),
    ]

    // MARK: - Protocol Implementation

    func fetchQuotes(symbols: [String]) async throws -> [Quote] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000)

        return symbols.compactMap { symbol in
            mockStocks.first(where: { $0.symbol == symbol })?.generateQuote()
        }
    }

    func fetchDailyBars(symbol: String, from: Date, to: Date) async throws -> [DailyBar] {
        try await Task.sleep(nanoseconds: 200_000_000)

        guard let stock = mockStocks.first(where: { $0.symbol == symbol }) else {
            throw MarketDataError.symbolNotFound(symbol)
        }

        let calendar = Calendar.current
        var bars: [DailyBar] = []
        var currentDate = from
        var price = stock.basePrice * 0.95 // Start slightly below current

        while currentDate <= to {
            // Skip weekends
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday != 1 && weekday != 7 {
                let dailyReturn = Double.random(in: -stock.volatility...stock.volatility) / 100
                let open = price
                price = price * (1 + dailyReturn)
                let high = max(open, price) * (1 + Double.random(in: 0...0.01))
                let low = min(open, price) * (1 - Double.random(in: 0...0.01))
                let volume = Int64(Double(stock.avgVolume) * Double.random(in: 0.6...1.8))

                bars.append(DailyBar(
                    symbol: symbol,
                    date: currentDate,
                    open: round(open * 100) / 100,
                    high: round(high * 100) / 100,
                    low: round(low * 100) / 100,
                    close: round(price * 100) / 100,
                    volume: volume
                ))
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return bars
    }

    func fetchMarketOverview() async throws -> MarketOverview {
        try await Task.sleep(nanoseconds: 250_000_000)

        let advancing = Int.random(in: 150...350)
        let declining = 500 - advancing
        let vix = Double.random(in: 12...28)

        let regime: VolatilityRegime
        if vix < 15 { regime = .low }
        else if vix < 20 { regime = .normal }
        else if vix < 25 { regime = .elevated }
        else { regime = .high }

        let sectors: [SectorPerformance] = [
            SectorPerformance(sector: "Technology", changePct: Double.random(in: -2...3), leaderSymbol: "NVDA", leaderChangePct: Double.random(in: -3...5)),
            SectorPerformance(sector: "Financials", changePct: Double.random(in: -1.5...2), leaderSymbol: "JPM", leaderChangePct: Double.random(in: -2...3)),
            SectorPerformance(sector: "Healthcare", changePct: Double.random(in: -1...1.5), leaderSymbol: "LLY", leaderChangePct: Double.random(in: -2...4)),
            SectorPerformance(sector: "Energy", changePct: Double.random(in: -2.5...2.5), leaderSymbol: "XOM", leaderChangePct: Double.random(in: -3...3)),
            SectorPerformance(sector: "Consumer", changePct: Double.random(in: -1.5...2), leaderSymbol: "AMZN", leaderChangePct: Double.random(in: -2...3)),
            SectorPerformance(sector: "Communication", changePct: Double.random(in: -2...2.5), leaderSymbol: "META", leaderChangePct: Double.random(in: -3...4)),
            SectorPerformance(sector: "Industrials", changePct: Double.random(in: -1...1.5), leaderSymbol: "CAT", leaderChangePct: Double.random(in: -2...2)),
            SectorPerformance(sector: "Utilities", changePct: Double.random(in: -0.8...0.8), leaderSymbol: "NEE", leaderChangePct: Double.random(in: -1...1.5)),
        ].map { sp in
            SectorPerformance(
                sector: sp.sector,
                changePct: round(sp.changePct * 100) / 100,
                leaderSymbol: sp.leaderSymbol,
                leaderChangePct: round(sp.leaderChangePct * 100) / 100
            )
        }

        return MarketOverview(
            breadthAdvancing: advancing,
            breadthDeclining: declining,
            vixProxy: round(vix * 10) / 10,
            volatilityRegime: regime,
            sectorPerformance: sectors.sorted { abs($0.changePct) > abs($1.changePct) },
            updatedAt: Date()
        )
    }

    func fetchIntradayPrices(symbol: String) async throws -> [IntradayPoint] {
        try await Task.sleep(nanoseconds: 150_000_000)

        guard let stock = mockStocks.first(where: { $0.symbol == symbol }) else {
            throw MarketDataError.symbolNotFound(symbol)
        }

        let calendar = Calendar.current
        let now = Date()
        var points: [IntradayPoint] = []
        var price = stock.basePrice

        // Generate 78 five-minute bars (6.5 hours of trading)
        for i in 0..<78 {
            let minutesFromOpen = i * 5
            let timestamp = calendar.date(byAdding: .minute, value: -390 + minutesFromOpen, to: now)!
            let change = Double.random(in: -0.003...0.003)
            price = price * (1 + change)
            let volume = Int64(Double(stock.avgVolume) / 78 * Double.random(in: 0.3...3.0))

            points.append(IntradayPoint(
                symbol: symbol,
                timestamp: timestamp,
                price: round(price * 100) / 100,
                volume: volume
            ))
        }

        return points
    }
}
