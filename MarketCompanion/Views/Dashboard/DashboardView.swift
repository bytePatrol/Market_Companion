// DashboardView.swift
// MarketCompanion

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Header
                HStack(alignment: .top) {
                    PageHeader(title: "Dashboard", subtitle: dateString)
                    Spacer()
                    Button {
                        Task { await appState.refreshData() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(AppFont.subheadline())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(appState.isLoading)
                    .help("Fetch the latest quotes, news, and calendar data")
                }

                // Metric cards row
                metricsRow

                // Insight chips
                DashboardInsightsRow()

                // Market Overview
                if let overview = appState.marketOverview {
                    marketOverviewSection(overview)
                }

                // Upcoming Earnings
                upcomingEarningsSection

                // Latest News
                latestNewsSection

                // Holdings in Play
                holdingsSection

                // Recent Alerts
                recentAlertsSection

                // Latest Report
                latestReportSection
            }
            .padding(Spacing.lg)
        }
        .overlay {
            if appState.isLoading && appState.quotes.isEmpty {
                LoadingOverlay(message: "Loading market data...")
            }
        }
    }

    // MARK: - Metrics Row

    private var metricsRow: some View {
        HStack(spacing: Spacing.md) {
            MetricCard(
                title: "Holdings",
                value: "\(appState.holdings.count)",
                subtitle: holdingsSubtitle,
                icon: "briefcase.fill",
                iconColor: .accentColor,
                trend: avgHoldingChange
            )

            MetricCard(
                title: "Watchlist",
                value: "\(appState.watchItems.count)",
                subtitle: "symbols tracked",
                icon: "eye.fill",
                iconColor: .infoBlue
            )

            if let overview = appState.marketOverview {
                MetricCard(
                    title: "VIX Proxy",
                    value: String(format: "%.1f", overview.vixProxy),
                    subtitle: overview.volatilityRegime.rawValue,
                    icon: "waveform.path.ecg",
                    iconColor: vixColor(overview.vixProxy)
                )
                .help("Estimated market volatility — green < 15, amber < 20, red > 20")

                MetricCard(
                    title: "Breadth",
                    value: "\(overview.breadthAdvancing)/\(overview.breadthDeclining)",
                    subtitle: overview.marketRegime,
                    icon: "chart.bar.fill",
                    iconColor: overview.breadthRatio > 0.5 ? .gainGreen : .lossRed,
                    trend: overview.breadthRatio > 0.5 ? 1 : -1
                )
                .help("Advancing vs declining symbols — indicates overall market health")
            }
        }
    }

    private var holdingsSubtitle: String {
        let up = appState.quotes.filter { q in
            appState.holdings.contains(where: { $0.symbol == q.symbol }) && q.changePct > 0
        }.count
        let total = appState.holdings.count
        return "\(up)/\(total) green today"
    }

    private var avgHoldingChange: Double? {
        let holdingQuotes = appState.quotes.filter { q in
            appState.holdings.contains(where: { $0.symbol == q.symbol })
        }
        guard !holdingQuotes.isEmpty else { return nil }
        return holdingQuotes.map(\.changePct).reduce(0, +) / Double(holdingQuotes.count)
    }

    private func vixColor(_ vix: Double) -> Color {
        if vix < 15 { return .gainGreen }
        if vix < 20 { return .warningAmber }
        return .lossRed
    }

    // MARK: - Market Overview

    private func marketOverviewSection(_ overview: MarketOverview) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Sector Performance", icon: "square.grid.3x3.fill") {
                RegimeBadge(regime: overview.marketRegime)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.xs) {
                ForEach(overview.sectorPerformance) { sector in
                    sectorTile(sector)
                }
            }
        }
    }

    private func sectorTile(_ sector: SectorPerformance) -> some View {
        CardView(padding: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(sector.sector)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                HStack {
                    Text(FormatHelper.percent(sector.changePct))
                        .font(AppFont.mono())
                        .foregroundStyle(Color.forChange(sector.changePct))
                    Spacer()
                }
                HStack(spacing: 2) {
                    Text(sector.leaderSymbol)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textTertiary)
                    Text(FormatHelper.percent(sector.leaderChangePct))
                        .font(AppFont.caption())
                        .foregroundStyle(Color.forChange(sector.leaderChangePct))
                }
            }
        }
    }

    // MARK: - Upcoming Earnings

    private var upcomingEarningsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Upcoming Earnings", icon: "calendar") {
                Button("View All") {
                    appState.selectedPage = .research
                }
                .font(AppFont.caption())
                .foregroundStyle(Color.accentColor)
                .help("Open the full earnings calendar in Research")
            }

            let holdingSymbols = Set(appState.holdings.map(\.symbol))
            let upcoming = appState.calendarEvents
                .filter { holdingSymbols.contains($0.symbol) && $0.date >= Date() }
                .sorted { $0.date < $1.date }
                .prefix(3)

            if upcoming.isEmpty {
                CardView {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No upcoming earnings")
                                .font(AppFont.subheadline())
                                .foregroundStyle(Color.textPrimary)
                            Text("Earnings dates for your holdings will appear here.")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                    }
                }
            } else {
                ForEach(Array(upcoming)) { event in
                    CardView(padding: Spacing.sm) {
                        HStack(spacing: Spacing.sm) {
                            VStack(alignment: .center, spacing: 0) {
                                Text(earningsMonth(event.date))
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.textTertiary)
                                Text(earningsDay(event.date))
                                    .font(AppFont.title())
                                    .foregroundStyle(Color.textPrimary)
                            }
                            .frame(width: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.symbol)
                                    .font(AppFont.symbol())
                                TagPill(text: event.eventType, color: .infoBlue, style: .subtle)
                            }

                            Spacer()

                            if let est = event.estimatedEPS {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Est. EPS")
                                        .font(AppFont.caption())
                                        .foregroundStyle(Color.textTertiary)
                                    Text(String(format: "$%.2f", est))
                                        .font(AppFont.mono())
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func earningsMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }

    private func earningsDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    // MARK: - Latest News

    private var latestNewsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Latest News", icon: "newspaper") {
                Button("More") {
                    appState.selectedPage = .research
                }
                .font(AppFont.caption())
                .foregroundStyle(Color.accentColor)
            }

            let recentNews = Array(appState.newsItems.prefix(3))

            if recentNews.isEmpty {
                CardView {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No news yet")
                                .font(AppFont.subheadline())
                                .foregroundStyle(Color.textPrimary)
                            Text("News for your holdings and watchlist will appear here.")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                    }
                }
            } else {
                ForEach(recentNews) { item in
                    CardView(padding: Spacing.sm) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            HStack {
                                TagPill(text: item.source, color: .textTertiary, style: .subtle)
                                if let sentiment = item.sentiment {
                                    TagPill(
                                        text: sentiment,
                                        color: sentiment == "positive" ? .gainGreen : sentiment == "negative" ? .lossRed : .textTertiary,
                                        style: .subtle
                                    )
                                }
                                Spacer()
                                Text(FormatHelper.relativeDate(item.publishedAt))
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.textTertiary)
                            }

                            Text(item.headline)
                                .font(AppFont.subheadline())
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(2)

                            if !item.relatedSymbols.isEmpty {
                                HStack(spacing: Spacing.xxs) {
                                    ForEach(item.relatedSymbols.prefix(4), id: \.self) { sym in
                                        Text(sym)
                                            .font(AppFont.caption())
                                            .foregroundStyle(Color.accentColor)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.accentColor.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Holdings

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(
                title: "Holdings",
                subtitle: "\(appState.holdings.count) positions",
                icon: "briefcase.fill"
            ) {
                Button("View All") {
                    // Navigate to dedicated holdings view
                }
                .font(AppFont.caption())
                .foregroundStyle(Color.accentColor)
            }

            if appState.holdings.isEmpty {
                EmptyStateView(
                    icon: "briefcase",
                    title: "No Holdings",
                    message: "Add your positions to see them on the dashboard.",
                    actionTitle: "Add Holding"
                ) {
                    appState.selectedPage = .watchlist
                }
                .frame(height: 200)
            } else {
                ForEach(topMovingHoldings) { quote in
                    Button {
                        appState.selectedChartSymbol = quote.symbol
                        appState.selectedPage = .chart
                    } label: {
                        SymbolRowCard(
                            quote: quote,
                            showVolume: true,
                            sparklineData: appState.sparklineData(for: quote.symbol)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var topMovingHoldings: [Quote] {
        appState.quotes
            .filter { q in appState.holdings.contains(where: { $0.symbol == q.symbol }) }
            .sorted { abs($0.changePct) > abs($1.changePct) }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Recent Alerts

    private var recentAlertsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(
                title: "Recent Alerts",
                subtitle: appState.alertEvents.isEmpty ? nil : "\(appState.alertEvents.count) events",
                icon: "bell.badge"
            )

            if appState.alertEvents.isEmpty {
                CardView {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No alerts yet")
                                .font(AppFont.subheadline())
                                .foregroundStyle(Color.textPrimary)
                            Text("Create alert rules to monitor volume spikes, trend breaks, and volatility.")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Button("Set Up") {
                            appState.selectedPage = .alerts
                        }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                        .help("Go to the Alerts page to create monitoring rules")
                    }
                }
            } else {
                ForEach(appState.alertEvents.prefix(3)) { event in
                    CardView(padding: Spacing.sm) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.warningAmber)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.summary)
                                    .font(AppFont.subheadline())
                                Text(FormatHelper.relativeDate(event.triggeredAt))
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.textTertiary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Latest Report

    private var latestReportSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(
                title: "Latest Report",
                icon: "doc.text"
            )

            if appState.isGeneratingReport {
                CardView {
                    HStack(spacing: Spacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generating report...")
                            .font(AppFont.subheadline())
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: appState.isGeneratingReport)
            }

            if let latest = appState.reports.first {
                CardView {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            TagPill(
                                text: latest.type == .morning ? "Morning" : "Close",
                                color: latest.type == .morning ? .warningAmber : .infoBlue,
                                style: .subtle
                            )
                            Spacer()
                            Text(FormatHelper.fullDate(latest.createdAt))
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textTertiary)
                        }

                        Text(latest.renderedMarkdown.prefix(200) + (latest.renderedMarkdown.count > 200 ? "..." : ""))
                            .font(AppFont.body())
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(4)

                        Button("Read Full Report") {
                            appState.selectedPage = .reports
                        }
                        .font(AppFont.caption())
                        .foregroundStyle(Color.accentColor)
                    }
                }
            } else {
                CardView {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No reports generated")
                                .font(AppFont.subheadline())
                                .foregroundStyle(Color.textPrimary)
                            Text("Reports generate automatically at market open (6:30 AM) and close (1:00 PM).")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}
