// HelpView.swift
// MarketCompanion
//
// Full-featured help window with sidebar topic navigation and scrollable detail content.

import SwiftUI

// MARK: - Help Topic

enum HelpTopic: String, CaseIterable, Identifiable {
    case gettingStarted = "Getting Started"
    case dashboard = "Dashboard"
    case heatmap = "Heatmap"
    case chart = "Chart"
    case portfolioRisk = "Portfolio Risk"
    case watchlist = "Watchlist"
    case alerts = "Alerts"
    case screener = "Screener"
    case research = "Research"
    case journal = "Journal"
    case reports = "Reports"
    case replay = "Replay"
    case companion = "Companion Window"
    case dataProviders = "Data Providers"
    case settings = "Settings"
    case shortcuts = "Keyboard Shortcuts"
    case indicators = "Technical Indicators"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gettingStarted: return "star.fill"
        case .dashboard: return "square.grid.2x2"
        case .heatmap: return "square.grid.3x3.fill"
        case .chart: return "chart.xyaxis.line"
        case .portfolioRisk: return "chart.pie"
        case .watchlist: return "eye"
        case .alerts: return "bell.badge"
        case .screener: return "magnifyingglass"
        case .research: return "newspaper"
        case .journal: return "book"
        case .reports: return "doc.text"
        case .replay: return "clock.arrow.circlepath"
        case .companion: return "sidebar.right"
        case .dataProviders: return "externaldrive.connected.to.line.below"
        case .settings: return "gearshape"
        case .shortcuts: return "keyboard"
        case .indicators: return "waveform.path.ecg"
        }
    }
}

// MARK: - Help View

struct HelpView: View {
    @State private var selectedTopic: HelpTopic = .gettingStarted
    @State private var searchText = ""

    private var filteredTopics: [HelpTopic] {
        if searchText.isEmpty { return HelpTopic.allCases }
        return HelpTopic.allCases.filter { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // Search
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                    TextField("Search topics", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(AppFont.body())
                }
                .padding(Spacing.sm)

                SubtleDivider()

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(filteredTopics) { topic in
                            Button {
                                selectedTopic = topic
                            } label: {
                                HStack(spacing: Spacing.xs) {
                                    Image(systemName: topic.icon)
                                        .font(.system(size: 11))
                                        .foregroundStyle(selectedTopic == topic ? Color.accentColor : Color.textTertiary)
                                        .frame(width: 18)
                                    Text(topic.rawValue)
                                        .font(AppFont.subheadline())
                                        .foregroundStyle(selectedTopic == topic ? Color.accentColor : Color.textPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .background {
                                    if selectedTopic == topic {
                                        RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                                            .fill(Color.accentColor.opacity(0.1))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }
            .frame(minWidth: 180, idealWidth: 200, maxWidth: 240)
            .background(Color.surfaceSecondary)

            // Detail
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    topicContent(selectedTopic)
                }
                .padding(Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 800, minHeight: 550)
    }

    // MARK: - Topic Content Router

    @ViewBuilder
    private func topicContent(_ topic: HelpTopic) -> some View {
        switch topic {
        case .gettingStarted: gettingStartedContent
        case .dashboard: dashboardContent
        case .heatmap: heatmapContent
        case .chart: chartContent
        case .portfolioRisk: portfolioRiskContent
        case .watchlist: watchlistContent
        case .alerts: alertsContent
        case .screener: screenerContent
        case .research: researchContent
        case .journal: journalContent
        case .reports: reportsContent
        case .replay: replayContent
        case .companion: companionContent
        case .dataProviders: dataProvidersContent
        case .settings: settingsContent
        case .shortcuts: shortcutsContent
        case .indicators: indicatorsContent
        }
    }

    // MARK: - 1. Getting Started

    private var gettingStartedContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Getting Started")
            helpBody("Market Companion is a macOS trading intelligence app designed to sit alongside your broker. It provides automated reports, smart alerts, portfolio analytics, and a trade journal with market context capture.")

            helpHeading("First Steps")
            helpBody("1. Add your symbols in the Watchlist page — these become your holdings for reports and alerts.\n2. Configure a data provider (or use Demo mode) in Data Providers.\n3. Visit the Dashboard to see your market overview.\n4. Use Cmd+K to open Quick Search for fast navigation.")

            helpHeading("Demo vs Live Data")
            helpBody("In Demo mode, the app generates realistic sample data so you can explore every feature without an API key. Switch to Live mode in Data Providers once you have a key from Polygon, Alpaca, Finnhub, or another supported provider.")

            HelpTip("Tip: The Companion window (Cmd+Shift+K) is designed to float beside ThinkorSwim or any broker platform.")
        }
    }

    // MARK: - 2. Dashboard

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Dashboard")
            helpBody("The Dashboard is your daily overview. It shows metric cards, sector performance, upcoming earnings, news, holdings, alerts, and your latest report — all on one page.")

            helpHeading("Metric Cards")
            helpBody("The top row shows:\n• Holdings count with green/red ratio\n• Watchlist count\n• VIX Proxy — a volatility estimate (green < 15, amber < 20, red > 20)\n• Market Breadth — advancing vs declining, plus the regime label (Risk-On / Caution / Risk-Off)")

            helpHeading("Sector Performance")
            helpBody("A grid of sector tiles showing daily change and the leading symbol per sector. The regime badge in the header shows the overall market posture.")

            helpHeading("Upcoming Earnings")
            helpBody("Shows the next 3 earnings dates for your holdings. Navigate to Research for the full calendar.")

            helpHeading("News & Alerts")
            helpBody("The latest 3 news headlines and recent alert events appear here. Click \"More\" or \"Set Up\" to go to the full page.")
        }
    }

    // MARK: - 3. Heatmap

    private var heatmapContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Heatmap")
            helpBody("A visual overview of all your symbols, color-coded by daily change. Green = up, red = down, with intensity proportional to the magnitude.")

            helpHeading("Grid vs Treemap")
            helpBody("Grid mode shows equally-sized tiles in a responsive grid. Treemap mode shows a squarified treemap where tile area is proportional to the chosen size strategy.")

            helpHeading("Size Strategy (Treemap)")
            helpBody("In Treemap mode, choose what drives tile size:\n• Equal — all tiles are the same size\n• Market Cap — larger companies get bigger tiles\n• Volume — higher volume symbols are larger\n• Change — bigger movers get more space")

            helpHeading("Sorting & Filtering")
            helpBody("Use the Sort picker (Grid mode) to order by Change %, Volume, Volatility, or Sector. The Filter picker narrows to All, Holdings only, or Watchlist only.")

            HelpTip("Click any tile to jump to its Chart.")
        }
    }

    // MARK: - 4. Chart

    private var chartContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Chart")
            helpBody("A full interactive candlestick chart with overlays, sub-chart studies, drawing tools, symbol comparison, and trade plan visualization.")

            helpHeading("Candlesticks")
            helpBody("Type a symbol and press Return to load it. The chart shows OHLCV candles with automatic date axis scaling.")

            helpHeading("Intervals")
            helpBody("Switch between time intervals (1m, 5m, 15m, 1h, 4h, D, W) using the interval picker. Intraday intervals require a provider that supports intraday bars.")

            helpHeading("Indicators")
            helpBody("The Indicators menu has three sections:\n• Overlays — SMA, EMA, Bollinger Bands, VWAP, Ichimoku Cloud (drawn on the price chart)\n• Studies — RSI, MACD, ATR, Stochastic, OBV, ADX (drawn in sub-charts below)\n• Volume — toggle volume bars and volume profile")

            helpHeading("Drawing Tools")
            helpBody("Four drawing modes: Trend Line, Horizontal Line, Fibonacci retracement, and Text annotation. Drawings persist per symbol. Use the trash icon to clear all.")

            helpHeading("Compare")
            helpBody("Overlay other symbols for relative performance comparison. Toggle \"Normalize %\" to rebase all symbols to zero at the chart start. Quick Add buttons for SPY and QQQ.")

            helpHeading("Trade Plan")
            helpBody("Click the Plan button to set Entry, Stop, and Target prices. The app calculates risk/reward ratio and can overlay the levels on the chart. You can also log the trade directly from the plan panel.")

            helpHeading("Export")
            helpBody("Use the camera icon to copy the chart to clipboard (Cmd+Shift+C) or save as a PNG file.")
        }
    }

    // MARK: - 5. Portfolio Risk

    private var portfolioRiskContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Portfolio Risk")
            helpBody("Analyze your portfolio's risk characteristics including volatility, concentration, and correlations between holdings.")

            helpHeading("Annualized Volatility")
            helpBody("Estimated annualized portfolio volatility based on 120 days of daily returns, weighted by position size. Green < 15%, amber < 25%, red > 25%.")

            helpHeading("Concentration (HHI)")
            helpBody("The Herfindahl-Hirschman Index measures how concentrated your portfolio is. Values above 0.30 indicate a concentrated portfolio; below means diversified. A single holding gives HHI = 1.0.")

            helpHeading("Correlation Matrix")
            helpBody("A grid showing pairwise correlation between all holdings. Red cells (> 0.7) indicate high correlation — these positions move together and amplify risk. Green cells (< 0.4) indicate low correlation.")

            helpHeading("What-If Analysis")
            helpBody("Enter a hypothetical new symbol and allocation percentage to see how adding it would change your portfolio's volatility. The app fetches historical data if needed and recalculates.")

            HelpTip("You need at least 2 holdings with price history for risk analytics to work.")
        }
    }

    // MARK: - 6. Watchlist

    private var watchlistContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Watchlist")
            helpBody("Manage your holdings (positions you own) and watchlist items (symbols you're tracking). Both feed into reports, alerts, and the heatmap.")

            helpHeading("Holdings")
            helpBody("Holdings represent positions you own. Each has a symbol, optional share count, cost basis, and tags. The app fetches quotes, calculates P&L, and includes them in reports.")

            helpHeading("Watch Items")
            helpBody("Watch items are symbols you're tracking but don't own. Each has a reason tag (e.g., \"Breakout candidate\", \"Earnings catalyst\") and optional notes.")

            helpHeading("Groups")
            helpBody("Create named groups with color labels to organize holdings and watchlist items. Right-click any row to move it between groups. Groups appear as collapsible sections.")

            helpHeading("Organizing")
            helpBody("Use the Holdings/Watchlist picker to switch tabs. Ungrouped items appear at the bottom. Right-click or use the context menu to move items between groups.")
        }
    }

    // MARK: - 7. Alerts

    private var alertsContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Alerts")
            helpBody("The alert engine monitors your symbols every 60 seconds and fires events when conditions are met. View triggered events and manage rules.")

            helpHeading("Alert Types")
            helpBody("14 built-in alert types:")
            helpBullets([
                "Volume Spike — volume exceeds Nx average",
                "Trend Break — price crosses a moving average",
                "Unusual Volatility — intraday range exceeds Nx typical",
                "RSI Overbought — RSI(14) above threshold (default 70)",
                "RSI Oversold — RSI(14) below threshold (default 30)",
                "MACD Crossover — histogram crosses zero line",
                "Bollinger Squeeze — bandwidth falls below threshold",
                "Price Above/Below MA — price crosses N-period SMA",
                "Bullish/Bearish Engulfing — candlestick patterns",
                "Hammer — hammer candlestick pattern",
                "Doji — doji candlestick pattern",
                "Composite — multiple conditions that must all be true"
            ])

            helpHeading("Composite Builder")
            helpBody("The Composite type lets you combine 2-5 conditions (RSI, volume, price, MACD, etc.) with comparison operators. All conditions must be true simultaneously for the alert to fire.")

            helpHeading("Alert Engine")
            helpBody("The engine polls every 60 seconds while the app is running. Use \"Check Now\" to trigger an immediate scan. The enable/disable toggle on each rule controls whether it's evaluated.")
        }
    }

    // MARK: - 8. Screener

    private var screenerContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Screener")
            helpBody("Filter your tracked symbols using basic criteria or multi-condition technical scans.")

            helpHeading("Basic Filters")
            helpBody("Set ranges for:\n• Min/Max Change % — filter by daily performance\n• Min Volume Ratio — volume relative to average (e.g., 2.0 = 2x average)\n• Min/Max Price — absolute price range\n• Holdings Only / Watchlist Only — restrict to a subset")

            helpHeading("Technical Scans")
            helpBody("Switch to Technical mode for indicator-based scanning. Choose from preset templates or build custom criteria from checkboxes like RSI oversold, MACD bullish cross, golden cross, volume surge, etc.")

            helpHeading("Preset Templates")
            helpBody("Four quick-start templates:\n• Momentum — RSI, MACD, and volume criteria\n• Oversold Bounce — RSI oversold + volume surge\n• Breakout — SMA crossover + Bollinger squeeze\n• Trend Following — ADX trending + SMA alignment")

            HelpTip("Click any result row to jump to its Chart.")
        }
    }

    // MARK: - 9. Research

    private var researchContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Research")
            helpBody("A combined news feed and earnings calendar for your tracked symbols.")

            helpHeading("News Feed")
            helpBody("Headlines from your holdings and watchlist, grouped by date. Filter by symbol or time range (1, 3, 7, or 30 days). Click headlines to open the full article. Sentiment tags (positive, negative, neutral) are shown when available.")

            helpHeading("Earnings Calendar")
            helpBody("Upcoming earnings dates for the next 30 days, grouped by week. Filter by Holdings only, Watchlist only, or All. Shows estimated and actual EPS when available. The current week is highlighted.")
        }
    }

    // MARK: - 10. Journal

    private var journalContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Journal")
            helpBody("A full trade journal with five tabs: Open trades, Closed trades, Insights, Performance analytics, and a Calendar view.")

            helpHeading("Open & Closed Trades")
            helpBody("The Open tab shows active positions with a \"Close Trade\" button that prompts for the exit price. The Closed tab shows completed trades with P&L, plus summary metric cards for Total P&L, Win Rate, and Trade Count.")

            helpHeading("Insights")
            helpBody("After 3+ closed trades, the app analyzes your history and shows insights on:\n• Time of day performance\n• Direction bias (long vs short)\n• Average holding period\n• Best and worst symbols\n• Current streak\n• Volatility regime performance\n• Setup/tag performance breakdown")

            helpHeading("Performance Analytics")
            helpBody("After 2+ closed trades, see detailed metrics: Profit Factor, Sharpe Ratio, Max Drawdown, Expectancy, average win/loss, consecutive streaks, and Win Rate. Includes an equity curve chart, monthly P&L grid, and P&L distribution histogram.")

            helpHeading("Calendar View")
            helpBody("A monthly calendar showing trade activity by day. Click a day to see details in a popover.")

            helpHeading("Import / Export")
            helpBody("Import trades from a CSV file using the Import button. Export your full trade history as CSV with the Export button (available in the Insights tab).")

            HelpTip("Each trade auto-captures market context (VIX, breadth, volatility regime, time of day) for later analysis.")
        }
    }

    // MARK: - 11. Reports

    private var reportsContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Reports")
            helpBody("Automated morning and close briefings that analyze your portfolio, market conditions, and recent activity.")

            helpHeading("Morning vs Close")
            helpBody("Morning reports run at market open (default 6:30 AM PT) and cover overnight changes, pre-market movers, and the day ahead. Close reports run at market close (default 1:00 PM PT) and summarize the trading day.")

            helpHeading("Concise vs Detailed")
            helpBody("Concise mode shows the top 3 items per section and skips rotation analysis and key levels. Detailed mode includes everything. Toggle the mode in the Reports toolbar or Settings.")

            helpHeading("Scheduling")
            helpBody("Reports auto-generate when the app is running at the scheduled times on weekdays. Install the LaunchAgent in Settings to have macOS open the app at those times even when it's closed.")

            helpHeading("Audio Briefing")
            helpBody("Click \"Read Aloud\" to have the report spoken using macOS text-to-speech. Adjust the speech rate in Settings > Audio Briefing.")

            helpHeading("Copy & PDF")
            helpBody("Use the Copy button to copy the report as markdown text. Use the PDF button to export a formatted PDF file.")
        }
    }

    // MARK: - 12. Replay

    private var replayContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Replay")
            helpBody("Step through historical candles to practice trading decisions on real data. No real money is involved.")

            helpHeading("Getting Started")
            helpBody("Enter a symbol, select a date range, and click Start Replay. The chart will load daily candles and begin at bar 1.")

            helpHeading("Playback Controls")
            helpBody("• Step back/forward — move one bar at a time\n• Play/Pause — auto-advance at the chosen speed\n• Speed picker — 1x, 2x, 5x, or 10x playback speed\n• Progress bar — shows position within the date range")

            helpHeading("Practice Trading")
            helpBody("Enter a quantity and click Buy or Sell to open a position at the current candle's close price. Click Close to exit. Trades are tracked during the replay session and P&L is compared to buy-and-hold.")

            HelpTip("Replay is a learning tool. Try replaying volatile periods to practice decision-making under pressure.")
        }
    }

    // MARK: - 13. Companion Window

    private var companionContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Companion Window")
            helpBody("A compact, always-on-top-capable window designed to sit beside your broker platform.")

            helpHeading("Normal Mode")
            helpBody("Shows market regime, open positions with unrealized P&L, top movers from your holdings/watchlist, key price levels for the selected symbol, and recent alert events.")

            helpHeading("Focus Mode")
            helpBody("A minimal dark view showing only regime, VIX, breadth, your top 3 positions with large P&L numbers, and key levels. Designed for a small screen area during active trading.")

            helpHeading("Pin (Always on Top)")
            helpBody("Click the pin icon to keep the Companion window above all other windows. Useful for overlaying on your broker charts.")

            helpHeading("Quick Actions")
            helpBody("The header has buttons for Focus mode toggle, Pin, Position Size Calculator, Quick Trade, and Refresh.")
        }
    }

    // MARK: - 14. Data Providers

    private var dataProvidersContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Data Providers")
            helpBody("Configure where Market Companion gets its market data.")

            helpHeading("Demo vs Live")
            helpBody("Demo mode generates realistic sample data — no API key needed. Live mode fetches real market data from your configured provider. You can switch anytime.")

            helpHeading("Supported Providers")
            helpBody("Market Companion supports multiple providers through a router pattern. Each provider has different capabilities (quotes, daily bars, intraday, news, calendar, options, websocket). Check each provider's capability grid.")

            helpHeading("API Keys")
            helpBody("API keys are stored securely in the macOS Keychain. Enter your key in the expanded provider card and click Save. The key field is a secure field — text is hidden by default.")

            helpHeading("Primary & Fallback")
            helpBody("Set a primary provider for normal operation. Optionally set a fallback provider — if the primary fails, requests automatically fall to the fallback, then to demo data.")

            helpHeading("Testing")
            helpBody("Use \"Test Connection\" on individual providers or \"Test All\" to run health checks. The status shows latency and connection state.")
        }
    }

    // MARK: - 15. Settings

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Settings")
            helpBody("App-wide configuration for appearance, reports, scheduling, audio, and data management.")

            helpHeading("Appearance")
            helpBody("Choose Dark, Light, or Auto theme (follows macOS system setting). Pick an accent color that applies throughout the app.")

            helpHeading("Report Preferences")
            helpBody("Set the default report mode (Concise or Detailed). Concise shows top 3 items per section; Detailed includes rotation analysis and key levels.")

            helpHeading("Report Schedule")
            helpBody("Toggle morning and close report auto-generation. Set the time for each. Reports auto-generate on weekdays while the app is running.")

            helpHeading("Background Scheduling (LaunchAgent)")
            helpBody("Install a macOS LaunchAgent to have the system open Market Companion at your scheduled report times, even when the app is closed. Uninstall to remove it.")

            helpHeading("Audio Briefing")
            helpBody("Adjust the speech rate for Read Aloud from Slow to Very Fast. Preview to hear a sample at the current speed.")

            helpHeading("Storage")
            helpBody("View the database location, record counts, and use the Reveal button to open the database file in Finder.")

            helpHeading("Danger Zone")
            helpBody("Delete All Data permanently removes all holdings, watchlist items, trades, reports, alerts, and API keys from both the database and Keychain. This cannot be undone.")
        }
    }

    // MARK: - 16. Keyboard Shortcuts

    private var shortcutsContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Keyboard Shortcuts")

            VStack(alignment: .leading, spacing: Spacing.xs) {
                helpSubheading("Navigation")
                HelpShortcutRow(keys: "Cmd + K", action: "Open Quick Search")
                HelpShortcutRow(keys: "Cmd + Shift + K", action: "Toggle Companion Window")
                HelpShortcutRow(keys: "Cmd + ?", action: "Open Help")
                HelpShortcutRow(keys: "Cmd + ,", action: "Open Settings")

                helpSubheading("Actions")
                HelpShortcutRow(keys: "Cmd + R", action: "Generate Report (auto morning/close)")
                HelpShortcutRow(keys: "Cmd + L", action: "Log Trade")
                HelpShortcutRow(keys: "Cmd + Shift + R", action: "Refresh Data")
                HelpShortcutRow(keys: "Cmd + Shift + 1", action: "Generate Morning Report")
                HelpShortcutRow(keys: "Cmd + Shift + 2", action: "Generate Close Report")

                helpSubheading("Chart")
                HelpShortcutRow(keys: "Cmd + Shift + C", action: "Copy Chart to Clipboard")
            }
        }
    }

    // MARK: - 17. Technical Indicators Reference

    private var indicatorsContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            helpTitle("Technical Indicators Reference")
            helpBody("All indicators available in the Chart Indicators menu.")

            helpSubheading("Overlays (on price chart)")

            HelpIndicatorBlock(
                name: "SMA (Simple Moving Average)",
                description: "The arithmetic mean of the last N closing prices.",
                parameters: "Period: 20 (default)",
                reading: "Price above SMA suggests uptrend; below suggests downtrend. Crossovers of different-period SMAs signal momentum shifts."
            )

            HelpIndicatorBlock(
                name: "EMA (Exponential Moving Average)",
                description: "A weighted average that gives more importance to recent prices.",
                parameters: "Period: 9 (default)",
                reading: "More responsive than SMA. Common pairs: 9/21 EMA crossover for short-term signals."
            )

            HelpIndicatorBlock(
                name: "Bollinger Bands",
                description: "An SMA with upper and lower bands at N standard deviations.",
                parameters: "Period: 20, Std Dev: 2.0",
                reading: "Price touching upper band may indicate overbought; lower band may indicate oversold. A \"squeeze\" (narrow bands) often precedes a breakout."
            )

            HelpIndicatorBlock(
                name: "VWAP (Volume-Weighted Average Price)",
                description: "The average price weighted by volume, typically calculated intraday.",
                parameters: "Intraday only",
                reading: "Institutional benchmark. Price above VWAP suggests buyers are in control; below suggests sellers."
            )

            HelpIndicatorBlock(
                name: "Ichimoku Cloud",
                description: "A comprehensive indicator showing support/resistance, trend, and momentum.",
                parameters: "Tenkan: 9, Kijun: 26, Senkou B: 52",
                reading: "Price above the cloud is bullish; below is bearish. The cloud thickness indicates support/resistance strength. Tenkan/Kijun crossovers provide entry signals."
            )

            helpSubheading("Studies (sub-charts)")

            HelpIndicatorBlock(
                name: "RSI (Relative Strength Index)",
                description: "Measures the speed and magnitude of recent price changes on a 0-100 scale.",
                parameters: "Period: 14",
                reading: "Above 70 = overbought (potential pullback). Below 30 = oversold (potential bounce). Divergences between RSI and price can signal reversals."
            )

            HelpIndicatorBlock(
                name: "MACD (Moving Average Convergence Divergence)",
                description: "The difference between a fast and slow EMA, with a signal line.",
                parameters: "Fast: 12, Slow: 26, Signal: 9",
                reading: "MACD crossing above signal line = bullish. Below = bearish. The histogram shows momentum magnitude. Zero-line crossovers indicate trend changes."
            )

            HelpIndicatorBlock(
                name: "ATR (Average True Range)",
                description: "Measures volatility as the average of true ranges over N periods.",
                parameters: "Period: 14",
                reading: "Higher ATR = more volatile. Use for stop-loss placement (e.g., 2x ATR from entry) and position sizing."
            )

            HelpIndicatorBlock(
                name: "Stochastic Oscillator",
                description: "Compares closing price to the high-low range over N periods.",
                parameters: "K: 14, D: 3, Smooth: 3",
                reading: "Above 80 = overbought. Below 20 = oversold. %K crossing %D provides signals. Best in range-bound markets."
            )

            HelpIndicatorBlock(
                name: "OBV (On-Balance Volume)",
                description: "A cumulative volume indicator that adds volume on up days and subtracts on down days.",
                parameters: "None",
                reading: "Rising OBV confirms an uptrend. Falling OBV confirms a downtrend. Divergences between OBV and price can precede reversals."
            )

            HelpIndicatorBlock(
                name: "ADX (Average Directional Index)",
                description: "Measures trend strength regardless of direction.",
                parameters: "Period: 14",
                reading: "Above 25 = strong trend. Below 20 = weak/no trend. Use to filter out range-bound markets before applying trend-following strategies."
            )
        }
    }

    // MARK: - Content Helpers

    private func helpTitle(_ text: String) -> some View {
        Text(text)
            .font(AppFont.largeTitle())
            .foregroundStyle(Color.textPrimary)
    }

    private func helpHeading(_ text: String) -> some View {
        Text(text)
            .font(AppFont.headline())
            .foregroundStyle(Color.textPrimary)
            .padding(.top, Spacing.xs)
    }

    private func helpSubheading(_ text: String) -> some View {
        Text(text)
            .font(AppFont.subheadline())
            .foregroundStyle(Color.textSecondary)
            .padding(.top, Spacing.sm)
    }

    private func helpBody(_ text: String) -> some View {
        Text(text)
            .font(AppFont.body())
            .foregroundStyle(Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func helpBullets(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: Spacing.xs) {
                    Text("\u{2022}")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textTertiary)
                    Text(item)
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }
}

// MARK: - HelpTip

struct HelpTip: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.warningAmber)
            Text(text)
                .font(AppFont.body())
                .foregroundStyle(Color.textPrimary)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                .fill(Color.warningAmber.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                        .strokeBorder(Color.warningAmber.opacity(0.2), lineWidth: 0.5)
                }
        }
        .padding(.top, Spacing.xs)
    }
}

// MARK: - HelpShortcutRow

struct HelpShortcutRow: View {
    let keys: String
    let action: String

    var body: some View {
        HStack {
            Text(keys)
                .font(AppFont.mono())
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 2)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.surfaceElevated)
                }
            Spacer()
            Text(action)
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - HelpIndicatorBlock

struct HelpIndicatorBlock: View {
    let name: String
    let description: String
    let parameters: String
    let reading: String

    var body: some View {
        CardView(padding: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(name)
                    .font(AppFont.subheadline())
                    .foregroundStyle(Color.accentColor)

                Text(description)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.textTertiary)
                        Text(parameters)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Text("How to read: \(reading)")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
}
