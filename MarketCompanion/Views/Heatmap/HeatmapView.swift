// HeatmapView.swift
// MarketCompanion

import SwiftUI

enum HeatmapMode: String, CaseIterable {
    case grid = "Grid"
    case treemap = "Treemap"
}

enum HeatmapSort: String, CaseIterable {
    case change = "Change %"
    case volume = "Volume"
    case volatility = "Volatility"
    case sector = "Sector"
}

enum HeatmapFilter: String, CaseIterable {
    case all = "All"
    case holdings = "Holdings"
    case watchlist = "Watchlist"
}

struct HeatmapView: View {
    @EnvironmentObject var appState: AppState
    @State private var sortBy: HeatmapSort = .change
    @State private var filterBy: HeatmapFilter = .all
    @State private var hoveredSymbol: String?
    @State private var heatmapMode: HeatmapMode = .grid
    @State private var treemapSizeStrategy: TreemapSizeStrategy = .equal

    private var filteredQuotes: [Quote] {
        let holdingSymbols = Set(appState.holdings.map(\.symbol))
        let watchSymbols = Set(appState.watchItems.map(\.symbol))

        var quotes = appState.quotes
        switch filterBy {
        case .all:
            break
        case .holdings:
            quotes = quotes.filter { holdingSymbols.contains($0.symbol) }
        case .watchlist:
            quotes = quotes.filter { watchSymbols.contains($0.symbol) }
        }

        switch sortBy {
        case .change:
            quotes.sort { abs($0.changePct) > abs($1.changePct) }
        case .volume:
            quotes.sort { $0.volumeRatio > $1.volumeRatio }
        case .volatility:
            quotes.sort { $0.intradayRange > $1.intradayRange }
        case .sector:
            quotes.sort { MarketSector.classify($0.symbol).rawValue < MarketSector.classify($1.symbol).rawValue }
        }

        return quotes
    }

    private let columns = [
        GridItem(.adaptive(minimum: 130, maximum: 180), spacing: Spacing.xs)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Header
                HStack(alignment: .top) {
                    PageHeader(title: "Heatmap", subtitle: "\(filteredQuotes.count) symbols")
                    Spacer()
                    controlsBar
                }

                if filteredQuotes.isEmpty {
                    EmptyStateView(
                        icon: "square.grid.3x3",
                        title: "No Data",
                        message: "Add holdings or watchlist items to see the heatmap.",
                        actionTitle: "Add Symbols"
                    ) {
                        appState.selectedPage = .watchlist
                    }
                } else if heatmapMode == .treemap {
                    TreemapCanvasView(
                        quotes: filteredQuotes,
                        sizeStrategy: treemapSizeStrategy
                    ) { symbol in
                        appState.selectedChartSymbol = symbol
                        appState.selectedPage = .chart
                    }
                    .frame(minHeight: 400)
                } else {
                    LazyVGrid(columns: columns, spacing: Spacing.xs) {
                        ForEach(filteredQuotes) { quote in
                            Button {
                                appState.selectedChartSymbol = quote.symbol
                                appState.selectedPage = .chart
                            } label: {
                                heatmapTile(quote)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - Controls

    private var controlsBar: some View {
        HStack(spacing: Spacing.sm) {
            Picker("Mode", selection: $heatmapMode) {
                ForEach(HeatmapMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 150)
            .help("Grid shows equal tiles. Treemap sizes tiles by the chosen strategy.")

            Picker("Filter", selection: $filterBy) {
                ForEach(HeatmapFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
            .help("Show all symbols, only holdings, or only watchlist items")

            if heatmapMode == .grid {
                Picker("Sort", selection: $sortBy) {
                    ForEach(HeatmapSort.allCases, id: \.self) { sort in
                        Text(sort.rawValue).tag(sort)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .help("Order tiles by the selected metric")
            } else {
                Picker("Size", selection: $treemapSizeStrategy) {
                    ForEach(TreemapSizeStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.rawValue).tag(strategy)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
                .help("Controls what drives tile size in the treemap layout")
            }
        }
    }

    // MARK: - Heatmap Tile

    private func heatmapTile(_ quote: Quote) -> some View {
        let isHovered = hoveredSymbol == quote.symbol
        let sparkline = appState.sparklineData(for: quote.symbol)

        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text(quote.symbol)
                    .font(AppFont.symbol())
                    .foregroundStyle(.white)
                Spacer()
                if quote.volumeRatio > 1.5 {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text(FormatHelper.percent(quote.changePct))
                .font(AppFont.price())
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.4), value: quote.changePct)

            if !sparkline.isEmpty {
                MiniSparkline(data: sparkline, color: .white.opacity(0.7))
                    .frame(height: 20)
            }

            Text(FormatHelper.price(quote.last))
                .font(AppFont.monoSmall())
                .foregroundStyle(.white.opacity(0.7))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.4), value: quote.last)
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Color.heatmapColor(for: quote.changePct))
        }
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            hoveredSymbol = hovering ? quote.symbol : nil
        }
    }
}
