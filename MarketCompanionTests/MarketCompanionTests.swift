// MarketCompanionTests.swift
// MarketCompanion

import XCTest
@testable import MarketCompanion

final class ModelTests: XCTestCase {

    // MARK: - Quote Tests

    func testQuoteIsUp() {
        let quote = Quote(symbol: "AAPL", last: 192.50, changePct: 1.23, volume: 55_000_000, avgVolume: 45_000_000, dayHigh: 193.00, dayLow: 190.00)
        XCTAssertTrue(quote.isUp)
    }

    func testQuoteIsDown() {
        let quote = Quote(symbol: "AAPL", last: 188.00, changePct: -1.50, volume: 55_000_000, avgVolume: 45_000_000, dayHigh: 191.00, dayLow: 187.00)
        XCTAssertFalse(quote.isUp)
    }

    func testQuoteIsFlat() {
        let quote = Quote(symbol: "AAPL", last: 190.00, changePct: 0.0, volume: 45_000_000, avgVolume: 45_000_000, dayHigh: 191.00, dayLow: 189.00)
        XCTAssertTrue(quote.isUp)
    }

    func testVolumeRatio() {
        let quote = Quote(symbol: "AAPL", last: 192.50, changePct: 1.0, volume: 90_000_000, avgVolume: 45_000_000, dayHigh: 193.00, dayLow: 190.00)
        XCTAssertEqual(quote.volumeRatio, 2.0, accuracy: 0.01)
    }

    func testVolumeRatioZeroAvg() {
        let quote = Quote(symbol: "TEST", last: 10.0, changePct: 0, volume: 100, avgVolume: 0, dayHigh: 11, dayLow: 9)
        XCTAssertEqual(quote.volumeRatio, 1.0)
    }

    func testIntradayRange() {
        let quote = Quote(symbol: "AAPL", last: 192.50, changePct: 1.0, volume: 50_000_000, avgVolume: 45_000_000, dayHigh: 195.00, dayLow: 190.00)
        XCTAssertEqual(quote.intradayRange, 2.63, accuracy: 0.01)
    }

    func testIntradayRangeZeroLow() {
        let quote = Quote(symbol: "TEST", last: 0, changePct: 0, volume: 0, avgVolume: 0, dayHigh: 10, dayLow: 0)
        XCTAssertEqual(quote.intradayRange, 0)
    }

    // MARK: - Trade Tests

    func testTradePnlLong() {
        let trade = Trade(symbol: "AAPL", side: .long, qty: 100, entryPrice: 180.00, exitPrice: 190.00)
        XCTAssertEqual(trade.pnl!, 1000.00, accuracy: 0.01)
    }

    func testTradePnlShort() {
        let trade = Trade(symbol: "TSLA", side: .short, qty: 50, entryPrice: 250.00, exitPrice: 240.00)
        XCTAssertEqual(trade.pnl!, 500.00, accuracy: 0.01)
    }

    func testTradePnlShortLoss() {
        let trade = Trade(symbol: "TSLA", side: .short, qty: 50, entryPrice: 250.00, exitPrice: 260.00)
        XCTAssertEqual(trade.pnl!, -500.00, accuracy: 0.01)
    }

    func testTradePnlLongLoss() {
        let trade = Trade(symbol: "AAPL", side: .long, qty: 100, entryPrice: 190.00, exitPrice: 180.00)
        XCTAssertEqual(trade.pnl!, -1000.00, accuracy: 0.01)
    }

    func testTradeOpenHasNoPnl() {
        let trade = Trade(symbol: "AAPL", side: .long, qty: 100, entryPrice: 180.00)
        XCTAssertNil(trade.pnl)
        XCTAssertFalse(trade.isClosed)
    }

    func testTradePnlPercent() {
        let trade = Trade(symbol: "AAPL", side: .long, qty: 100, entryPrice: 200.00, exitPrice: 210.00)
        XCTAssertEqual(trade.pnlPercent!, 5.0, accuracy: 0.01)
    }

    func testTradePnlPercentShort() {
        let trade = Trade(symbol: "TSLA", side: .short, qty: 50, entryPrice: 200.00, exitPrice: 190.00)
        XCTAssertEqual(trade.pnlPercent!, 5.0, accuracy: 0.01)
    }

    func testTradeIsClosed() {
        let trade = Trade(symbol: "AAPL", side: .long, qty: 100, entryPrice: 180.00, exitPrice: 190.00, exitTime: Date())
        XCTAssertTrue(trade.isClosed)
    }

    func testTradeTagList() {
        let trade = Trade(symbol: "AAPL", side: .long, qty: 10, entryPrice: 100, tags: "scalp, momentum, morning")
        XCTAssertEqual(trade.tagList, ["scalp", "momentum", "morning"])
    }

    func testTradeEmptyTagList() {
        let trade = Trade(symbol: "AAPL", side: .long, qty: 10, entryPrice: 100)
        XCTAssertEqual(trade.tagList, [])
    }

    // MARK: - Holding Tests

    func testHoldingTagList() {
        let holding = Holding(symbol: "AAPL", tags: "tech, core, dividend")
        XCTAssertEqual(holding.tagList, ["tech", "core", "dividend"])
    }

    func testHoldingEmptyTags() {
        let holding = Holding(symbol: "AAPL", tags: "")
        XCTAssertEqual(holding.tagList, [])
    }

    // MARK: - DailyBar Tests

    func testDailyBarChangePercent() {
        let bar = DailyBar(symbol: "AAPL", date: Date(), open: 100, high: 105, low: 98, close: 103, volume: 1_000_000)
        XCTAssertEqual(bar.changePercent, 3.0, accuracy: 0.01)
    }

    func testDailyBarChangePercentNegative() {
        let bar = DailyBar(symbol: "AAPL", date: Date(), open: 100, high: 102, low: 95, close: 97, volume: 500_000)
        XCTAssertEqual(bar.changePercent, -3.0, accuracy: 0.01)
    }

    func testDailyBarChangePercentZeroOpen() {
        let bar = DailyBar(symbol: "TEST", date: Date(), open: 0, high: 10, low: 0, close: 5, volume: 100)
        XCTAssertEqual(bar.changePercent, 0)
    }

    // MARK: - AlertRule Tests

    func testAlertRuleDisplayNameWithSymbol() {
        let rule = AlertRule(symbol: "AAPL", type: .volumeSpike)
        XCTAssertEqual(rule.displayName, "AAPL Volume Spike")
    }

    func testAlertRuleDisplayNameMarketWide() {
        let rule = AlertRule(type: .unusualVolatility)
        XCTAssertEqual(rule.displayName, "Market Unusual Volatility")
    }

    func testAlertRuleDisplayNameTrendBreak() {
        let rule = AlertRule(symbol: "NVDA", type: .trendBreak)
        XCTAssertEqual(rule.displayName, "NVDA Trend Break")
    }

    func testAlertRuleDefaults() {
        let rule = AlertRule(type: .volumeSpike)
        XCTAssertEqual(rule.thresholdValue, 2.0)
        XCTAssertTrue(rule.enabled)
        XCTAssertNil(rule.symbol)
        XCTAssertNil(rule.sector)
    }

    // MARK: - Sector Classification Tests

    func testSectorClassification() {
        XCTAssertEqual(MarketSector.classify("AAPL"), .technology)
        XCTAssertEqual(MarketSector.classify("JPM"), .financials)
        XCTAssertEqual(MarketSector.classify("XOM"), .energy)
        XCTAssertEqual(MarketSector.classify("JNJ"), .healthcare)
        XCTAssertEqual(MarketSector.classify("AMZN"), .consumer)
    }

    func testSectorClassificationCommunication() {
        XCTAssertEqual(MarketSector.classify("GOOGL"), .communication)
        XCTAssertEqual(MarketSector.classify("META"), .communication)
        XCTAssertEqual(MarketSector.classify("NFLX"), .communication)
    }

    func testSectorClassificationIndustrials() {
        XCTAssertEqual(MarketSector.classify("BA"), .industrials)
        XCTAssertEqual(MarketSector.classify("CAT"), .industrials)
    }

    func testSectorClassificationUnknownDefaultsToTech() {
        XCTAssertEqual(MarketSector.classify("ZZZZZ"), .technology)
    }

    // MARK: - Market Overview Tests

    func testMarketRegimeRiskOn() {
        let overview = MarketOverview(
            breadthAdvancing: 400,
            breadthDeclining: 100,
            vixProxy: 13.0,
            volatilityRegime: .low,
            sectorPerformance: [],
            updatedAt: Date()
        )
        XCTAssertEqual(overview.marketRegime, "Risk-On")
    }

    func testMarketRegimeRiskOff() {
        let overview = MarketOverview(
            breadthAdvancing: 100,
            breadthDeclining: 400,
            vixProxy: 28.0,
            volatilityRegime: .high,
            sectorPerformance: [],
            updatedAt: Date()
        )
        XCTAssertEqual(overview.marketRegime, "Risk-Off")
    }

    func testMarketRegimeNeutral() {
        let overview = MarketOverview(
            breadthAdvancing: 250,
            breadthDeclining: 250,
            vixProxy: 18.0,
            volatilityRegime: .normal,
            sectorPerformance: [],
            updatedAt: Date()
        )
        XCTAssertEqual(overview.marketRegime, "Neutral")
    }

    func testBreadthRatio() {
        let overview = MarketOverview(
            breadthAdvancing: 300,
            breadthDeclining: 200,
            vixProxy: 18.0,
            volatilityRegime: .normal,
            sectorPerformance: [],
            updatedAt: Date()
        )
        XCTAssertEqual(overview.breadthRatio, 0.6, accuracy: 0.01)
    }

    func testBreadthRatioZeroTotal() {
        let overview = MarketOverview(
            breadthAdvancing: 0,
            breadthDeclining: 0,
            vixProxy: 18.0,
            volatilityRegime: .normal,
            sectorPerformance: [],
            updatedAt: Date()
        )
        XCTAssertEqual(overview.breadthRatio, 0.5, accuracy: 0.01)
    }

    // MARK: - Format Helper Tests

    func testPercentFormatPositive() {
        XCTAssertEqual(FormatHelper.percent(2.345), "+2.35%")
    }

    func testPercentFormatNegative() {
        XCTAssertEqual(FormatHelper.percent(-1.5), "-1.50%")
    }

    func testPercentFormatZero() {
        XCTAssertEqual(FormatHelper.percent(0.0), "0.00%")
    }

    func testPercentFormatUnsigned() {
        XCTAssertEqual(FormatHelper.percent(2.5, signed: false), "2.50%")
    }

    func testPriceFormat() {
        XCTAssertEqual(FormatHelper.price(192.50), "$192.50")
    }

    func testPriceFormatSmall() {
        XCTAssertEqual(FormatHelper.price(0.5432), "$0.5432")
    }

    func testPriceFormatLarge() {
        XCTAssertEqual(FormatHelper.price(1500.00), "$1500.00")
    }

    func testVolumeFormatMillions() {
        XCTAssertEqual(FormatHelper.volume(55_000_000), "55.0M")
    }

    func testVolumeFormatBillions() {
        XCTAssertEqual(FormatHelper.volume(1_500_000_000), "1.5B")
    }

    func testVolumeFormatThousands() {
        XCTAssertEqual(FormatHelper.volume(850_000), "850.0K")
    }

    func testVolumeFormatSmall() {
        XCTAssertEqual(FormatHelper.volume(500), "500")
    }

    func testPnlFormat() {
        XCTAssertEqual(FormatHelper.pnl(1500.00), "+$1500.00")
        XCTAssertEqual(FormatHelper.pnl(-500.00), "-$500.00")
    }

    func testPnlFormatZero() {
        XCTAssertEqual(FormatHelper.pnl(0.0), "+$0.00")
    }

    // MARK: - Report Type Tests

    func testReportTypeRawValues() {
        XCTAssertEqual(ReportType.morning.rawValue, "morning")
        XCTAssertEqual(ReportType.close.rawValue, "close")
    }

    // MARK: - TradeSide Tests

    func testTradeSideRawValues() {
        XCTAssertEqual(TradeSide.long.rawValue, "long")
        XCTAssertEqual(TradeSide.short.rawValue, "short")
    }

    // MARK: - VolatilityRegime Tests

    func testVolatilityRegimeRawValues() {
        XCTAssertEqual(VolatilityRegime.low.rawValue, "Low")
        XCTAssertEqual(VolatilityRegime.normal.rawValue, "Normal")
        XCTAssertEqual(VolatilityRegime.elevated.rawValue, "Elevated")
        XCTAssertEqual(VolatilityRegime.high.rawValue, "High")
    }
}

// MARK: - Mock Data Provider Tests

final class MockDataProviderTests: XCTestCase {

    let provider = MockDataProvider()

    func testFetchQuotesReturnsData() async throws {
        let quotes = try await provider.fetchQuotes(symbols: ["AAPL", "MSFT", "NVDA"])
        XCTAssertEqual(quotes.count, 3)
        XCTAssert(quotes.allSatisfy { $0.last > 0 })
        XCTAssert(quotes.allSatisfy { $0.volume > 0 })
    }

    func testFetchQuotesUnknownSymbol() async throws {
        let quotes = try await provider.fetchQuotes(symbols: ["AAPL", "ZZZZZZ"])
        XCTAssertEqual(quotes.count, 1)
    }

    func testFetchQuotesEmpty() async throws {
        let quotes = try await provider.fetchQuotes(symbols: [])
        XCTAssertEqual(quotes.count, 0)
    }

    func testFetchDailyBars() async throws {
        let calendar = Calendar.current
        let to = Date()
        let from = calendar.date(byAdding: .day, value: -10, to: to)!

        let bars = try await provider.fetchDailyBars(symbol: "AAPL", from: from, to: to)
        XCTAssertGreaterThan(bars.count, 0)
        XCTAssert(bars.allSatisfy { $0.symbol == "AAPL" })
        XCTAssert(bars.allSatisfy { $0.close > 0 })
    }

    func testFetchDailyBarsHasCorrectPriceRelation() async throws {
        let calendar = Calendar.current
        let to = Date()
        let from = calendar.date(byAdding: .day, value: -10, to: to)!

        let bars = try await provider.fetchDailyBars(symbol: "AAPL", from: from, to: to)
        for bar in bars {
            XCTAssertLessThanOrEqual(bar.low, bar.close)
            XCTAssertGreaterThanOrEqual(bar.high, bar.close)
            XCTAssertLessThanOrEqual(bar.low, bar.open)
            XCTAssertGreaterThanOrEqual(bar.high, bar.open)
        }
    }

    func testFetchDailyBarsUnknownSymbol() async throws {
        let calendar = Calendar.current
        let to = Date()
        let from = calendar.date(byAdding: .day, value: -5, to: to)!

        do {
            _ = try await provider.fetchDailyBars(symbol: "ZZZZZZ", from: from, to: to)
            XCTFail("Should throw symbolNotFound")
        } catch MarketDataError.symbolNotFound {
            // Expected
        }
    }

    func testFetchMarketOverview() async throws {
        let overview = try await provider.fetchMarketOverview()
        XCTAssertGreaterThan(overview.breadthAdvancing, 0)
        XCTAssertGreaterThan(overview.breadthDeclining, 0)
        XCTAssertGreaterThan(overview.vixProxy, 0)
        XCTAssertFalse(overview.sectorPerformance.isEmpty)
    }

    func testFetchMarketOverviewSectorsHaveLeaders() async throws {
        let overview = try await provider.fetchMarketOverview()
        for sector in overview.sectorPerformance {
            XCTAssertFalse(sector.sector.isEmpty)
            XCTAssertFalse(sector.leaderSymbol.isEmpty)
        }
    }

    func testFetchIntradayPrices() async throws {
        let points = try await provider.fetchIntradayPrices(symbol: "AAPL")
        XCTAssertGreaterThan(points.count, 0)
        XCTAssert(points.allSatisfy { $0.symbol == "AAPL" })
        XCTAssert(points.allSatisfy { $0.price > 0 })
    }

    func testFetchIntradayPricesHaveVolume() async throws {
        let points = try await provider.fetchIntradayPrices(symbol: "MSFT")
        XCTAssert(points.allSatisfy { $0.volume > 0 })
    }

    func testProviderIsNotLive() {
        XCTAssertFalse(provider.isLive)
        XCTAssertEqual(provider.name, "Demo Data")
    }

    func testSeedHoldingsNotEmpty() {
        XCTAssertFalse(MockDataProvider.seedHoldings.isEmpty)
        XCTAssert(MockDataProvider.seedHoldings.allSatisfy { !$0.symbol.isEmpty })
    }

    func testSeedWatchItemsNotEmpty() {
        XCTAssertFalse(MockDataProvider.seedWatchItems.isEmpty)
        XCTAssert(MockDataProvider.seedWatchItems.allSatisfy { !$0.symbol.isEmpty })
        XCTAssert(MockDataProvider.seedWatchItems.allSatisfy { !$0.reasonTag.isEmpty })
    }
}

// MARK: - Database Repository Tests

final class RepositoryTests: XCTestCase {

    var db: DatabaseManager!

    override func setUp() async throws {
        db = try DatabaseManager(inMemory: true)
    }

    // MARK: - Holding Repository

    func testHoldingSaveAndFetch() throws {
        let repo = HoldingRepository(db: db)
        var holding = Holding(symbol: "AAPL", shares: 100, costBasis: 185.00, tags: "tech")
        try repo.save(&holding)

        let all = try repo.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.symbol, "AAPL")
        XCTAssertEqual(all.first?.shares, 100)
        XCTAssertNotNil(all.first?.id)
    }

    func testHoldingDelete() throws {
        let repo = HoldingRepository(db: db)
        var holding = Holding(symbol: "TSLA", shares: 50)
        try repo.save(&holding)

        let saved = try repo.find(symbol: "TSLA")
        XCTAssertNotNil(saved)
        try repo.delete(id: saved!.id!)
        XCTAssertEqual(try repo.all().count, 0)
    }

    func testHoldingFindBySymbol() throws {
        let repo = HoldingRepository(db: db)
        var h1 = Holding(symbol: "AAPL")
        var h2 = Holding(symbol: "MSFT")
        try repo.save(&h1)
        try repo.save(&h2)

        let found = try repo.find(symbol: "MSFT")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.symbol, "MSFT")

        let notFound = try repo.find(symbol: "NVDA")
        XCTAssertNil(notFound)
    }

    func testHoldingSymbols() throws {
        let repo = HoldingRepository(db: db)
        var h1 = Holding(symbol: "AAPL")
        var h2 = Holding(symbol: "MSFT")
        try repo.save(&h1)
        try repo.save(&h2)

        let symbols = try repo.symbols()
        XCTAssertEqual(symbols.sorted(), ["AAPL", "MSFT"])
    }

    // MARK: - WatchItem Repository

    func testWatchItemSaveAndFetch() throws {
        let repo = WatchItemRepository(db: db)
        var item = WatchItem(symbol: "NVDA", reasonTag: "momentum", note: "Breakout setup")
        try repo.save(&item)

        let all = try repo.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.symbol, "NVDA")
        XCTAssertEqual(all.first?.reasonTag, "momentum")
        XCTAssertNotNil(all.first?.id)
    }

    func testWatchItemDelete() throws {
        let repo = WatchItemRepository(db: db)
        var item = WatchItem(symbol: "AMD", reasonTag: "earnings")
        try repo.save(&item)

        let saved = try repo.all().first
        XCTAssertNotNil(saved)
        try repo.delete(id: saved!.id!)
        XCTAssertEqual(try repo.all().count, 0)
    }

    // MARK: - Quote Repository

    func testQuoteUpsertAndFetch() throws {
        let repo = QuoteRepository(db: db)
        let quotes = [
            Quote(symbol: "AAPL", last: 192.50, changePct: 1.23, volume: 55_000_000, avgVolume: 45_000_000, dayHigh: 193.00, dayLow: 190.00),
            Quote(symbol: "MSFT", last: 415.20, changePct: -0.50, volume: 25_000_000, avgVolume: 22_000_000, dayHigh: 418.00, dayLow: 413.00)
        ]
        try repo.upsert(quotes)

        let all = try repo.all()
        XCTAssertEqual(all.count, 2)
    }

    func testQuoteUpsertOverwrites() throws {
        let repo = QuoteRepository(db: db)
        let initial = [Quote(symbol: "AAPL", last: 190.00, changePct: 0.5, volume: 50_000_000, avgVolume: 45_000_000, dayHigh: 191.00, dayLow: 189.00)]
        try repo.upsert(initial)

        let updated = [Quote(symbol: "AAPL", last: 195.00, changePct: 2.0, volume: 60_000_000, avgVolume: 45_000_000, dayHigh: 196.00, dayLow: 189.00)]
        try repo.upsert(updated)

        let all = try repo.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.last, 195.00)
    }

    func testQuoteForSymbol() throws {
        let repo = QuoteRepository(db: db)
        let quotes = [
            Quote(symbol: "AAPL", last: 192.50, changePct: 1.23, volume: 55_000_000, avgVolume: 45_000_000, dayHigh: 193.00, dayLow: 190.00),
            Quote(symbol: "MSFT", last: 415.20, changePct: -0.50, volume: 25_000_000, avgVolume: 22_000_000, dayHigh: 418.00, dayLow: 413.00)
        ]
        try repo.upsert(quotes)

        let found = try repo.forSymbol("AAPL")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.last, 192.50)

        let notFound = try repo.forSymbol("NVDA")
        XCTAssertNil(notFound)
    }

    // MARK: - DailyBar Repository

    func testDailyBarSaveAndFetch() throws {
        let repo = DailyBarRepository(db: db)
        let bars = (0..<5).map { i in
            DailyBar(
                symbol: "AAPL",
                date: Calendar.current.date(byAdding: .day, value: -i, to: Date())!,
                open: 190 + Double(i),
                high: 193 + Double(i),
                low: 188 + Double(i),
                close: 191 + Double(i),
                volume: 50_000_000
            )
        }
        try repo.save(bars)

        let fetched = try repo.forSymbol("AAPL", limit: 10)
        XCTAssertEqual(fetched.count, 5)
    }

    func testDailyBarLatestDate() throws {
        let repo = DailyBarRepository(db: db)
        let today = Calendar.current.startOfDay(for: Date())
        let bars = [
            DailyBar(symbol: "AAPL", date: Calendar.current.date(byAdding: .day, value: -2, to: today)!, open: 190, high: 193, low: 188, close: 191, volume: 50_000_000),
            DailyBar(symbol: "AAPL", date: today, open: 192, high: 195, low: 190, close: 194, volume: 55_000_000)
        ]
        try repo.save(bars)

        let latest = try repo.latestDate(for: "AAPL")
        XCTAssertNotNil(latest)
    }

    // MARK: - Trade Repository

    func testTradeSaveAndFetch() throws {
        let repo = TradeRepository(db: db)
        var trade = Trade(symbol: "AAPL", side: .long, qty: 100, entryPrice: 185.00, notes: "breakout", tags: "scalp")
        try repo.save(&trade)

        let all = try repo.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.symbol, "AAPL")
        XCTAssertEqual(all.first?.qty, 100)
        XCTAssertNotNil(all.first?.id)
    }

    func testTradeOpenAndClosed() throws {
        let repo = TradeRepository(db: db)
        var openTrade = Trade(symbol: "AAPL", side: .long, qty: 100, entryPrice: 185.00)
        var closedTrade = Trade(symbol: "MSFT", side: .short, qty: 50, entryPrice: 415.00, exitPrice: 410.00, exitTime: Date())
        try repo.save(&openTrade)
        try repo.save(&closedTrade)

        XCTAssertEqual(try repo.open().count, 1)
        XCTAssertEqual(try repo.open().first?.symbol, "AAPL")

        XCTAssertEqual(try repo.closed().count, 1)
        XCTAssertEqual(try repo.closed().first?.symbol, "MSFT")
    }

    func testTradeDelete() throws {
        let repo = TradeRepository(db: db)
        var trade = Trade(symbol: "AAPL", side: .long, qty: 10, entryPrice: 100)
        try repo.save(&trade)

        let saved = try repo.all().first
        XCTAssertNotNil(saved)
        try repo.delete(id: saved!.id!)
        XCTAssertEqual(try repo.all().count, 0)
    }

    func testTradeForSymbol() throws {
        let repo = TradeRepository(db: db)
        var t1 = Trade(symbol: "AAPL", side: .long, qty: 100, entryPrice: 185.00)
        var t2 = Trade(symbol: "MSFT", side: .long, qty: 50, entryPrice: 415.00)
        var t3 = Trade(symbol: "AAPL", side: .short, qty: 30, entryPrice: 190.00)
        try repo.save(&t1)
        try repo.save(&t2)
        try repo.save(&t3)

        let aaplTrades = try repo.forSymbol("AAPL")
        XCTAssertEqual(aaplTrades.count, 2)
    }

    // MARK: - AlertRule Repository

    func testAlertRuleSaveAndFetch() throws {
        let repo = AlertRuleRepository(db: db)
        var rule = AlertRule(symbol: "AAPL", type: .volumeSpike, thresholdValue: 2.5)
        try repo.save(&rule)

        let all = try repo.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.symbol, "AAPL")
        XCTAssertEqual(all.first?.thresholdValue, 2.5)
        XCTAssertNotNil(all.first?.id)
    }

    func testAlertRuleEnabled() throws {
        let repo = AlertRuleRepository(db: db)
        var enabled = AlertRule(symbol: "AAPL", type: .volumeSpike, enabled: true)
        var disabled = AlertRule(symbol: "MSFT", type: .trendBreak, enabled: false)
        try repo.save(&enabled)
        try repo.save(&disabled)

        let enabledRules = try repo.enabled()
        XCTAssertEqual(enabledRules.count, 1)
        XCTAssertEqual(enabledRules.first?.symbol, "AAPL")
    }

    func testAlertRuleToggleEnabled() throws {
        let repo = AlertRuleRepository(db: db)
        var rule = AlertRule(symbol: "AAPL", type: .volumeSpike, enabled: true)
        try repo.save(&rule)

        let savedId = try repo.all().first!.id!
        try repo.toggleEnabled(id: savedId)
        let toggled = try repo.all().first
        XCTAssertEqual(toggled?.enabled, false)

        try repo.toggleEnabled(id: savedId)
        let toggledBack = try repo.all().first
        XCTAssertEqual(toggledBack?.enabled, true)
    }

    func testAlertRuleDelete() throws {
        let repo = AlertRuleRepository(db: db)
        var rule = AlertRule(type: .unusualVolatility)
        try repo.save(&rule)

        let savedId = try repo.all().first!.id!
        try repo.delete(id: savedId)
        XCTAssertEqual(try repo.all().count, 0)
    }

    // MARK: - AlertEvent Repository

    func testAlertEventSaveAndFetch() throws {
        let ruleRepo = AlertRuleRepository(db: db)
        let eventRepo = AlertEventRepository(db: db)

        var rule = AlertRule(symbol: "AAPL", type: .volumeSpike)
        try ruleRepo.save(&rule)
        let ruleId = try ruleRepo.all().first!.id!

        var event = AlertEvent(ruleId: ruleId, summary: "AAPL volume spike", details: "2.5x average")
        try eventRepo.save(&event)

        let all = try eventRepo.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.summary, "AAPL volume spike")
    }

    func testAlertEventForRule() throws {
        let ruleRepo = AlertRuleRepository(db: db)
        let eventRepo = AlertEventRepository(db: db)

        var rule1 = AlertRule(symbol: "AAPL", type: .volumeSpike)
        var rule2 = AlertRule(symbol: "MSFT", type: .trendBreak)
        try ruleRepo.save(&rule1)
        try ruleRepo.save(&rule2)

        let allRules = try ruleRepo.all()
        let rule1Id = allRules.first(where: { $0.symbol == "AAPL" })!.id!
        let rule2Id = allRules.first(where: { $0.symbol == "MSFT" })!.id!

        var event1 = AlertEvent(ruleId: rule1Id, summary: "AAPL event")
        var event2 = AlertEvent(ruleId: rule2Id, summary: "MSFT event")
        try eventRepo.save(&event1)
        try eventRepo.save(&event2)

        let rule1Events = try eventRepo.forRule(rule1Id)
        XCTAssertEqual(rule1Events.count, 1)
        XCTAssertEqual(rule1Events.first?.summary, "AAPL event")
    }

    func testAlertEventCascadeDelete() throws {
        let ruleRepo = AlertRuleRepository(db: db)
        let eventRepo = AlertEventRepository(db: db)

        var rule = AlertRule(symbol: "AAPL", type: .volumeSpike)
        try ruleRepo.save(&rule)
        let ruleId = try ruleRepo.all().first!.id!

        var event = AlertEvent(ruleId: ruleId, summary: "test")
        try eventRepo.save(&event)
        XCTAssertEqual(try eventRepo.all().count, 1)

        try ruleRepo.delete(id: ruleId)
        XCTAssertEqual(try eventRepo.all().count, 0)
    }

    // MARK: - Report Repository

    func testReportSaveAndFetch() throws {
        let repo = ReportRepository(db: db)
        var report = Report(type: .morning, jsonPayload: "{}", renderedMarkdown: "# Morning Report")
        try repo.save(&report)

        let all = try repo.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.type, .morning)
        XCTAssertNotNil(all.first?.id)
    }

    func testReportLatest() throws {
        let repo = ReportRepository(db: db)
        var r1 = Report(type: .morning, createdAt: Date().addingTimeInterval(-3600), renderedMarkdown: "First")
        var r2 = Report(type: .morning, createdAt: Date(), renderedMarkdown: "Latest")
        try repo.save(&r1)
        try repo.save(&r2)

        let latest = try repo.latest(type: .morning)
        XCTAssertEqual(latest?.renderedMarkdown, "Latest")
    }

    func testReportFilterByType() throws {
        let repo = ReportRepository(db: db)
        var morning = Report(type: .morning, renderedMarkdown: "Morning")
        var close = Report(type: .close, renderedMarkdown: "Close")
        try repo.save(&morning)
        try repo.save(&close)

        let mornings = try repo.all(type: .morning)
        XCTAssertEqual(mornings.count, 1)
        XCTAssertEqual(mornings.first?.type, .morning)
    }

    func testReportForDate() throws {
        let repo = ReportRepository(db: db)
        var today = Report(type: .morning, createdAt: Date(), renderedMarkdown: "Today")
        var yesterday = Report(type: .morning, createdAt: Date().addingTimeInterval(-86400), renderedMarkdown: "Yesterday")
        try repo.save(&today)
        try repo.save(&yesterday)

        let todayReports = try repo.forDate(Date())
        XCTAssertEqual(todayReports.count, 1)
        XCTAssertEqual(todayReports.first?.renderedMarkdown, "Today")
    }

    // MARK: - TradeContext Repository

    func testTradeContextSaveAndFetch() throws {
        let tradeRepo = TradeRepository(db: db)
        let contextRepo = TradeContextRepository(db: db)

        var trade = Trade(symbol: "AAPL", side: .long, qty: 100, entryPrice: 185.00)
        try tradeRepo.save(&trade)
        let tradeId = try tradeRepo.all().first!.id!

        var context = TradeContext(
            tradeId: tradeId,
            vixProxy: 15.5,
            marketBreadthProxy: 0.65,
            volatilityRegime: "normal",
            timeOfDay: "9:35 AM"
        )
        try contextRepo.save(&context)

        let fetched = try contextRepo.forTrade(tradeId)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.vixProxy, 15.5)
        XCTAssertEqual(fetched?.volatilityRegime, "normal")
    }

    // MARK: - Delete All Data

    func testDeleteAllData() throws {
        let holdingRepo = HoldingRepository(db: db)
        let tradeRepo = TradeRepository(db: db)

        var holding = Holding(symbol: "AAPL")
        var trade = Trade(symbol: "AAPL", side: .long, qty: 10, entryPrice: 185.00)
        try holdingRepo.save(&holding)
        try tradeRepo.save(&trade)

        XCTAssertEqual(try holdingRepo.all().count, 1)
        XCTAssertEqual(try tradeRepo.all().count, 1)

        try db.deleteAllData()

        XCTAssertEqual(try holdingRepo.all().count, 0)
        XCTAssertEqual(try tradeRepo.all().count, 0)
    }
}

// MARK: - Keychain Tests

final class KeychainServiceTests: XCTestCase {
    let service = KeychainService.shared

    override func tearDown() {
        try? service.deleteAll()
    }

    func testSaveAndRead() throws {
        try service.save(key: .marketDataAPIKey, value: "test-key-123")
        let value = service.read(key: .marketDataAPIKey)
        XCTAssertEqual(value, "test-key-123")
    }

    func testReadMissing() {
        let value = service.read(key: .marketDataBaseURL)
        XCTAssertNil(value)
    }

    func testDelete() throws {
        try service.save(key: .marketDataAPIKey, value: "test-key")
        try service.delete(key: .marketDataAPIKey)
        XCTAssertNil(service.read(key: .marketDataAPIKey))
    }

    func testHasKey() throws {
        XCTAssertFalse(service.hasKey(.marketDataAPIKey))
        try service.save(key: .marketDataAPIKey, value: "exists")
        XCTAssertTrue(service.hasKey(.marketDataAPIKey))
    }

    func testOverwrite() throws {
        try service.save(key: .marketDataAPIKey, value: "first")
        try service.save(key: .marketDataAPIKey, value: "second")
        XCTAssertEqual(service.read(key: .marketDataAPIKey), "second")
    }

    // MARK: - Per-Provider Secrets

    func testProviderSecretSaveAndRead() throws {
        try service.saveProviderSecret(providerID: .finnhub, key: "api_key", value: "fh-test-123")
        let value = service.readProviderSecret(providerID: .finnhub, key: "api_key")
        XCTAssertEqual(value, "fh-test-123")
    }

    func testProviderSecretReadMissing() {
        let value = service.readProviderSecret(providerID: .alpaca, key: "api_key")
        XCTAssertNil(value)
    }

    func testProviderSecretDelete() throws {
        try service.saveProviderSecret(providerID: .alphaVantage, key: "api_key", value: "av-key")
        try service.deleteProviderSecret(providerID: .alphaVantage, key: "api_key")
        XCTAssertNil(service.readProviderSecret(providerID: .alphaVantage, key: "api_key"))
    }

    func testProviderSecretIsolation() throws {
        try service.saveProviderSecret(providerID: .finnhub, key: "api_key", value: "finnhub-key")
        try service.saveProviderSecret(providerID: .alpaca, key: "api_key", value: "alpaca-key")

        XCTAssertEqual(service.readProviderSecret(providerID: .finnhub, key: "api_key"), "finnhub-key")
        XCTAssertEqual(service.readProviderSecret(providerID: .alpaca, key: "api_key"), "alpaca-key")
    }

    func testProviderSecretMultipleKeys() throws {
        try service.saveProviderSecret(providerID: .alpaca, key: "api_key", value: "key-123")
        try service.saveProviderSecret(providerID: .alpaca, key: "api_secret", value: "secret-456")

        XCTAssertEqual(service.readProviderSecret(providerID: .alpaca, key: "api_key"), "key-123")
        XCTAssertEqual(service.readProviderSecret(providerID: .alpaca, key: "api_secret"), "secret-456")
    }

    func testDeleteAllProviderSecrets() throws {
        try service.saveProviderSecret(providerID: .finnhub, key: "api_key", value: "key")
        try service.saveProviderSecret(providerID: .finnhub, key: "base_url", value: "url")
        try service.deleteAllProviderSecrets(providerID: .finnhub)

        XCTAssertNil(service.readProviderSecret(providerID: .finnhub, key: "api_key"))
        XCTAssertNil(service.readProviderSecret(providerID: .finnhub, key: "base_url"))
    }

    func testHasProviderCredentials() throws {
        XCTAssertFalse(service.hasProviderCredentials(providerID: .finnhub))
        try service.saveProviderSecret(providerID: .finnhub, key: "api_key", value: "key")
        XCTAssertTrue(service.hasProviderCredentials(providerID: .finnhub))
    }
}

// MARK: - Provider Router Tests

final class ProviderRouterTests: XCTestCase {

    func testDemoModeUseMockProvider() async throws {
        let mock = MockDataProvider()
        let registry = ProviderRegistry(providers: [mock])
        let router = ProviderRouter(registry: registry)
        router.setDataMode(.demo)

        let quotes = try await router.fetchQuotes(symbols: ["AAPL"])
        // Mock provider returns quotes for known symbols
        XCTAssertEqual(quotes.count, 1)
        XCTAssertEqual(quotes.first?.symbol, "AAPL")
    }

    func testLiveModeWithMockFallback() async throws {
        let mock = MockDataProvider()
        let registry = ProviderRegistry(providers: [mock])
        let router = ProviderRouter(registry: registry)
        router.setDataMode(.live)
        router.setPrimary(.mock) // Only mock is available in test

        let quotes = try await router.fetchQuotes(symbols: ["AAPL"])
        XCTAssertEqual(quotes.count, 1)
    }

    func testHealthCheckReturnsResult() async throws {
        let mock = MockDataProvider()
        let registry = ProviderRegistry(providers: [mock])
        let router = ProviderRouter(registry: registry)
        router.setPrimary(.mock)

        let health = try await router.healthCheck()
        XCTAssertEqual(health.status, .healthy)
        XCTAssertEqual(health.latencyMs, 1)
    }

    func testDiagnosticsReturnsAllProviders() async {
        let mock = MockDataProvider()
        let registry = ProviderRegistry(providers: [mock])
        let router = ProviderRouter(registry: registry)

        let results = await router.runDiagnostics()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.0, .mock)
        XCTAssertEqual(results.first?.1.status, .healthy)
    }

    func testFetchDailyBarsViaRouter() async throws {
        let mock = MockDataProvider()
        let registry = ProviderRegistry(providers: [mock])
        let router = ProviderRouter(registry: registry)
        router.setDataMode(.demo)

        let from = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let bars = try await router.fetchDailyBars(symbol: "AAPL", from: from, to: Date())
        XCTAssertGreaterThan(bars.count, 0)
    }

    func testFetchIntradayViaRouter() async throws {
        let mock = MockDataProvider()
        let registry = ProviderRegistry(providers: [mock])
        let router = ProviderRouter(registry: registry)
        router.setDataMode(.demo)

        let points = try await router.fetchIntradayPrices(symbol: "AAPL")
        XCTAssertGreaterThan(points.count, 0)
    }

    func testFetchMarketOverviewViaRouter() async throws {
        let mock = MockDataProvider()
        let registry = ProviderRegistry(providers: [mock])
        let router = ProviderRouter(registry: registry)
        router.setDataMode(.demo)

        let overview = try await router.fetchMarketOverview()
        XCTAssertGreaterThan(overview.breadthAdvancing, 0)
    }
}

// MARK: - Rate Limiter Tests

final class RateLimiterTests: XCTestCase {

    func testBasicRateLimiterDoesNotBlock() async throws {
        let limiter = RateLimiter(
            provider: .mock,
            config: RateLimitConfig(requestsPerSecond: 100, requestsPerMinute: 1000, requestsPerDay: nil, burstLimit: 10)
        )
        // Should not throw or block for a single request
        try await limiter.waitIfNeeded()
    }

    func testRateLimiterTracksRequests() async throws {
        let limiter = RateLimiter(
            provider: .mock,
            config: RateLimitConfig(requestsPerSecond: 100, requestsPerMinute: 1000, requestsPerDay: nil, burstLimit: 10)
        )
        // Multiple requests should succeed
        for _ in 0..<5 {
            try await limiter.waitIfNeeded()
        }
    }

    func testRateLimitSignalFromExternal() async {
        let limiter = RateLimiter(
            provider: .finnhub,
            config: RateLimitConfig(requestsPerSecond: 10, requestsPerMinute: 60, requestsPerDay: nil, burstLimit: 5)
        )
        // Simulate receiving a 429
        await limiter.markRateLimited()
        // After marking, the limiter should still function (it just delays)
        do {
            try await limiter.waitIfNeeded()
        } catch {
            // Rate limited is acceptable
        }
    }

    func testDefaultConfigForProviders() {
        let finnhubConfig = RateLimitConfig.forProvider(.finnhub)
        XCTAssertEqual(finnhubConfig.requestsPerMinute, 60)

        let alphaConfig = RateLimitConfig.forProvider(.alphaVantage)
        XCTAssertEqual(alphaConfig.requestsPerMinute, 5)
        XCTAssertEqual(alphaConfig.requestsPerDay, 500)

        let mockConfig = RateLimitConfig.forProvider(.mock)
        XCTAssertEqual(mockConfig.requestsPerMinute, Int.max)
    }
}

// MARK: - Response Cache Tests

final class ResponseCacheTests: XCTestCase {

    func testCacheSetAndGet() async {
        let cache = ResponseCache()
        await cache.set("test-key", value: "hello", ttl: 60)
        let result: String? = await cache.get("test-key")
        XCTAssertEqual(result, "hello")
    }

    func testCacheExpiration() async throws {
        let cache = ResponseCache()
        await cache.set("expire-key", value: "value", ttl: 0.1)
        try await Task.sleep(nanoseconds: 200_000_000)
        let result: String? = await cache.get("expire-key")
        XCTAssertNil(result)
    }

    func testCacheMiss() async {
        let cache = ResponseCache()
        let result: String? = await cache.get("nonexistent")
        XCTAssertNil(result)
    }

    func testCacheEvictAll() async {
        let cache = ResponseCache()
        await cache.set("key1", value: "a", ttl: 60)
        await cache.set("key2", value: "b", ttl: 60)
        await cache.evictAll()

        let r1: String? = await cache.get("key1")
        let r2: String? = await cache.get("key2")
        XCTAssertNil(r1)
        XCTAssertNil(r2)
    }

    func testCacheKeyBuilders() {
        let quoteKey = ResponseCache.quoteKey(symbols: ["AAPL", "MSFT"])
        XCTAssertTrue(quoteKey.hasPrefix("quotes:"))
        XCTAssertTrue(quoteKey.contains("AAPL"))
        XCTAssertTrue(quoteKey.contains("MSFT"))

        let dailyKey = ResponseCache.dailyBarsKey(symbol: "AAPL", from: Date(), to: Date())
        XCTAssertTrue(dailyKey.hasPrefix("dailyBars:"))
        XCTAssertTrue(dailyKey.contains("AAPL"))

        let intradayKey = ResponseCache.intradayKey(symbol: "NVDA")
        XCTAssertEqual(intradayKey, "intraday:NVDA")

        let overviewKey = ResponseCache.overviewKey()
        XCTAssertEqual(overviewKey, "marketOverview")
    }
}

// MARK: - Provider Protocol Conformance Tests

final class ProviderProtocolTests: XCTestCase {

    func testMockProviderConformance() {
        let provider: MarketDataProvider = MockDataProvider()
        XCTAssertEqual(provider.providerID, .mock)
        XCTAssertFalse(provider.isLive)
        XCTAssertTrue(provider.capabilities.supportsRealtimeQuotes)
        XCTAssertTrue(provider.capabilities.supportsDailyBars)
        XCTAssertTrue(provider.capabilities.supportsIntradayBars)
    }

    func testFinnhubProviderCapabilities() {
        let provider = FinnhubProvider()
        XCTAssertEqual(provider.providerID, .finnhub)
        XCTAssertTrue(provider.isLive)
        XCTAssertTrue(provider.capabilities.supportsRealtimeQuotes)
        XCTAssertTrue(provider.capabilities.supportsDailyBars)
        XCTAssertFalse(provider.capabilities.supportsIntradayBars)
        XCTAssertTrue(provider.capabilities.supportsCompanyNews)
        XCTAssertTrue(provider.capabilities.supportsEarningsCalendar)
    }

    func testAlpacaProviderCapabilities() {
        let provider = AlpacaProvider()
        XCTAssertEqual(provider.providerID, .alpaca)
        XCTAssertTrue(provider.isLive)
        XCTAssertTrue(provider.capabilities.supportsRealtimeQuotes)
        XCTAssertTrue(provider.capabilities.supportsIntradayBars)
        XCTAssertTrue(provider.capabilities.supportsDailyBars)
        XCTAssertTrue(provider.capabilities.supportsCompanyNews)
    }

    func testAlphaVantageProviderCapabilities() {
        let provider = AlphaVantageProvider()
        XCTAssertEqual(provider.providerID, .alphaVantage)
        XCTAssertTrue(provider.isLive)
        XCTAssertEqual(provider.capabilities.maxSymbolsPerRequest, 1)
    }

    func testMarketStackProviderCapabilities() {
        let provider = MarketStackProvider()
        XCTAssertEqual(provider.providerID, .marketStack)
        XCTAssertTrue(provider.isLive)
        XCTAssertTrue(provider.capabilities.supportsDailyBars)
    }

    func testEODHDProviderCapabilities() {
        let provider = EODHDProvider()
        XCTAssertEqual(provider.providerID, .eodhd)
        XCTAssertTrue(provider.isLive)
        XCTAssertTrue(provider.capabilities.supportsCompanyNews)
    }

    func testMassiveProviderCapabilities() {
        let provider = MassiveProvider()
        XCTAssertEqual(provider.providerID, .massive)
        XCTAssertTrue(provider.isLive)
        XCTAssertTrue(provider.capabilities.supportsWebSocketStreaming)
        XCTAssertEqual(provider.capabilities.maxSymbolsPerRequest, 50)
    }

    func testDataBentoProviderCapabilities() {
        let provider = DataBentoProvider()
        XCTAssertEqual(provider.providerID, .dataBento)
        XCTAssertTrue(provider.isLive)
        XCTAssertTrue(provider.capabilities.supportsOptionsData)
    }

    func testThetaDataProviderCapabilities() {
        let provider = ThetaDataProvider()
        XCTAssertEqual(provider.providerID, .thetaData)
        XCTAssertTrue(provider.isLive)
        XCTAssertTrue(provider.capabilities.supportsOptionsData)
    }

    func testAllProvidersHaveDisplayName() {
        let providers: [MarketDataProvider] = [
            MockDataProvider(),
            FinnhubProvider(),
            AlpacaProvider(),
            AlphaVantageProvider(),
            MarketStackProvider(),
            EODHDProvider(),
            MassiveProvider(),
            DataBentoProvider(),
            ThetaDataProvider(),
        ]
        for provider in providers {
            XCTAssertFalse(provider.displayName.isEmpty, "\(provider.providerID) has empty display name")
        }
    }

    func testLiveProvidersRequireCredentials() async throws {
        // All live providers without credentials should return noCredentials health
        let providers: [MarketDataProvider] = [
            FinnhubProvider(),
            AlpacaProvider(),
            AlphaVantageProvider(),
        ]
        for provider in providers {
            let health = try await provider.healthCheck()
            XCTAssertEqual(health.status, .noCredentials, "\(provider.providerID) should report noCredentials without API key")
        }
    }
}

// MARK: - Provider Registry Tests

final class ProviderRegistryTests: XCTestCase {

    func testRegistryContainsAllProviders() {
        let registry = ProviderRegistry.shared
        for id in ProviderID.allCases {
            XCTAssertNotNil(registry.provider(for: id), "Missing provider for \(id)")
        }
    }

    func testRegistryHasRateLimiters() {
        let registry = ProviderRegistry.shared
        for id in ProviderID.allCases {
            XCTAssertNotNil(registry.rateLimiter(for: id), "Missing rate limiter for \(id)")
        }
    }

    func testRegistryAllProvidersList() {
        let registry = ProviderRegistry.shared
        XCTAssertEqual(registry.allProviders.count, ProviderID.allCases.count)
    }

    func testTestingInitWithCustomProviders() {
        let mock = MockDataProvider()
        let registry = ProviderRegistry(providers: [mock])
        XCTAssertNotNil(registry.provider(for: .mock))
        XCTAssertNil(registry.provider(for: .finnhub))
    }
}

// MARK: - MarketDataError Tests

final class MarketDataErrorTests: XCTestCase {

    func testRetryableErrors() {
        XCTAssertTrue(MarketDataError.rateLimited.isRetryable)
        XCTAssertTrue(MarketDataError.networkError("timeout").isRetryable)
        XCTAssertTrue(MarketDataError.providerUnavailable.isRetryable)
    }

    func testNonRetryableErrors() {
        XCTAssertFalse(MarketDataError.noAPIKey.isRetryable)
        XCTAssertFalse(MarketDataError.authenticationFailed.isRetryable)
        XCTAssertFalse(MarketDataError.symbolNotFound("AAPL").isRetryable)
        XCTAssertFalse(MarketDataError.invalidResponse.isRetryable)
        XCTAssertFalse(MarketDataError.decodingError("bad json").isRetryable)
    }

    func testErrorEquality() {
        XCTAssertEqual(MarketDataError.rateLimited, MarketDataError.rateLimited)
        XCTAssertEqual(MarketDataError.noAPIKey, MarketDataError.noAPIKey)
        XCTAssertEqual(MarketDataError.networkError("a"), MarketDataError.networkError("a"))
        XCTAssertNotEqual(MarketDataError.networkError("a"), MarketDataError.networkError("b"))
        XCTAssertNotEqual(MarketDataError.rateLimited, MarketDataError.noAPIKey)
    }

    func testErrorDescriptions() {
        XCTAssertNotNil(MarketDataError.noAPIKey.errorDescription)
        XCTAssertNotNil(MarketDataError.rateLimited.errorDescription)
        XCTAssertNotNil(MarketDataError.authenticationFailed.errorDescription)
        XCTAssertNotNil(MarketDataError.decodingError("test").errorDescription)
    }
}

// MARK: - Domain Model Tests

final class ProviderDomainModelTests: XCTestCase {

    func testDateRangeLastDays() {
        let range = DateRange.lastDays(7)
        let diff = Calendar.current.dateComponents([.day], from: range.from, to: range.to).day!
        XCTAssertEqual(diff, 7)
    }

    func testCandleIntervalRawValues() {
        XCTAssertEqual(CandleInterval.fiveMinutes.rawValue, "5min")
        XCTAssertEqual(CandleInterval.daily.rawValue, "1d")
        XCTAssertEqual(CandleInterval.weekly.rawValue, "1w")
    }

    func testProviderIDDisplayNames() {
        XCTAssertEqual(ProviderID.mock.displayName, "Demo Data")
        XCTAssertEqual(ProviderID.finnhub.displayName, "Finnhub")
        XCTAssertEqual(ProviderID.alpaca.displayName, "Alpaca")
        XCTAssertEqual(ProviderID.alphaVantage.displayName, "Alpha Vantage")
        XCTAssertEqual(ProviderID.marketStack.displayName, "MarketStack")
        XCTAssertEqual(ProviderID.eodhd.displayName, "EODHD")
        XCTAssertEqual(ProviderID.massive.displayName, "Massive")
        XCTAssertEqual(ProviderID.dataBento.displayName, "DataBento")
        XCTAssertEqual(ProviderID.thetaData.displayName, "ThetaData")
    }

    func testProviderCapabilitiesNone() {
        let caps = ProviderCapabilities.none
        XCTAssertFalse(caps.supportsRealtimeQuotes)
        XCTAssertFalse(caps.supportsDailyBars)
        XCTAssertFalse(caps.supportsIntradayBars)
        XCTAssertNil(caps.maxSymbolsPerRequest)
    }

    func testProviderCapabilitiesFull() {
        let caps = ProviderCapabilities.full
        XCTAssertTrue(caps.supportsRealtimeQuotes)
        XCTAssertTrue(caps.supportsDailyBars)
        XCTAssertTrue(caps.supportsIntradayBars)
        XCTAssertTrue(caps.supportsCompanyNews)
        XCTAssertTrue(caps.supportsEarningsCalendar)
        XCTAssertTrue(caps.supportsWebSocketStreaming)
        XCTAssertTrue(caps.supportsOptionsData)
    }

    func testProviderHealthFactoryMethods() {
        let healthy = ProviderHealth.healthy(latencyMs: 42)
        XCTAssertEqual(healthy.status, .healthy)
        XCTAssertEqual(healthy.latencyMs, 42)
        XCTAssertNil(healthy.message)

        let error = ProviderHealth.error("timeout")
        XCTAssertEqual(error.status, .error)
        XCTAssertEqual(error.message, "timeout")
        XCTAssertNil(error.latencyMs)

        let noCreds = ProviderHealth.noCredentials()
        XCTAssertEqual(noCreds.status, .noCredentials)
    }

    func testDataModeValues() {
        XCTAssertEqual(DataMode.demo.rawValue, "Demo")
        XCTAssertEqual(DataMode.live.rawValue, "Live")
    }
}
