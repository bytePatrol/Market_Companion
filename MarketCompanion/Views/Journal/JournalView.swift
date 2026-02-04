// JournalView.swift
// MarketCompanion

import SwiftUI

struct JournalView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var showImport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .top) {
                    PageHeader(title: "Journal", subtitle: "Trade history & insights")
                    Spacer()
                    Button {
                        showImport = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                            .font(AppFont.subheadline())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Import trades from a CSV file")
                    Button {
                        appState.showTradeEntry = true
                    } label: {
                        Label("Log Trade", systemImage: "plus")
                            .font(AppFont.subheadline())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Manually record a new trade entry")
                }

                Picker("View", selection: $selectedTab) {
                    Text("Open (\(openTrades.count))").tag(0)
                    Text("Closed (\(closedTrades.count))").tag(1)
                    Text("Insights").tag(2)
                    Text("Performance").tag(3)
                    Text("Calendar").tag(4)
                }
                .pickerStyle(.segmented)
                .frame(width: 520)
                .help("Switch between open trades, closed trades, insights, performance, and calendar")

                if selectedTab == 0 {
                    openTradesSection
                } else if selectedTab == 1 {
                    closedTradesSection
                } else if selectedTab == 2 {
                    insightsSection
                } else if selectedTab == 3 {
                    performanceSection
                } else {
                    JournalCalendarView()
                }
            }
            .padding(Spacing.lg)
        }
        .sheet(isPresented: $showImport) {
            TradeImportSheet()
                .environmentObject(appState)
        }
    }

    private var openTrades: [Trade] {
        appState.trades.filter { !$0.isClosed }
    }

    private var closedTrades: [Trade] {
        appState.trades.filter { $0.isClosed }
    }

    // MARK: - Open Trades

    private var openTradesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if openTrades.isEmpty {
                EmptyStateView(
                    icon: "rectangle.stack",
                    title: "No Open Trades",
                    message: "Log a trade to start building your journal.",
                    actionTitle: "Log Trade"
                ) {
                    appState.showTradeEntry = true
                }
                .frame(height: 250)
            } else {
                ForEach(openTrades) { trade in
                    tradeRow(trade, showClose: true)
                }
            }
        }
    }

    // MARK: - Closed Trades

    private var closedTradesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if closedTrades.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "No Closed Trades",
                    message: "Completed trades will appear here with P&L analysis.",
                    actionTitle: "Log Trade"
                ) {
                    appState.showTradeEntry = true
                }
                .frame(height: 250)
            } else {
                // Summary
                if !closedTrades.isEmpty {
                    tradesSummary
                }

                ForEach(closedTrades) { trade in
                    tradeRow(trade, showClose: false)
                }
            }
        }
    }

    private var tradesSummary: some View {
        let totalPnl = closedTrades.compactMap(\.pnl).reduce(0, +)
        let winCount = closedTrades.filter { ($0.pnl ?? 0) > 0 }.count
        let winRate = closedTrades.isEmpty ? 0 : Double(winCount) / Double(closedTrades.count) * 100

        return HStack(spacing: Spacing.md) {
            MetricCard(
                title: "Total P&L",
                value: FormatHelper.pnl(totalPnl),
                icon: "dollarsign.circle.fill",
                iconColor: totalPnl >= 0 ? .gainGreen : .lossRed,
                trend: totalPnl
            )

            MetricCard(
                title: "Win Rate",
                value: String(format: "%.0f%%", winRate),
                subtitle: "\(winCount)/\(closedTrades.count) trades",
                icon: "target",
                iconColor: winRate >= 50 ? .gainGreen : .lossRed
            )

            MetricCard(
                title: "Trades",
                value: "\(closedTrades.count)",
                subtitle: "completed",
                icon: "arrow.left.arrow.right",
                iconColor: .infoBlue
            )
        }
    }

    // MARK: - Trade Row

    private func tradeRow(_ trade: Trade, showClose: Bool) -> some View {
        CardView(padding: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(trade.symbol)
                        .font(AppFont.symbol())
                    TagPill(
                        text: trade.side.rawValue.uppercased(),
                        color: trade.side == .long ? .gainGreen : .lossRed,
                        style: .filled
                    )
                    Spacer()

                    if let pnl = trade.pnl {
                        Text(FormatHelper.pnl(pnl))
                            .font(AppFont.price())
                            .foregroundStyle(Color.forChange(pnl))
                    }
                }

                HStack(spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Entry")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                        Text(FormatHelper.price(trade.entryPrice))
                            .font(AppFont.mono())
                    }

                    if let exit = trade.exitPrice {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exit")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textTertiary)
                            Text(FormatHelper.price(exit))
                                .font(AppFont.mono())
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Qty")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                        Text("\(Int(trade.qty))")
                            .font(AppFont.mono())
                    }

                    Spacer()

                    Text(FormatHelper.fullDate(trade.entryTime))
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textTertiary)
                }

                if !trade.notes.isEmpty {
                    Text(trade.notes)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)
                        .padding(.top, 2)
                }

                if !trade.tagList.isEmpty {
                    HStack(spacing: Spacing.xxs) {
                        ForEach(trade.tagList, id: \.self) { tag in
                            TagPill(text: tag, style: .subtle)
                        }
                    }
                }

                if showClose && !trade.isClosed {
                    CloseTradeButton(trade: trade)
                        .environmentObject(appState)
                }
            }
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Trading Insights", subtitle: "From your history", icon: "lightbulb.fill")

            if closedTrades.count < 3 {
                CardView {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.textTertiary)
                        Text("Need more data")
                            .font(AppFont.headline())
                        Text("Log at least 3 closed trades to see insights about your trading patterns.")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.lg)
                }
            } else {
                insightCards
            }
        }
    }

    private var insightCards: some View {
        let trades = closedTrades

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            // Best time of day
            insightCard(
                icon: "clock.fill",
                title: "Time of Day",
                insight: timeOfDayInsight(trades)
            )

            // Best side
            insightCard(
                icon: "arrow.left.arrow.right",
                title: "Direction Bias",
                insight: directionInsight(trades)
            )

            // Holding period
            insightCard(
                icon: "hourglass",
                title: "Holding Period",
                insight: holdingPeriodInsight(trades)
            )

            // Best symbols
            insightCard(
                icon: "star.fill",
                title: "Best Symbols",
                insight: bestSymbolsInsight(trades)
            )

            // Current streak
            insightCard(
                icon: "flame.fill",
                title: "Streak",
                insight: streakInsight(trades)
            )

            // Volatility regime performance
            insightCard(
                icon: "waveform.path.ecg",
                title: "Volatility & You",
                insight: volatilityInsight(trades)
            )

            // Tag analytics
            tagBreakdownCard(trades)
            bestWorstSetupCard(trades)

            // Export
            HStack {
                Spacer()
                Button {
                    exportTradeHistory()
                } label: {
                    Label("Export Trade History", systemImage: "square.and.arrow.up")
                        .font(AppFont.subheadline())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Export all trades as a CSV file")
                Spacer()
            }
            .padding(.top, Spacing.xs)
        }
    }

    private func tagBreakdownCard(_ trades: [Trade]) -> some View {
        let tagData = PerformanceAnalytics.byTag(from: trades)

        return Group {
            if !tagData.isEmpty {
                insightCard(
                    icon: "tag.fill",
                    title: "By Setup",
                    insight: ""
                )
                .overlay {
                    // Replace with full table content
                    Color.clear
                }

                CardView(padding: Spacing.sm) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 28)
                            Text("By Setup")
                                .font(AppFont.subheadline())
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                        }

                        // Table header
                        HStack {
                            Text("Tag").font(AppFont.caption()).frame(width: 100, alignment: .leading)
                            Text("Trades").font(AppFont.caption()).frame(width: 50, alignment: .trailing)
                            Text("Win %").font(AppFont.caption()).frame(width: 55, alignment: .trailing)
                            Text("Avg P&L").font(AppFont.caption()).frame(width: 80, alignment: .trailing)
                            Text("Total P&L").font(AppFont.caption()).frame(width: 80, alignment: .trailing)
                        }
                        .foregroundStyle(Color.textTertiary)

                        Divider()

                        ForEach(tagData, id: \.tag) { item in
                            HStack {
                                Text(item.tag)
                                    .font(AppFont.mono())
                                    .frame(width: 100, alignment: .leading)
                                    .lineLimit(1)
                                Text("\(item.metrics.tradeCount)")
                                    .font(AppFont.mono())
                                    .frame(width: 50, alignment: .trailing)
                                Text(String(format: "%.0f%%", item.metrics.winRate))
                                    .font(AppFont.mono())
                                    .frame(width: 55, alignment: .trailing)
                                    .foregroundStyle(item.metrics.winRate >= 50 ? Color.gainGreen : Color.lossRed)
                                Text(FormatHelper.pnl(item.metrics.expectancy))
                                    .font(AppFont.mono())
                                    .frame(width: 80, alignment: .trailing)
                                    .foregroundStyle(Color.forChange(item.metrics.expectancy))
                                Text(FormatHelper.pnl(item.metrics.totalPnl))
                                    .font(AppFont.mono())
                                    .frame(width: 80, alignment: .trailing)
                                    .foregroundStyle(Color.forChange(item.metrics.totalPnl))
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }
            }
        }
    }

    private func bestWorstSetupCard(_ trades: [Trade]) -> some View {
        let tagData = PerformanceAnalytics.byTag(from: trades)
            .filter { $0.metrics.tradeCount >= 3 }

        let best = tagData.max(by: { $0.metrics.winRate < $1.metrics.winRate })
        let worst = tagData.min(by: { $0.metrics.winRate < $1.metrics.winRate })

        return Group {
            if let best, let worst, best.tag != worst.tag {
                insightCard(
                    icon: "medal.fill",
                    title: "Best & Worst Setup",
                    insight: "Your '\(best.tag)' trades win \(Int(best.metrics.winRate))% — consider sizing up. Your '\(worst.tag)' trades win \(Int(worst.metrics.winRate))% — review your criteria."
                )
            } else if let best {
                insightCard(
                    icon: "medal.fill",
                    title: "Best Setup",
                    insight: "Your '\(best.tag)' trades win \(Int(best.metrics.winRate))% across \(best.metrics.tradeCount) trades."
                )
            }
        }
    }

    private func insightCard(icon: String, title: String, insight: String) -> some View {
        CardView(padding: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.subheadline())
                        .foregroundStyle(Color.textPrimary)
                    Text(insight)
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Performance

    private var performanceSection: some View {
        let metrics = PerformanceAnalytics.compute(from: appState.trades)
        let curve = PerformanceAnalytics.equityCurve(from: appState.trades)
        let drawdowns = PerformanceAnalytics.drawdownSeries(from: appState.trades)
        let monthly = PerformanceAnalytics.monthlyPnl(from: appState.trades)

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Performance Analytics", subtitle: "\(metrics.tradeCount) closed trades", icon: "chart.line.uptrend.xyaxis")

            if metrics.tradeCount < 2 {
                CardView {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.textTertiary)
                        Text("Need more data")
                            .font(AppFont.headline())
                        Text("Close at least 2 trades to see performance metrics.")
                            .font(AppFont.body())
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.lg)
                }
            } else {
                // Metric cards
                HStack(spacing: Spacing.md) {
                    MetricCard(
                        title: "Profit Factor",
                        value: metrics.profitFactor.isInfinite ? "∞" : String(format: "%.2f", metrics.profitFactor),
                        icon: "arrow.up.arrow.down",
                        iconColor: metrics.profitFactor >= 1.5 ? .gainGreen : .lossRed
                    )
                    MetricCard(
                        title: "Sharpe",
                        value: String(format: "%.2f", metrics.sharpeRatio),
                        icon: "chart.bar.xaxis",
                        iconColor: metrics.sharpeRatio >= 1 ? .gainGreen : .warningAmber
                    )
                    MetricCard(
                        title: "Max Drawdown",
                        value: FormatHelper.pnl(-metrics.maxDrawdown),
                        subtitle: String(format: "%.1f%%", metrics.maxDrawdownPercent),
                        icon: "arrow.down.right",
                        iconColor: .lossRed
                    )
                    MetricCard(
                        title: "Expectancy",
                        value: FormatHelper.pnl(metrics.expectancy),
                        icon: "target",
                        iconColor: metrics.expectancy > 0 ? .gainGreen : .lossRed
                    )
                }

                // Additional stats
                HStack(spacing: Spacing.md) {
                    MetricCard(
                        title: "Avg Win",
                        value: FormatHelper.pnl(metrics.averageWin),
                        icon: "arrow.up",
                        iconColor: .gainGreen
                    )
                    MetricCard(
                        title: "Avg Loss",
                        value: FormatHelper.pnl(-metrics.averageLoss),
                        icon: "arrow.down",
                        iconColor: .lossRed
                    )
                    MetricCard(
                        title: "Best Streak",
                        value: "\(metrics.consecutiveWins)W / \(metrics.consecutiveLosses)L",
                        icon: "flame.fill",
                        iconColor: .warningAmber
                    )
                    MetricCard(
                        title: "Win Rate",
                        value: String(format: "%.0f%%", metrics.winRate),
                        subtitle: "\(metrics.winCount)/\(metrics.tradeCount)",
                        icon: "target",
                        iconColor: metrics.winRate >= 50 ? .gainGreen : .lossRed
                    )
                }

                // Equity curve
                CardView {
                    EquityCurveView(curve: curve, drawdowns: drawdowns)
                }

                // Monthly P&L grid
                CardView {
                    MonthlyPnlGrid(monthlyData: monthly)
                }

                // P&L distribution
                CardView {
                    PnlDistributionView(trades: appState.trades)
                }
            }
        }
    }

    // MARK: - Insight Calculations

    private func timeOfDayInsight(_ trades: [Trade]) -> String {
        let calendar = Calendar.current
        let morningTrades = trades.filter { calendar.component(.hour, from: $0.entryTime) < 12 }
        let afternoonTrades = trades.filter { calendar.component(.hour, from: $0.entryTime) >= 12 }

        let morningWins = morningTrades.filter { ($0.pnl ?? 0) > 0 }.count
        let afternoonWins = afternoonTrades.filter { ($0.pnl ?? 0) > 0 }.count

        let morningRate = morningTrades.isEmpty ? 0 : Double(morningWins) / Double(morningTrades.count)
        let afternoonRate = afternoonTrades.isEmpty ? 0 : Double(afternoonWins) / Double(afternoonTrades.count)

        if morningRate > afternoonRate + 0.1 {
            return "You tend to perform better in the morning session (\(Int(morningRate * 100))% vs \(Int(afternoonRate * 100))% win rate)."
        } else if afternoonRate > morningRate + 0.1 {
            return "You tend to perform better in the afternoon session (\(Int(afternoonRate * 100))% vs \(Int(morningRate * 100))% win rate)."
        } else {
            return "Your performance is consistent across morning and afternoon sessions."
        }
    }

    private func directionInsight(_ trades: [Trade]) -> String {
        let longs = trades.filter { $0.side == .long }
        let shorts = trades.filter { $0.side == .short }

        let longWinRate = longs.isEmpty ? 0 : Double(longs.filter { ($0.pnl ?? 0) > 0 }.count) / Double(longs.count) * 100
        let shortWinRate = shorts.isEmpty ? 0 : Double(shorts.filter { ($0.pnl ?? 0) > 0 }.count) / Double(shorts.count) * 100

        if shorts.isEmpty {
            return "You primarily trade long positions (\(longs.count) trades, \(Int(longWinRate))% win rate)."
        } else if longs.isEmpty {
            return "You primarily trade short positions (\(shorts.count) trades, \(Int(shortWinRate))% win rate)."
        } else {
            return "Long: \(Int(longWinRate))% win rate (\(longs.count) trades). Short: \(Int(shortWinRate))% win rate (\(shorts.count) trades)."
        }
    }

    private func holdingPeriodInsight(_ trades: [Trade]) -> String {
        let durations = trades.compactMap { trade -> TimeInterval? in
            guard let exit = trade.exitTime else { return nil }
            return exit.timeIntervalSince(trade.entryTime)
        }
        guard !durations.isEmpty else { return "Not enough data to analyze holding periods." }

        let avgMinutes = durations.reduce(0, +) / Double(durations.count) / 60

        if avgMinutes < 60 {
            return "Your average holding period is \(Int(avgMinutes)) minutes. You tend toward quick scalps."
        } else if avgMinutes < 1440 {
            return "Your average holding period is \(String(format: "%.1f", avgMinutes / 60)) hours. You trade within the day."
        } else {
            return "Your average holding period is \(String(format: "%.1f", avgMinutes / 1440)) days. You favor swing positions."
        }
    }

    private func bestSymbolsInsight(_ trades: [Trade]) -> String {
        let grouped = Dictionary(grouping: trades, by: \.symbol)
        let symbolStats = grouped.map { symbol, trades -> (String, Double, Int) in
            let totalPnl = trades.compactMap(\.pnl).reduce(0, +)
            return (symbol, totalPnl, trades.count)
        }
        .sorted { $0.1 > $1.1 }

        guard let best = symbolStats.first else {
            return "Not enough data."
        }

        var result = "Your best symbol is \(best.0) (\(FormatHelper.pnl(best.1)) across \(best.2) trades)."

        if symbolStats.count > 1, let worst = symbolStats.last, worst.1 < 0 {
            result += " Your weakest is \(worst.0) (\(FormatHelper.pnl(worst.1)))."
        }

        return result
    }

    private func streakInsight(_ trades: [Trade]) -> String {
        let sorted = trades.sorted { $0.exitTime ?? $0.entryTime < $1.exitTime ?? $1.entryTime }

        var currentStreak = 0
        var streakType = ""

        for trade in sorted.reversed() {
            let isWin = (trade.pnl ?? 0) > 0
            let type = isWin ? "win" : "loss"

            if currentStreak == 0 {
                streakType = type
                currentStreak = 1
            } else if type == streakType {
                currentStreak += 1
            } else {
                break
            }
        }

        if currentStreak >= 3 {
            if streakType == "win" {
                return "You're on a \(currentStreak)-trade winning streak. Stay disciplined."
            } else {
                return "You've had \(currentStreak) consecutive losses. Consider stepping back to review your approach."
            }
        } else if currentStreak > 0 {
            return "Current streak: \(currentStreak) \(streakType)(s). No strong pattern right now."
        }

        return "Not enough recent trades to identify a streak."
    }

    private func volatilityInsight(_ trades: [Trade]) -> String {
        // Get trade contexts
        var highVolTrades: [Trade] = []
        var lowVolTrades: [Trade] = []

        for trade in trades {
            if let tradeId = trade.id,
               let context = try? appState.tradeContextRepo.forTrade(tradeId) {
                if context.volatilityRegime == "High" || context.volatilityRegime == "Elevated" {
                    highVolTrades.append(trade)
                } else {
                    lowVolTrades.append(trade)
                }
            }
        }

        if highVolTrades.isEmpty && lowVolTrades.isEmpty {
            return "Context data not yet available. New trades will auto-capture volatility regime."
        }

        let highWins = highVolTrades.filter { ($0.pnl ?? 0) > 0 }.count
        let lowWins = lowVolTrades.filter { ($0.pnl ?? 0) > 0 }.count
        let highRate = highVolTrades.isEmpty ? 0.0 : Double(highWins) / Double(highVolTrades.count) * 100
        let lowRate = lowVolTrades.isEmpty ? 0.0 : Double(lowWins) / Double(lowVolTrades.count) * 100

        if highVolTrades.count >= 2 && lowVolTrades.count >= 2 {
            if lowRate > highRate + 10 {
                return "You perform better in low-volatility environments (\(Int(lowRate))% vs \(Int(highRate))% win rate). Consider reducing size on high-vol days."
            } else if highRate > lowRate + 10 {
                return "You actually thrive in elevated volatility (\(Int(highRate))% win rate vs \(Int(lowRate))% in calm markets)."
            } else {
                return "Your performance is similar across volatility regimes (\(Int(highRate))% high-vol vs \(Int(lowRate))% low-vol)."
            }
        }

        return "Building volatility data. \(highVolTrades.count) high-vol and \(lowVolTrades.count) low-vol trades so far."
    }

    // MARK: - Export

    private func exportTradeHistory() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "trade_history_\(FormatHelper.shortDate(Date())).csv"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let csv = self.buildCSV()
                try? csv.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func buildCSV() -> String {
        var csv = "Symbol,Side,Qty,Entry Price,Exit Price,Entry Time,Exit Time,P&L,P&L %,Notes,Tags\n"

        for trade in appState.trades {
            let exit = trade.exitPrice.map { String($0) } ?? ""
            let exitTime = trade.exitTime.map { FormatHelper.fullDate($0) } ?? ""
            let pnl = trade.pnl.map { String(format: "%.2f", $0) } ?? ""
            let pnlPct = trade.pnlPercent.map { String(format: "%.2f", $0) } ?? ""
            let notes = trade.notes.replacingOccurrences(of: ",", with: ";")

            csv += "\(trade.symbol),\(trade.side.rawValue),\(trade.qty),\(trade.entryPrice),\(exit),\(FormatHelper.fullDate(trade.entryTime)),\(exitTime),\(pnl),\(pnlPct),\(notes),\(trade.tags)\n"
        }

        return csv
    }
}

// MARK: - Close Trade Button

struct CloseTradeButton: View {
    @EnvironmentObject var appState: AppState
    let trade: Trade
    @State private var showClose = false
    @State private var exitPrice = ""

    var body: some View {
        if showClose {
            HStack(spacing: Spacing.xs) {
                TextField("Exit price", text: $exitPrice)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Button("Close") {
                    if let id = trade.id, let price = Double(exitPrice) {
                        appState.closeTrade(id: id, exitPrice: price)
                        showClose = false
                    }
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                Button("Cancel") { showClose = false }
                    .controlSize(.small)
            }
            .padding(.top, Spacing.xxs)
        } else {
            Button("Close Trade") {
                showClose = true
            }
            .font(AppFont.caption())
            .controlSize(.small)
            .padding(.top, Spacing.xxs)
            .help("Enter an exit price to close this trade and calculate P&L")
        }
    }
}

// MARK: - Trade Entry Sheet

struct TradeEntrySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var symbol = ""
    @State private var side: TradeSide = .long
    @State private var qty = ""
    @State private var entryPrice = ""
    @State private var notes = ""
    @State private var tags = ""
    @State private var showChecklist = false
    @State private var checklist = PreTradeChecklist()
    @State private var showPositionSizer = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                HStack {
                    Text("Log Trade")
                        .font(AppFont.title())
                    Spacer()
                    if let overview = appState.marketOverview {
                        RegimeBadge(regime: overview.marketRegime)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        TextField("Symbol", text: $symbol)
                            .textFieldStyle(.roundedBorder)
                            .help("Ticker symbol for this trade")

                        Picker("Side", selection: $side) {
                            Text("Long").tag(TradeSide.long)
                            Text("Short").tag(TradeSide.short)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }

                    HStack(spacing: Spacing.sm) {
                        TextField("Quantity", text: $qty)
                            .textFieldStyle(.roundedBorder)
                            .help("Number of shares")

                        Button("Size it") {
                            showPositionSizer = true
                        }
                        .controlSize(.small)
                        .font(AppFont.caption())
                        .help("Open the position size calculator")

                        TextField("Entry Price", text: $entryPrice)
                            .textFieldStyle(.roundedBorder)
                            .help("Price per share at entry")
                    }

                    TextField("Notes (optional)", text: $notes)
                        .textFieldStyle(.roundedBorder)
                        .help("Optional notes about your trade thesis")

                    TextField("Tags (comma-separated, optional)", text: $tags)
                        .textFieldStyle(.roundedBorder)
                        .help("Comma-separated labels, e.g. momentum, earnings")
                }

                // Context snapshot preview
                if let overview = appState.marketOverview {
                    CardView(padding: Spacing.sm) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Auto-captured context")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textTertiary)
                            HStack(spacing: Spacing.sm) {
                                Label("VIX: \(String(format: "%.1f", overview.vixProxy))", systemImage: "waveform.path.ecg")
                                Label("Breadth: \(overview.breadthAdvancing)/\(overview.breadthDeclining)", systemImage: "chart.bar")
                                Label(overview.volatilityRegime.rawValue, systemImage: "gauge.medium")
                            }
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)
                        }
                    }
                }

                // Pre-trade checklist
                DisclosureGroup("Pre-Trade Checklist", isExpanded: $showChecklist) {
                    PreTradeChecklistView(checklist: $checklist)
                        .padding(.top, Spacing.xs)
                }
                .font(AppFont.subheadline())
                .help("Optional checklist to review before entering the trade")

                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Log Trade") {
                        guard let q = Double(qty), let price = Double(entryPrice) else { return }
                        checklist.symbol = symbol
                        checklist.side = side.rawValue
                        appState.logTrade(
                            symbol: symbol,
                            side: side,
                            qty: q,
                            entryPrice: price,
                            notes: notes,
                            tags: tags,
                            checklistJson: checklist.json
                        )
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(symbol.isEmpty || qty.isEmpty || entryPrice.isEmpty)
                }
            }
            .padding(Spacing.xl)
        }
        .frame(width: 500, height: 700)
        .popover(isPresented: $showPositionSizer) {
            PositionSizeCalculator { confirmedQty in
                qty = "\(Int(confirmedQty))"
            }
        }
    }
}
