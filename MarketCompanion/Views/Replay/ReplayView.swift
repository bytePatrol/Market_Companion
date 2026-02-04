// ReplayView.swift
// MarketCompanion
//
// Market replay mode: step through historical candles, practice trading.

import SwiftUI

struct ReplayView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ReplayViewModel()
    @State private var replayQty = "100"

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar

            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading replay data...")
                    .font(AppFont.body())
                Spacer()
            } else if !viewModel.hasStarted {
                Spacer()
                startPrompt
                Spacer()
            } else if viewModel.replayCandles.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Data",
                    message: "No candle data available for this symbol and date range.",
                    actionTitle: "Try Again"
                ) {}
                Spacer()
            } else {
                replayContent
            }
        }
        .onAppear {
            viewModel.appState = appState
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Symbol", text: $viewModel.replaySymbol)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .font(AppFont.symbol())
                .help("Ticker symbol to replay")

            DatePicker("From", selection: $viewModel.startDate, displayedComponents: .date)
                .frame(width: 180)
                .font(AppFont.caption())
                .help("Start date for the replay range")

            DatePicker("To", selection: $viewModel.endDate, displayedComponents: .date)
                .frame(width: 180)
                .font(AppFont.caption())
                .help("End date for the replay range")

            Button("Start Replay") {
                Task { await viewModel.loadReplayData() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(viewModel.replaySymbol.isEmpty)
            .help("Load historical candles and begin the replay")

            if viewModel.hasStarted {
                Button("Reset") {
                    viewModel.reset()
                }
                .controlSize(.small)
                .help("Clear the replay and start over")
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.bar)
    }

    // MARK: - Start Prompt

    private var startPrompt: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.textTertiary)

            Text("Market Replay")
                .font(AppFont.title())

            Text("Select a symbol and date range, then step through candles to practice trading decisions on real historical data.")
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
    }

    // MARK: - Replay Content

    private var replayContent: some View {
        HSplitView {
            // Left: Chart + Controls
            VStack(spacing: 0) {
                // Mini OHLCV bar
                replayOHLCV
                    .frame(height: 20)

                // Chart showing only visible candles
                replayChart
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Playback controls
                playbackControls
                    .frame(height: 50)
            }

            // Right: Trade panel + context
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    tradePanel
                    contextPanel
                    if viewModel.isAtEnd || !viewModel.replayTrades.filter(\.isClosed).isEmpty {
                        resultsPanel
                    }
                }
                .padding(Spacing.sm)
            }
            .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)
        }
    }

    // MARK: - OHLCV Bar

    private var replayOHLCV: some View {
        HStack(spacing: Spacing.md) {
            if let candle = viewModel.currentCandle {
                Group {
                    Text("O: \(FormatHelper.price(candle.open))")
                    Text("H: \(FormatHelper.price(candle.high))")
                    Text("L: \(FormatHelper.price(candle.low))")
                    Text("C: \(FormatHelper.price(candle.close))")
                        .foregroundStyle(Color.forChange(candle.close - candle.open))
                    Text("V: \(FormatHelper.volume(candle.volume))")
                }
                .font(AppFont.monoSmall())
                .foregroundStyle(Color.textSecondary)

                Spacer()

                Text("Bar \(viewModel.replayIndex + 1)/\(viewModel.replayCandles.count)")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .background(Color.surfaceSecondary.opacity(0.5))
    }

    // MARK: - Chart

    private func priceToY(_ price: Double, height: CGFloat, minP: Double, prRange: Double) -> CGFloat {
        let ratio = (price - minP) / prRange
        return 4.0 + (height - 8.0) * (1.0 - ratio)
    }

    private var replayChart: some View {
        let visible = viewModel.visibleCandles

        return Canvas { context, size in
            guard !visible.isEmpty else { return }

            let maxVisible = min(visible.count, 80)
            let startIdx = max(0, visible.count - maxVisible)
            let shown = Array(visible[startIdx...])

            guard let lo = shown.map(\.low).min(),
                  let hi = shown.map(\.high).max() else { return }

            let padding = max((hi - lo) * 0.05, 0.01)
            let minP = lo - padding
            let maxP = hi + padding
            let prRange = maxP - minP

            let candleCount = CGFloat(shown.count)
            let cw = size.width / candleCount
            let bodyWidth = max(1, cw - max(2, cw * 0.3))
            let h = size.height

            for (i, candle) in shown.enumerated() {
                let x = CGFloat(i) * cw + cw / 2
                let isGreen = candle.close >= candle.open
                let color: Color = isGreen ? .gainGreen : .lossRed

                let wickTop = self.priceToY(candle.high, height: h, minP: minP, prRange: prRange)
                let wickBottom = self.priceToY(candle.low, height: h, minP: minP, prRange: prRange)
                var wickPath = Path()
                wickPath.move(to: CGPoint(x: x, y: wickTop))
                wickPath.addLine(to: CGPoint(x: x, y: wickBottom))
                context.stroke(wickPath, with: .color(color), lineWidth: 1)

                let openY = self.priceToY(candle.open, height: h, minP: minP, prRange: prRange)
                let closeY = self.priceToY(candle.close, height: h, minP: minP, prRange: prRange)
                let bodyTop = min(openY, closeY)
                let bodyBottom = max(openY, closeY)
                let bodyHeight = max(1, bodyBottom - bodyTop)
                let bodyRect = CGRect(x: x - bodyWidth / 2, y: bodyTop, width: bodyWidth, height: bodyHeight)
                context.fill(Path(bodyRect), with: .color(color))
            }
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: Spacing.md) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.textTertiary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(viewModel.progress))
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)

            // Buttons
            HStack(spacing: Spacing.xs) {
                Button { viewModel.stepBack() } label: {
                    Image(systemName: "backward.frame")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.replayIndex <= 0)
                .help("Go back one candle")

                Button {
                    viewModel.isPlaying ? viewModel.pause() : viewModel.play()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .help("Auto-advance candles at the selected speed")

                Button { viewModel.stepForward() } label: {
                    Image(systemName: "forward.frame")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isAtEnd)
                .help("Advance one candle")
            }

            // Speed picker
            Picker("", selection: $viewModel.playbackSpeed) {
                Text("1x").tag(1.0)
                Text("2x").tag(2.0)
                Text("5x").tag(5.0)
                Text("10x").tag(10.0)
            }
            .frame(width: 70)
            .help("Playback speed — higher values advance candles faster")
            .onChange(of: viewModel.playbackSpeed) {
                viewModel.setSpeed(viewModel.playbackSpeed)
            }
        }
        .padding(.horizontal, Spacing.md)
        .background(.bar)
    }

    // MARK: - Trade Panel

    private var tradePanel: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader(title: "Trade", icon: "arrow.left.arrow.right")

            HStack(spacing: Spacing.xs) {
                TextField("Qty", text: $replayQty)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .help("Number of shares for practice trades")

                Button("Buy") {
                    if let qty = Double(replayQty) {
                        viewModel.placeTrade(side: .long, qty: qty)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.gainGreen)
                .controlSize(.small)
                .help("Open a long position at the current candle's close price")

                Button("Sell") {
                    if let qty = Double(replayQty) {
                        viewModel.placeTrade(side: .short, qty: qty)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.lossRed)
                .controlSize(.small)
                .help("Open a short position at the current candle's close price")

                if viewModel.replayTrades.contains(where: { !$0.isClosed }) {
                    Button("Close") {
                        viewModel.closeLastTrade()
                    }
                    .controlSize(.small)
                    .help("Close the last open position at the current candle's close price")
                }
            }

            Text("Price: \(FormatHelper.price(viewModel.currentPrice))")
                .font(AppFont.mono())
                .foregroundStyle(Color.textSecondary)

            // Open replay trades
            ForEach(viewModel.replayTrades.filter { !$0.isClosed }, id: \.entryTime) { trade in
                HStack {
                    TagPill(text: trade.side.rawValue.uppercased(), color: trade.side == .long ? .gainGreen : .lossRed, style: .filled)
                    Text("\(Int(trade.qty)) @ \(FormatHelper.price(trade.entryPrice))")
                        .font(AppFont.caption())
                    Spacer()
                }
            }
        }
    }

    // MARK: - Context Panel

    private var contextPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader(title: "Context", icon: "info.circle")

            if let candle = viewModel.currentCandle {
                let dateStr = FormatHelper.shortDate(candle.timestamp)
                Text("Date: \(dateStr)")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)

                if let overview = appState.marketOverview {
                    RegimeBadge(regime: overview.marketRegime)
                }
            }
        }
    }

    // MARK: - Results Panel

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionHeader(title: "Results", icon: "chart.bar")

            if let results = viewModel.replayResults() {
                HStack(spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replay P&L")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                        Text(FormatHelper.pnl(results.totalPnl))
                            .font(AppFont.price())
                            .foregroundStyle(Color.forChange(results.totalPnl))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Buy & Hold")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                        Text(String(format: "%.1f%%", results.buyAndHoldPnl))
                            .font(AppFont.price())
                            .foregroundStyle(Color.forChange(results.buyAndHoldPnl))
                    }
                }

                Text("\(results.tradeCount) trades, \(results.winCount) wins")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)
            }

            // Closed replay trades
            ForEach(viewModel.replayTrades.filter(\.isClosed), id: \.entryTime) { trade in
                HStack {
                    TagPill(text: trade.side.rawValue.uppercased(), color: trade.side == .long ? .gainGreen : .lossRed, style: .filled)
                    if let pnl = trade.pnl {
                        Text(FormatHelper.pnl(pnl))
                            .font(AppFont.mono())
                            .foregroundStyle(Color.forChange(pnl))
                    }
                    Spacer()
                }
            }
        }
    }
}
