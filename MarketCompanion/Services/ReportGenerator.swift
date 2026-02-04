// ReportGenerator.swift
// MarketCompanion
//
// Generates morning and close market reports from current data.
// Reports are deterministic analysis (no trading advice).

import Foundation

final class ReportGenerator {
    private let dataProvider: MarketDataProvider
    private let holdingRepo: HoldingRepository
    private let watchItemRepo: WatchItemRepository
    private let quoteRepo: QuoteRepository
    private let dailyBarRepo: DailyBarRepository
    private let tradeRepo: TradeRepository
    private let reportRepo: ReportRepository

    init(
        dataProvider: MarketDataProvider,
        holdingRepo: HoldingRepository,
        watchItemRepo: WatchItemRepository,
        quoteRepo: QuoteRepository,
        dailyBarRepo: DailyBarRepository,
        tradeRepo: TradeRepository,
        reportRepo: ReportRepository
    ) {
        self.dataProvider = dataProvider
        self.holdingRepo = holdingRepo
        self.watchItemRepo = watchItemRepo
        self.quoteRepo = quoteRepo
        self.dailyBarRepo = dailyBarRepo
        self.tradeRepo = tradeRepo
        self.reportRepo = reportRepo
    }

    // MARK: - Generate Morning Report

    func generateMorningReport(mode: ReportMode = .detailed) async throws -> Report {
        let itemLimit = mode == .concise ? 3 : 5
        let holdings = try holdingRepo.all()
        let watchItems = try watchItemRepo.all()
        let allSymbols = Array(Set(holdings.map(\.symbol) + watchItems.map(\.symbol)))

        // Fetch fresh data
        let quotes = try await dataProvider.fetchQuotes(symbols: allSymbols)
        try quoteRepo.upsert(quotes)

        let overview = try await dataProvider.fetchMarketOverview()

        // Build report sections
        var md = ""
        let dateStr = formatReportDate(Date())

        md += "# Morning Briefing\n"
        md += "### \(dateStr)\n\n"
        md += "> What actually matters today\n\n"

        // Market Regime
        md += "## Market Regime\n\n"
        md += "| Metric | Value |\n"
        md += "|--------|-------|\n"
        md += "| Regime | **\(overview.marketRegime)** |\n"
        md += "| VIX Proxy | \(String(format: "%.1f", overview.vixProxy)) (\(overview.volatilityRegime.rawValue)) |\n"
        md += "| Breadth | \(overview.breadthAdvancing) advancing / \(overview.breadthDeclining) declining |\n"
        md += "| Breadth Ratio | \(String(format: "%.0f%%", overview.breadthRatio * 100)) |\n\n"

        // Context insight
        md += contextInsight(overview: overview)

        // Sector Heat
        md += "## Sector Heat\n\n"
        let sortedSectors = overview.sectorPerformance.sorted { $0.changePct > $1.changePct }
        if !sortedSectors.isEmpty {
            md += "| Sector | Change | Leader |\n"
            md += "|--------|--------|--------|\n"
            for sector in sortedSectors.prefix(mode == .concise ? 5 : sortedSectors.count) {
                let arrow = sector.changePct >= 0 ? "+" : ""
                md += "| \(sector.sector) | \(arrow)\(String(format: "%.2f", sector.changePct))% | \(sector.leaderSymbol) (\(arrow)\(String(format: "%.2f", sector.leaderChangePct))%) |\n"
            }
            md += "\n"

            // Rotation analysis (skip in concise mode)
            if mode == .detailed {
                md += rotationAnalysis(sectors: sortedSectors)
            }
        }

        // Holdings in Play
        md += "## Holdings in Play\n\n"
        let holdingQuotes = quotes.filter { q in holdings.contains(where: { $0.symbol == q.symbol }) }
        let flagged = flagHoldings(quotes: holdingQuotes)

        if flagged.isEmpty {
            md += "_No holdings flagged with unusual activity this morning._\n\n"
        } else {
            for (quote, reasons) in flagged.prefix(itemLimit) {
                let arrow = quote.changePct >= 0 ? "+" : ""
                md += "**\(quote.symbol)** \(FormatHelper.price(quote.last)) (\(arrow)\(String(format: "%.2f", quote.changePct))%)\n"
                for reason in reasons {
                    md += "- \(reason)\n"
                }
                md += "\n"
            }
        }

        // Unusual Activity
        md += "## Unusual Activity\n\n"
        let unusual = findUnusualActivity(quotes: quotes)
        if unusual.isEmpty {
            md += "_Nothing unusual detected across your universe._\n\n"
        } else {
            for item in unusual.prefix(itemLimit) {
                md += "- \(item)\n"
            }
            md += "\n"
        }

        // Auto-Watchlist Suggestions
        md += "## Watch Today\n\n"
        let suggestions = generateWatchSuggestions(quotes: quotes, holdings: holdings, watchItems: watchItems, overview: overview)
        if suggestions.isEmpty {
            md += "_No new suggestions._\n\n"
        } else {
            for (symbol, reason) in suggestions.prefix(itemLimit) {
                md += "- **\(symbol)**: \(reason)\n"
            }
            md += "\n"
        }

        // Build payload
        let payload = MorningPayload(
            date: dateStr,
            regime: overview.marketRegime,
            vix: overview.vixProxy,
            breadthAdvancing: overview.breadthAdvancing,
            breadthDeclining: overview.breadthDeclining,
            flaggedCount: flagged.count,
            unusualCount: unusual.count
        )
        let jsonData = try JSONEncoder().encode(payload)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        var report = Report(
            type: .morning,
            jsonPayload: jsonString,
            renderedMarkdown: md
        )
        try reportRepo.save(&report)
        return report
    }

    // MARK: - Generate Close Report

    func generateCloseReport(mode: ReportMode = .detailed) async throws -> Report {
        let itemLimit = mode == .concise ? 3 : 5
        let holdings = try holdingRepo.all()
        let watchItems = try watchItemRepo.all()
        let allSymbols = Array(Set(holdings.map(\.symbol) + watchItems.map(\.symbol)))

        let quotes = try await dataProvider.fetchQuotes(symbols: allSymbols)
        try quoteRepo.upsert(quotes)

        let overview = try await dataProvider.fetchMarketOverview()
        let todayTrades = todaysTrades()

        var md = ""
        let dateStr = formatReportDate(Date())

        md += "# Close Summary\n"
        md += "### \(dateStr)\n\n"
        md += "> What happened today & why\n\n"

        // Market Summary
        md += "## Market Summary\n\n"
        md += "| Metric | Value |\n"
        md += "|--------|-------|\n"
        md += "| Close Regime | **\(overview.marketRegime)** |\n"
        md += "| VIX Proxy | \(String(format: "%.1f", overview.vixProxy)) |\n"
        md += "| Breadth | \(overview.breadthAdvancing)A / \(overview.breadthDeclining)D |\n\n"

        // Sector Rotation
        md += "## Sector Rotation\n\n"
        let sortedSectors = overview.sectorPerformance.sorted { $0.changePct > $1.changePct }
        if !sortedSectors.isEmpty {
            let leaders = sortedSectors.prefix(3)
            let laggards = sortedSectors.suffix(3).reversed()

            md += "**Leading:** "
            md += leaders.map { "\($0.sector) (\(String(format: "%+.2f", $0.changePct))%)" }.joined(separator: ", ")
            md += "\n\n"
            md += "**Lagging:** "
            md += laggards.map { "\($0.sector) (\(String(format: "%+.2f", $0.changePct))%)" }.joined(separator: ", ")
            md += "\n\n"

            if mode == .detailed {
                md += rotationAnalysis(sectors: sortedSectors)
            }
        }

        // Portfolio Attribution
        md += "## Portfolio Attribution\n\n"
        let holdingQuotes = quotes.filter { q in holdings.contains(where: { $0.symbol == q.symbol }) }
        if holdingQuotes.isEmpty {
            md += "_No holdings to analyze._\n\n"
        } else {
            let sorted = holdingQuotes.sorted { $0.changePct > $1.changePct }
            let helped = sorted.filter { $0.changePct > 0.1 }
            let hurt = sorted.filter { $0.changePct < -0.1 }

            if !helped.isEmpty {
                md += "**Helped:**\n"
                for q in helped.prefix(itemLimit) {
                    let holding = holdings.first(where: { $0.symbol == q.symbol })
                    let shareInfo = holding?.shares.map { " (\(Int($0)) shares)" } ?? ""
                    md += "- \(q.symbol)\(shareInfo): \(String(format: "%+.2f", q.changePct))%\n"
                }
                md += "\n"
            }

            if !hurt.isEmpty {
                md += "**Hurt:**\n"
                for q in hurt.suffix(itemLimit).reversed() {
                    let holding = holdings.first(where: { $0.symbol == q.symbol })
                    let shareInfo = holding?.shares.map { " (\(Int($0)) shares)" } ?? ""
                    md += "- \(q.symbol)\(shareInfo): \(String(format: "%+.2f", q.changePct))%\n"
                }
                md += "\n"
            }

            let avgChange = holdingQuotes.map(\.changePct).reduce(0, +) / Double(holdingQuotes.count)
            md += "**Average holding change:** \(String(format: "%+.2f", avgChange))%\n\n"
        }

        // Today's Trades
        if !todayTrades.isEmpty {
            md += "## Today's Trades\n\n"
            var totalPnl = 0.0
            for trade in todayTrades {
                let pnlStr = trade.pnl.map { FormatHelper.pnl($0) } ?? "Open"
                md += "- \(trade.symbol) \(trade.side.rawValue.uppercased()) \(Int(trade.qty)) @ \(FormatHelper.price(trade.entryPrice)) → \(pnlStr)\n"
                totalPnl += trade.pnl ?? 0
            }
            if todayTrades.contains(where: { $0.isClosed }) {
                md += "\n**Net P&L:** \(FormatHelper.pnl(totalPnl))\n"
            }
            md += "\n"

            // Strategy insight from journal
            md += journalInsight(trades: todayTrades)
        }

        // Tomorrow Prep
        md += "## Tomorrow Prep\n\n"
        md += "### Watchlist\n"
        let topMovers = quotes.sorted { abs($0.changePct) > abs($1.changePct) }.prefix(itemLimit)
        for q in topMovers {
            md += "- **\(q.symbol)** — closed at \(FormatHelper.price(q.last)) (\(String(format: "%+.2f", q.changePct))%)\n"
        }
        md += "\n"

        if mode == .detailed {
            md += "### Key Levels\n"
            for q in holdingQuotes.prefix(itemLimit) {
                let pivot = (q.dayHigh + q.dayLow + q.last) / 3
                md += "- **\(q.symbol)**: Pivot \(FormatHelper.price(pivot)) | R1 \(FormatHelper.price(2 * pivot - q.dayLow)) | S1 \(FormatHelper.price(2 * pivot - q.dayHigh))\n"
            }
            md += "\n"
        }

        md += "### Upcoming\n"
        md += "- _Check earnings calendar for tomorrow_\n"
        md += "- _Review any macro data releases_\n\n"

        // Build payload
        let payload = ClosePayload(
            date: dateStr,
            regime: overview.marketRegime,
            avgHoldingChange: holdingQuotes.isEmpty ? 0 : holdingQuotes.map(\.changePct).reduce(0, +) / Double(holdingQuotes.count),
            tradesCount: todayTrades.count,
            netPnl: todayTrades.compactMap(\.pnl).reduce(0, +)
        )
        let jsonData = try JSONEncoder().encode(payload)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        var report = Report(
            type: .close,
            jsonPayload: jsonString,
            renderedMarkdown: md
        )
        try reportRepo.save(&report)
        return report
    }

    // MARK: - Analysis Helpers

    private func flagHoldings(quotes: [Quote]) -> [(Quote, [String])] {
        var flagged: [(Quote, [String])] = []
        for quote in quotes {
            var reasons: [String] = []

            if quote.volumeRatio > 1.5 {
                reasons.append("Volume \(String(format: "%.1f", quote.volumeRatio))x above average")
            }
            if abs(quote.changePct) > 2.0 {
                let direction = quote.changePct > 0 ? "up" : "down"
                reasons.append("Moving \(direction) \(String(format: "%.1f", abs(quote.changePct)))% pre-market/early")
            }
            if quote.intradayRange > 3.0 {
                reasons.append("Wide intraday range (\(String(format: "%.1f", quote.intradayRange))%)")
            }

            // Check historical behavior
            if let bars = try? dailyBarRepo.forSymbol(quote.symbol, limit: 20), bars.count >= 10 {
                let avgRange = bars.map { ($0.high - $0.low) / $0.low * 100 }.reduce(0, +) / Double(bars.count)
                if quote.intradayRange > avgRange * 1.5 {
                    reasons.append("Behaving differently than its usual pattern (range \(String(format: "%.1f", quote.intradayRange / avgRange))x typical)")
                }
            }

            if !reasons.isEmpty {
                flagged.append((quote, reasons))
            }
        }
        return flagged.sorted { $0.1.count > $1.1.count }
    }

    private func findUnusualActivity(quotes: [Quote]) -> [String] {
        var items: [String] = []

        for quote in quotes {
            if quote.volumeRatio > 2.5 {
                items.append("**\(quote.symbol)** volume spike: \(String(format: "%.1f", quote.volumeRatio))x average (\(FormatHelper.volume(quote.volume)))")
            }
            if abs(quote.changePct) > 3.0 {
                let direction = quote.changePct > 0 ? "surging" : "dropping"
                items.append("**\(quote.symbol)** \(direction) \(String(format: "%.1f", abs(quote.changePct)))%")
            }
        }

        return items
    }

    private func generateWatchSuggestions(quotes: [Quote], holdings: [Holding], watchItems: [WatchItem], overview: MarketOverview) -> [(String, String)] {
        var suggestions: [(String, String)] = []
        let existingSymbols = Set(holdings.map(\.symbol) + watchItems.map(\.symbol))

        // Find sector leaders not in portfolio
        for sector in overview.sectorPerformance where sector.changePct > 1.0 {
            if !existingSymbols.contains(sector.leaderSymbol) {
                suggestions.append((sector.leaderSymbol, "Leading \(sector.sector) sector (\(String(format: "%+.2f", sector.leaderChangePct))%)"))
            }
        }

        // High volume movers
        for quote in quotes where quote.volumeRatio > 2.0 && abs(quote.changePct) > 1.5 {
            let direction = quote.changePct > 0 ? "bullish" : "bearish"
            suggestions.append((quote.symbol, "Unusual volume + \(direction) momentum"))
        }

        return Array(suggestions.prefix(5))
    }

    private func contextInsight(overview: MarketOverview) -> String {
        var md = ""

        if overview.volatilityRegime == .high || overview.volatilityRegime == .elevated {
            md += "> **Context:** Elevated volatility environment. Historically, high-volatility mornings tend to see wider ranges and more reversals. Position sizing and stops deserve extra attention.\n\n"
        } else if overview.breadthRatio > 0.7 {
            md += "> **Context:** Broad participation across sectors. When breadth is this strong, individual stock moves tend to be more sustainable.\n\n"
        } else if overview.breadthRatio < 0.3 {
            md += "> **Context:** Weak breadth — most stocks declining. Historically, narrow selling often precedes either capitulation bounces or further deterioration. Defensive positioning has been common in these conditions.\n\n"
        }

        return md
    }

    private func rotationAnalysis(sectors: [SectorPerformance]) -> String {
        guard sectors.count >= 3 else { return "" }

        var md = ""
        let defensive = ["Utilities", "Healthcare", "Consumer"]
        let cyclical = ["Technology", "Financials", "Industrials", "Energy"]

        let defensiveAvg = sectors.filter { defensive.contains($0.sector) }.map(\.changePct).reduce(0, +) / max(1, Double(sectors.filter { defensive.contains($0.sector) }.count))
        let cyclicalAvg = sectors.filter { cyclical.contains($0.sector) }.map(\.changePct).reduce(0, +) / max(1, Double(sectors.filter { cyclical.contains($0.sector) }.count))

        if cyclicalAvg > defensiveAvg + 0.5 {
            md += "> **Rotation:** Money flowing into cyclical/growth sectors over defensives — a risk-on signal.\n\n"
        } else if defensiveAvg > cyclicalAvg + 0.5 {
            md += "> **Rotation:** Defensive sectors outperforming — a flight-to-safety signal.\n\n"
        } else {
            md += "> **Rotation:** No clear directional rotation today. Sector performance is mixed.\n\n"
        }

        return md
    }

    private func journalInsight(trades: [Trade]) -> String {
        guard !trades.isEmpty else { return "" }

        var md = ""
        let calendar = Calendar.current
        let closedToday = trades.filter { $0.isClosed }

        if !closedToday.isEmpty {
            let wins = closedToday.filter { ($0.pnl ?? 0) > 0 }.count
            let rate = Double(wins) / Double(closedToday.count) * 100
            md += "> **Journal note:** \(closedToday.count) trades closed today (\(Int(rate))% win rate)."

            // Check time patterns
            let allTrades = (try? tradeRepo.all()) ?? []
            let recentClosed = allTrades.filter { $0.isClosed }
            if recentClosed.count >= 5 {
                let morningTrades = recentClosed.filter { calendar.component(.hour, from: $0.entryTime) < 11 }
                let morningWins = morningTrades.filter { ($0.pnl ?? 0) > 0 }.count
                let morningRate = morningTrades.isEmpty ? 0 : Double(morningWins) / Double(morningTrades.count)
                if morningRate > 0.6 {
                    md += " Your morning trades have been stronger lately (\(Int(morningRate * 100))% win rate)."
                }
            }
            md += "\n\n"
        }

        return md
    }

    private func todaysTrades() -> [Trade] {
        let calendar = Calendar.current
        let allTrades = (try? tradeRepo.all()) ?? []
        return allTrades.filter { calendar.isDateInToday($0.entryTime) }
    }

    // MARK: - Formatting

    private func formatReportDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: date)
    }
}

// MARK: - Report Payloads

struct MorningPayload: Codable {
    let date: String
    let regime: String
    let vix: Double
    let breadthAdvancing: Int
    let breadthDeclining: Int
    let flaggedCount: Int
    let unusualCount: Int
}

struct ClosePayload: Codable {
    let date: String
    let regime: String
    let avgHoldingChange: Double
    let tradesCount: Int
    let netPnl: Double
}
