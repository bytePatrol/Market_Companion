// ReplayViewModel.swift
// MarketCompanion
//
// Manages state for the market replay mode: candle stepping, playback, and replay trades.

import SwiftUI

// MARK: - Replay Results

struct ReplayResults {
    let totalPnl: Double
    let buyAndHoldPnl: Double
    let tradeCount: Int
    let winCount: Int
    let equityCurve: [(index: Int, cumPnl: Double)]
}

// MARK: - Replay View Model

@MainActor
final class ReplayViewModel: ObservableObject {
    @Published var replaySymbol: String = ""
    @Published var startDate: Date = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
    @Published var endDate: Date = Date()
    @Published var replayCandles: [Candle] = []
    @Published var replayIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var playbackSpeed: Double = 1.0
    @Published var replayTrades: [Trade] = []
    @Published var isLoading = false
    @Published var hasStarted = false

    weak var appState: AppState?
    private var playbackTimer: Timer?

    var visibleCandles: [Candle] {
        guard !replayCandles.isEmpty, replayIndex >= 0 else { return [] }
        return Array(replayCandles.prefix(replayIndex + 1))
    }

    var currentCandle: Candle? {
        guard replayIndex >= 0, replayIndex < replayCandles.count else { return nil }
        return replayCandles[replayIndex]
    }

    var currentPrice: Double {
        currentCandle?.close ?? 0
    }

    var progress: Double {
        guard replayCandles.count > 1 else { return 0 }
        return Double(replayIndex) / Double(replayCandles.count - 1)
    }

    var isAtEnd: Bool {
        replayIndex >= replayCandles.count - 1
    }

    // MARK: - Load Data

    func loadReplayData() async {
        guard let appState, !replaySymbol.isEmpty else { return }
        isLoading = true

        do {
            let bars = try await appState.dataProvider.fetchDailyBars(
                symbol: replaySymbol.uppercased(),
                from: startDate,
                to: endDate
            )

            replayCandles = bars
                .sorted { $0.date < $1.date }
                .map { bar in
                    Candle(
                        symbol: bar.symbol,
                        timestamp: bar.date,
                        open: bar.open,
                        high: bar.high,
                        low: bar.low,
                        close: bar.close,
                        volume: bar.volume
                    )
                }

            replayIndex = 0
            replayTrades = []
            hasStarted = true
        } catch {
            print("[Replay] Load error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Playback Controls

    func stepForward() {
        guard replayIndex < replayCandles.count - 1 else {
            pause()
            return
        }
        replayIndex += 1
    }

    func stepBack() {
        guard replayIndex > 0 else { return }
        replayIndex -= 1
    }

    func play() {
        guard !isPlaying, !isAtEnd else { return }
        isPlaying = true

        let interval = 1.0 / playbackSpeed
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                if self.isAtEnd {
                    self.pause()
                } else {
                    self.replayIndex += 1
                }
            }
        }
    }

    func pause() {
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    func setSpeed(_ speed: Double) {
        playbackSpeed = speed
        if isPlaying {
            pause()
            play()
        }
    }

    // MARK: - Replay Trades

    func placeTrade(side: TradeSide, qty: Double) {
        guard let candle = currentCandle else { return }
        let trade = Trade(
            symbol: replaySymbol.uppercased(),
            side: side,
            qty: qty,
            entryPrice: candle.close,
            entryTime: candle.timestamp,
            tags: "replay"
        )
        replayTrades.append(trade)
    }

    func closeLastTrade() {
        guard let candle = currentCandle else { return }
        if let idx = replayTrades.lastIndex(where: { !$0.isClosed }) {
            replayTrades[idx].exitPrice = candle.close
            replayTrades[idx].exitTime = candle.timestamp
        }
    }

    // MARK: - Results

    func replayResults() -> ReplayResults? {
        guard !replayCandles.isEmpty, hasStarted else { return nil }

        let closedTrades = replayTrades.filter(\.isClosed)
        let totalPnl = closedTrades.compactMap(\.pnl).reduce(0, +)
        let winCount = closedTrades.filter { ($0.pnl ?? 0) > 0 }.count

        // Buy and hold comparison
        let firstPrice = replayCandles.first?.close ?? 0
        let lastPrice = visibleCandles.last?.close ?? 0
        let buyAndHoldPnl = firstPrice > 0 ? (lastPrice - firstPrice) / firstPrice * 100 : 0

        // Equity curve
        var cumPnl = 0.0
        let curve: [(index: Int, cumPnl: Double)] = closedTrades.enumerated().compactMap { idx, trade in
            guard let pnl = trade.pnl else { return nil }
            cumPnl += pnl
            return (index: idx, cumPnl: cumPnl)
        }

        return ReplayResults(
            totalPnl: totalPnl,
            buyAndHoldPnl: buyAndHoldPnl,
            tradeCount: closedTrades.count,
            winCount: winCount,
            equityCurve: curve
        )
    }

    func reset() {
        pause()
        replayCandles = []
        replayIndex = 0
        replayTrades = []
        hasStarted = false
    }
}
