// ScreenerView.swift
// MarketCompanion
//
// Client-side stock screener that filters existing quotes.

import SwiftUI

// MARK: - Screener Filters

struct ScreenerFilters {
    var minChangePct: Double?
    var maxChangePct: Double?
    var minVolume: Int64?
    var minVolumeRatio: Double?
    var sectors: Set<String> = []
    var minPrice: Double?
    var maxPrice: Double?
    var onlyHoldings: Bool = false
    var onlyWatchlist: Bool = false
}

// MARK: - Screener View

enum ScreenerMode: String, CaseIterable {
    case basic = "Basic"
    case technical = "Technical"
}

struct ScreenerView: View {
    @EnvironmentObject var appState: AppState
    @State private var filters = ScreenerFilters()
    @State private var sortBy: ScreenerSort = .change
    @State private var screenerMode: ScreenerMode = .basic

    enum ScreenerSort: String, CaseIterable {
        case change = "Change %"
        case volume = "Volume"
        case price = "Price"
        case volatility = "Volatility"
    }

    private var filteredQuotes: [Quote] {
        let holdingSymbols = Set(appState.holdings.map(\.symbol))
        let watchSymbols = Set(appState.watchItems.map(\.symbol))

        var quotes = appState.quotes

        if filters.onlyHoldings {
            quotes = quotes.filter { holdingSymbols.contains($0.symbol) }
        }
        if filters.onlyWatchlist {
            quotes = quotes.filter { watchSymbols.contains($0.symbol) }
        }
        if let min = filters.minChangePct {
            quotes = quotes.filter { $0.changePct >= min }
        }
        if let max = filters.maxChangePct {
            quotes = quotes.filter { $0.changePct <= max }
        }
        if let minVol = filters.minVolume {
            quotes = quotes.filter { $0.volume >= minVol }
        }
        if let minRatio = filters.minVolumeRatio {
            quotes = quotes.filter { $0.volumeRatio >= minRatio }
        }
        if let minPrice = filters.minPrice {
            quotes = quotes.filter { $0.last >= minPrice }
        }
        if let maxPrice = filters.maxPrice {
            quotes = quotes.filter { $0.last <= maxPrice }
        }
        if !filters.sectors.isEmpty {
            quotes = quotes.filter { filters.sectors.contains(MarketSector.classify($0.symbol).rawValue) }
        }

        switch sortBy {
        case .change:
            quotes.sort { abs($0.changePct) > abs($1.changePct) }
        case .volume:
            quotes.sort { $0.volumeRatio > $1.volumeRatio }
        case .price:
            quotes.sort { $0.last > $1.last }
        case .volatility:
            quotes.sort { $0.intradayRange > $1.intradayRange }
        }

        return quotes
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .top) {
                    PageHeader(title: "Screener", subtitle: screenerMode == .basic ? "\(filteredQuotes.count) matches" : "Technical Scanner")
                    Spacer()

                    Picker("Mode", selection: $screenerMode) {
                        ForEach(ScreenerMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .help("Basic filters quotes by price and volume. Technical scans for indicator patterns.")

                    if screenerMode == .basic {
                        sortPicker
                    }
                }

                if screenerMode == .technical {
                    TechnicalScanView()
                        .environmentObject(appState)
                } else {
                    filterBar

                if filteredQuotes.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Matches",
                        message: "Adjust your filters or add more symbols to your holdings/watchlist.",
                        actionTitle: "Clear Filters"
                    ) {
                        filters = ScreenerFilters()
                    }
                    .frame(height: 300)
                } else {
                    ForEach(filteredQuotes) { quote in
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
                } // end else (basic mode)
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                filterField("Min Change %", value: Binding(
                    get: { filters.minChangePct.map { String($0) } ?? "" },
                    set: { filters.minChangePct = Double($0) }
                ))
                .help("Only show symbols with daily change above this percentage")
                filterField("Max Change %", value: Binding(
                    get: { filters.maxChangePct.map { String($0) } ?? "" },
                    set: { filters.maxChangePct = Double($0) }
                ))
                .help("Only show symbols with daily change below this percentage")
                filterField("Min Vol Ratio", value: Binding(
                    get: { filters.minVolumeRatio.map { String($0) } ?? "" },
                    set: { filters.minVolumeRatio = Double($0) }
                ))
                .help("Volume relative to average — e.g., 2.0 means twice the usual volume")
                filterField("Min Price", value: Binding(
                    get: { filters.minPrice.map { String($0) } ?? "" },
                    set: { filters.minPrice = Double($0) }
                ))
                .help("Filter by absolute stock price")
                filterField("Max Price", value: Binding(
                    get: { filters.maxPrice.map { String($0) } ?? "" },
                    set: { filters.maxPrice = Double($0) }
                ))
                .help("Filter by absolute stock price")
            }

            HStack(spacing: Spacing.sm) {
                Toggle("Holdings Only", isOn: $filters.onlyHoldings)
                    .toggleStyle(.checkbox)
                    .font(AppFont.caption())
                    .help("Restrict results to symbols in your holdings")
                Toggle("Watchlist Only", isOn: $filters.onlyWatchlist)
                    .toggleStyle(.checkbox)
                    .font(AppFont.caption())
                    .help("Restrict results to symbols in your watchlist")

                Spacer()

                Button("Clear") {
                    filters = ScreenerFilters()
                }
                .font(AppFont.caption())
                .controlSize(.small)
                .help("Reset all filters to defaults")
            }
        }
        .padding(Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Color.surfaceSecondary.opacity(0.5))
        }
    }

    private func filterField(_ label: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color.textTertiary)
            TextField("", text: value)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .font(AppFont.monoSmall())
        }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $sortBy) {
            ForEach(ScreenerSort.allCases, id: \.self) { sort in
                Text(sort.rawValue).tag(sort)
            }
        }
        .labelsHidden()
        .frame(width: 120)
        .help("Order results by the selected metric")
    }
}
