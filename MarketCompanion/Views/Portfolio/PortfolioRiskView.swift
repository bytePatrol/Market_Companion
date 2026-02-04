// PortfolioRiskView.swift
// MarketCompanion
//
// Portfolio risk analytics: beta, volatility, correlation, concentration, what-if.

import SwiftUI

struct PortfolioRiskView: View {
    @EnvironmentObject var appState: AppState
    @State private var whatIfSymbol = ""
    @State private var whatIfAllocation = "10"
    @State private var whatIfResult: (newVol: Double, delta: Double)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .top) {
                    PageHeader(title: "Portfolio Risk", subtitle: "Correlation, concentration & risk metrics")
                    Spacer()
                    Button {
                        Task { await appState.refreshData() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(AppFont.subheadline())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Fetch the latest price data for risk calculations")
                }

                if appState.holdings.count < 2 {
                    EmptyStateView(
                        icon: "chart.pie",
                        title: "Need More Holdings",
                        message: "Add at least 2 holdings to see portfolio risk analytics.",
                        actionTitle: "Go to Watchlist"
                    ) {
                        appState.selectedPage = .watchlist
                    }
                    .frame(height: 300)
                } else {
                    summaryMetrics
                    sectorAllocation
                    correlationSection
                    highCorrelationWarnings
                    whatIfSection
                }
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - Computed Data

    private var allBars: [String: [DailyBar]] {
        var result: [String: [DailyBar]] = [:]
        for holding in appState.holdings {
            if let bars = try? appState.dailyBarRepo.forSymbol(holding.symbol, limit: 120) {
                result[holding.symbol] = bars
            }
        }
        return result
    }

    private var portfolioWeights: [String: Double] {
        var total = 0.0
        var values: [String: Double] = [:]
        for holding in appState.holdings {
            let price = appState.quote(for: holding.symbol)?.last ?? 0
            let value = price * (holding.shares ?? 0)
            values[holding.symbol] = value
            total += value
        }
        guard total > 0 else { return [:] }
        return values.mapValues { $0 / total }
    }

    // MARK: - Summary Metrics

    private var summaryMetrics: some View {
        let vol = PortfolioAnalytics.portfolioVolatility(bars: allBars, weights: portfolioWeights)
        let hhi = PortfolioAnalytics.herfindahlIndex(holdings: appState.holdings, quotes: appState.quotes)

        return HStack(spacing: Spacing.md) {
            MetricCard(
                title: "Annualized Vol",
                value: String(format: "%.1f%%", vol),
                icon: "waveform.path.ecg",
                iconColor: vol > 25 ? .lossRed : vol > 15 ? .warningAmber : .gainGreen
            )
            .help("Estimated annualized portfolio volatility based on 120 days of daily returns")

            MetricCard(
                title: "Holdings",
                value: "\(appState.holdings.count)",
                subtitle: "positions",
                icon: "briefcase.fill",
                iconColor: .accentColor
            )

            MetricCard(
                title: "Concentration",
                value: String(format: "%.2f", hhi),
                subtitle: hhi > 0.3 ? "Concentrated" : "Diversified",
                icon: "chart.pie",
                iconColor: hhi > 0.3 ? .warningAmber : .gainGreen
            )
            .help("Herfindahl-Hirschman Index — above 0.30 is concentrated, below is diversified")
        }
    }

    // MARK: - Sector Allocation

    private var sectorAllocation: some View {
        let sectors = PortfolioAnalytics.sectorConcentration(holdings: appState.holdings, quotes: appState.quotes)

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Sector Allocation", icon: "chart.pie")

            if sectors.isEmpty {
                CardView {
                    Text("No allocation data available")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                }
            } else {
                CardView(padding: Spacing.sm) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        // Stacked horizontal bar
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                ForEach(sectors.indices, id: \.self) { i in
                                    let sector = sectors[i]
                                    Rectangle()
                                        .fill(sectorColor(i))
                                        .frame(width: geo.size.width * CGFloat(sector.pctOfPortfolio / 100))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .frame(height: 24)

                        // Legend
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.xs) {
                            ForEach(sectors.indices, id: \.self) { i in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(sectorColor(i))
                                        .frame(width: 8, height: 8)
                                    Text(sectors[i].sector)
                                        .font(AppFont.caption())
                                        .foregroundStyle(Color.textSecondary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(String(format: "%.0f%%", sectors[i].pctOfPortfolio))
                                        .font(AppFont.mono())
                                        .foregroundStyle(Color.textPrimary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectorColor(_ index: Int) -> Color {
        let colors: [Color] = [.accentColor, .gainGreen, .lossRed, .warningAmber, .infoBlue, .purple, .cyan, .orange, .mint, .pink]
        return colors[index % colors.count]
    }

    // MARK: - Correlation Matrix

    private var correlationSection: some View {
        let (symbols, matrix) = PortfolioAnalytics.correlationMatrix(bars: allBars)

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Correlation Matrix", icon: "square.grid.3x3")

            if symbols.count < 2 {
                CardView {
                    Text("Need at least 2 holdings with price history")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textSecondary)
                }
            } else {
                CardView(padding: Spacing.sm) {
                    VStack(spacing: 2) {
                        // Header row
                        HStack(spacing: 2) {
                            Text("")
                                .frame(width: 50)
                            ForEach(symbols, id: \.self) { sym in
                                Text(sym)
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .frame(width: 44)
                                    .lineLimit(1)
                            }
                        }

                        // Matrix rows
                        ForEach(0..<symbols.count, id: \.self) { i in
                            HStack(spacing: 2) {
                                Text(symbols[i])
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                    .frame(width: 50, alignment: .leading)
                                    .lineLimit(1)

                                ForEach(0..<symbols.count, id: \.self) { j in
                                    let val = matrix[i][j]
                                    Text(String(format: "%.2f", val))
                                        .font(.system(size: 8, design: .monospaced))
                                        .frame(width: 44, height: 28)
                                        .background(correlationColor(val).opacity(0.3))
                                        .clipShape(RoundedRectangle(cornerRadius: 2))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func correlationColor(_ value: Double) -> Color {
        let abs = abs(value)
        if abs > 0.7 { return .lossRed }
        if abs > 0.4 { return .warningAmber }
        return .gainGreen
    }

    // MARK: - High Correlation Warnings

    private var highCorrelationWarnings: some View {
        let (symbols, matrix) = PortfolioAnalytics.correlationMatrix(bars: allBars)
        var pairs: [(String, String, Double)] = []

        for i in 0..<symbols.count {
            for j in (i+1)..<symbols.count {
                if matrix[i][j] > 0.7 {
                    pairs.append((symbols[i], symbols[j], matrix[i][j]))
                }
            }
        }
        pairs.sort { $0.2 > $1.2 }

        return Group {
            if !pairs.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    SectionHeader(title: "Correlated Pairs", subtitle: "Risk concentration", icon: "exclamationmark.triangle")

                    ForEach(pairs.prefix(3), id: \.0) { pair in
                        CardView(padding: Spacing.sm) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.warningAmber)
                                Text("\(pair.0) & \(pair.1): \(String(format: "%.2f", pair.2))")
                                    .font(AppFont.subheadline())
                                Spacer()
                                Text("These move together")
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - What-If Section

    private var whatIfSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "What-If Analysis", subtitle: "Hypothetical position impact", icon: "questionmark.diamond")

            CardView(padding: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        TextField("Symbol", text: $whatIfSymbol)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .help("Enter a ticker to simulate adding it to your portfolio")

                        TextField("Allocation %", text: $whatIfAllocation)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .help("Percentage of portfolio to allocate to the hypothetical position")

                        Button("Analyze") {
                            runWhatIf()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(whatIfSymbol.isEmpty)
                        .help("Calculate how the new position would affect portfolio volatility")

                        Spacer()
                    }

                    if let result = whatIfResult {
                        HStack(spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("New Volatility")
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.textTertiary)
                                Text(String(format: "%.1f%%", result.newVol))
                                    .font(AppFont.price())
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Change")
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.textTertiary)
                                Text(String(format: "%+.1f%%", result.delta))
                                    .font(AppFont.price())
                                    .foregroundStyle(result.delta > 0 ? Color.lossRed : Color.gainGreen)
                            }
                        }
                    }
                }
            }
        }
    }

    private func runWhatIf() {
        let sym = whatIfSymbol.trimmingCharacters(in: .whitespaces).uppercased()
        guard !sym.isEmpty, let pct = Double(whatIfAllocation) else { return }
        let weight = pct / 100.0

        let newBars = (try? appState.dailyBarRepo.forSymbol(sym, limit: 120)) ?? []
        guard !newBars.isEmpty else {
            // Try to fetch first
            Task {
                let from = Calendar.current.date(byAdding: .day, value: -180, to: Date())!
                let bars = try await appState.dataProvider.fetchDailyBars(symbol: sym, from: from, to: Date())
                try appState.dailyBarRepo.save(bars)

                let result = PortfolioAnalytics.hypotheticalImpact(
                    bars: allBars,
                    currentWeights: portfolioWeights,
                    newSymbol: sym,
                    newWeight: weight,
                    newBars: bars.map { bar in
                        DailyBar(symbol: bar.symbol, date: bar.date, open: bar.open, high: bar.high, low: bar.low, close: bar.close, volume: bar.volume)
                    }
                )
                whatIfResult = (newVol: result.newVolatility, delta: result.deltaVolatility)
            }
            return
        }

        let result = PortfolioAnalytics.hypotheticalImpact(
            bars: allBars,
            currentWeights: portfolioWeights,
            newSymbol: sym,
            newWeight: weight,
            newBars: newBars
        )
        whatIfResult = (newVol: result.newVolatility, delta: result.deltaVolatility)
    }
}
