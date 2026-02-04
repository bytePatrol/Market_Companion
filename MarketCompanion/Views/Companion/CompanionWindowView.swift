// CompanionWindowView.swift
// MarketCompanion
//
// Compact companion window designed to sit beside ThinkorSwim.

import SwiftUI

struct CompanionWindowView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSymbol: String?
    @State private var isAlwaysOnTop = false
    @State private var showQuickTrade = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider()

            if appState.companionFocusMode {
                focusModeContent
            } else {
                normalModeContent
            }
        }
        .frame(minWidth: 310, idealWidth: 310, minHeight: 400)
        .background(appState.companionFocusMode ? Color.black.opacity(0.9) : Color.surfacePrimary)
        .animation(.easeInOut(duration: 0.3), value: appState.companionFocusMode)
        .sheet(isPresented: $showQuickTrade) {
            CompanionQuickTradeSheet()
                .environmentObject(appState)
        }
    }

    // MARK: - Normal Mode

    private var normalModeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                regimeSection
                SubtleDivider()
                openPositionsSection
                SubtleDivider()
                topMoversSection
                SubtleDivider()
                if let symbol = selectedSymbol {
                    keyLevelsSection(symbol)
                }
                SubtleDivider()
                alertsTimeline
            }
            .padding(Spacing.sm)
        }
    }

    // MARK: - Focus Mode

    private var focusModeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Regime + VIX (large)
                if let overview = appState.marketOverview {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(overview.marketRegime)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(overview.marketRegime == "Risk-On" ? Color.gainGreen : overview.marketRegime == "Risk-Off" ? Color.lossRed : Color.warningAmber)
                            Text("VIX \(String(format: "%.1f", overview.vixProxy))")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer()
                        Text("\(overview.breadthAdvancing)A/\(overview.breadthDeclining)D")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                // Top 3 positions with large P&L
                let openTrades = appState.trades.filter { !$0.isClosed }
                if !openTrades.isEmpty {
                    ForEach(openTrades.prefix(3)) { trade in
                        HStack {
                            Text(trade.symbol)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)

                            Text(trade.side == .long ? "L" : "S")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(trade.side == .long ? Color.gainGreen : Color.lossRed)

                            Spacer()

                            if let quote = appState.quote(for: trade.symbol) {
                                let multiplier: Double = trade.side == .long ? 1 : -1
                                let unrealized = (quote.last - trade.entryPrice) * trade.qty * multiplier
                                let pct = (quote.last - trade.entryPrice) / trade.entryPrice * 100 * multiplier
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(FormatHelper.pnl(unrealized))
                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.forChange(unrealized))
                                    Text(String(format: "%+.2f%%", pct))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color.forChange(pct))
                                }
                            }
                        }
                    }
                }

                // Key levels for selected symbol
                if let symbol = selectedSymbol, let quote = appState.quote(for: symbol) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(symbol)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.accentColor)

                        let pivot = (quote.dayHigh + quote.dayLow + quote.last) / 3
                        let r1 = 2 * pivot - quote.dayLow
                        let s1 = 2 * pivot - quote.dayHigh

                        HStack {
                            focusLevelLabel("R1", value: r1)
                            Spacer()
                            focusLevelLabel("P", value: pivot)
                            Spacer()
                            focusLevelLabel("S1", value: s1)
                        }

                        HStack {
                            focusLevelLabel("H", value: quote.dayHigh)
                            Spacer()
                            focusLevelLabel("Last", value: quote.last, highlight: true)
                            Spacer()
                            focusLevelLabel("L", value: quote.dayLow)
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
    }

    private func focusLevelLabel(_ label: String, value: Double, highlight: Bool = false) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(highlight ? Color.accentColor : Color.textTertiary)
            Text(FormatHelper.price(value))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(highlight ? .white : Color.textSecondary)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.accentColor)

            if !appState.companionFocusMode {
                Text("Companion")
                    .font(AppFont.subheadline())
                    .foregroundStyle(Color.textPrimary)
            }

            Spacer()

            Button {
                appState.companionFocusMode.toggle()
            } label: {
                Image(systemName: appState.companionFocusMode ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                    .font(.system(size: 11))
                    .foregroundStyle(appState.companionFocusMode ? Color.accentColor : Color.textTertiary)
            }
            .buttonStyle(.plain)
            .help(appState.companionFocusMode ? "Exit focus mode" : "Focus mode")

            Button {
                isAlwaysOnTop.toggle()
                setWindowLevel(isAlwaysOnTop)
            } label: {
                Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                    .foregroundStyle(isAlwaysOnTop ? Color.accentColor : Color.textTertiary)
            }
            .buttonStyle(.plain)
            .help(isAlwaysOnTop ? "Unpin window" : "Pin above other windows")

            Button {
                appState.showPositionSizer = true
            } label: {
                Image(systemName: "function")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Position size calculator")

            Button {
                showQuickTrade = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Quick trade log")

            Button {
                Task { await appState.refreshData() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Refresh market data")
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.bar)
    }

    // MARK: - Market Regime

    private var regimeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("MARKET REGIME")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textTertiary)
                .tracking(1)

            if let overview = appState.marketOverview {
                HStack(spacing: Spacing.xs) {
                    RegimeBadge(regime: overview.marketRegime)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("VIX \(String(format: "%.1f", overview.vixProxy))")
                            .font(AppFont.monoSmall())
                            .foregroundStyle(Color.textSecondary)
                        Text("\(overview.breadthAdvancing)A / \(overview.breadthDeclining)D")
                            .font(AppFont.monoSmall())
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            } else {
                Text("Loading...")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    // MARK: - Open Positions

    private var openPositionsSection: some View {
        let openTrades = appState.trades.filter { !$0.isClosed }

        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text("OPEN POSITIONS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                    .tracking(1)
                Spacer()
                if !openTrades.isEmpty {
                    Text("\(openTrades.count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.textTertiary)
                }
            }

            if openTrades.isEmpty {
                Text("No open positions")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, 2)
            } else {
                ForEach(openTrades.prefix(5)) { trade in
                    HStack(spacing: Spacing.xs) {
                        Text(trade.symbol)
                            .font(AppFont.monoSmall())
                            .foregroundStyle(Color.textPrimary)
                            .frame(width: 44, alignment: .leading)

                        TagPill(
                            text: trade.side.rawValue.uppercased(),
                            color: trade.side == .long ? .gainGreen : .lossRed,
                            style: .subtle
                        )

                        Spacer()

                        Text("\(Int(trade.qty)) @ \(FormatHelper.price(trade.entryPrice))")
                            .font(AppFont.monoSmall())
                            .foregroundStyle(Color.textSecondary)

                        // Show unrealized P&L if we have a current quote
                        if let quote = appState.quote(for: trade.symbol) {
                            let multiplier: Double = trade.side == .long ? 1 : -1
                            let unrealized = (quote.last - trade.entryPrice) * trade.qty * multiplier
                            Text(FormatHelper.pnl(unrealized))
                                .font(AppFont.monoSmall())
                                .foregroundStyle(Color.forChange(unrealized))
                                .frame(width: 65, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    // MARK: - Top Movers

    private var topMoversSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("TOP MOVERS")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textTertiary)
                .tracking(1)

            let movers = appState.quotes
                .filter { q in
                    appState.holdings.contains(where: { $0.symbol == q.symbol }) ||
                    appState.watchItems.contains(where: { $0.symbol == q.symbol })
                }
                .sorted { abs($0.changePct) > abs($1.changePct) }
                .prefix(6)

            ForEach(Array(movers)) { quote in
                Button {
                    selectedSymbol = quote.symbol
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(quote.symbol)
                            .font(AppFont.monoSmall())
                            .foregroundStyle(selectedSymbol == quote.symbol ? Color.accentColor : Color.textPrimary)
                            .frame(width: 44, alignment: .leading)

                        Spacer()

                        Text(FormatHelper.price(quote.last))
                            .font(AppFont.monoSmall())
                            .foregroundStyle(Color.textSecondary)

                        Text(FormatHelper.percent(quote.changePct))
                            .font(AppFont.monoSmall())
                            .foregroundStyle(Color.forChange(quote.changePct))
                            .frame(width: 55, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Key Levels

    private func keyLevelsSection(_ symbol: String) -> some View {
        let quote = appState.quote(for: symbol)

        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Text("KEY LEVELS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                    .tracking(1)
                Text(symbol)
                    .font(AppFont.monoSmall())
                    .foregroundStyle(Color.accentColor)
            }

            if let quote {
                VStack(spacing: 2) {
                    levelRow("Day High", value: quote.dayHigh)
                    levelRow("Last", value: quote.last, highlight: true)
                    levelRow("Day Low", value: quote.dayLow)

                    // Simple pivot calculation
                    let pivot = (quote.dayHigh + quote.dayLow + quote.last) / 3
                    let r1 = 2 * pivot - quote.dayLow
                    let s1 = 2 * pivot - quote.dayHigh

                    SubtleDivider()
                        .padding(.vertical, 2)

                    levelRow("R1", value: r1)
                    levelRow("Pivot", value: pivot)
                    levelRow("S1", value: s1)
                }
            }
        }
    }

    private func levelRow(_ label: String, value: Double, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(AppFont.monoSmall())
                .foregroundStyle(highlight ? Color.accentColor : Color.textTertiary)
                .frame(width: 60, alignment: .leading)
            Spacer()
            Text(FormatHelper.price(value))
                .font(AppFont.monoSmall())
                .foregroundStyle(highlight ? Color.textPrimary : Color.textSecondary)
        }
    }

    // MARK: - Alerts Timeline

    private var alertsTimeline: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("RECENT ALERTS")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textTertiary)
                .tracking(1)

            if appState.alertEvents.isEmpty {
                Text("No recent alerts")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, Spacing.xs)
            } else {
                ForEach(appState.alertEvents.prefix(4)) { event in
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(Color.warningAmber)
                            .frame(width: 5, height: 5)
                        Text(event.summary)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Text(FormatHelper.relativeDate(event.triggeredAt))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Window Level

    private func setWindowLevel(_ alwaysOnTop: Bool) {
        if let window = NSApplication.shared.windows.first(where: { $0.title == "Companion" }) {
            window.level = alwaysOnTop ? .floating : .normal
        }
    }
}

// MARK: - Quick Trade Sheet (Compact)

struct CompanionQuickTradeSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var symbol = ""
    @State private var side: TradeSide = .long
    @State private var qty = ""
    @State private var price = ""

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text("Quick Trade")
                .font(AppFont.headline())

            HStack(spacing: Spacing.xs) {
                TextField("SYM", text: $symbol)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)

                Picker("", selection: $side) {
                    Text("Long").tag(TradeSide.long)
                    Text("Short").tag(TradeSide.short)
                }
                .frame(width: 80)
            }

            HStack(spacing: Spacing.xs) {
                TextField("Qty", text: $qty)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                TextField("Price", text: $price)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Log") {
                    let sym = symbol.trimmingCharacters(in: .whitespaces).uppercased()
                    guard !sym.isEmpty,
                          let q = Double(qty),
                          let p = Double(price) else { return }
                    appState.logTrade(symbol: sym, side: side, qty: q, entryPrice: p)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(symbol.isEmpty || qty.isEmpty || price.isEmpty)
            }
        }
        .padding(Spacing.md)
        .frame(width: 240)
    }
}
