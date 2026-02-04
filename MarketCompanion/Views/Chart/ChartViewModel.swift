// ChartViewModel.swift
// MarketCompanion
//
// Manages data loading, indicator computation, and viewport state
// for the interactive candlestick chart.

import SwiftUI

@MainActor
final class ChartViewModel: ObservableObject {
    // Symbol & interval
    @Published var symbol: String = ""
    @Published var interval: CandleInterval = .daily
    @Published var configuration = ChartConfiguration()

    // Data
    @Published var candles: [Candle] = []
    @Published var indicatorData = ChartIndicatorData()

    // State
    @Published var isLoading = false
    @Published var error: String?

    // Viewport — visibleRange defines which candles are shown
    @Published var visibleRange: Range<Int> = 0..<0

    // Crosshair
    @Published var crosshairIndex: Int?
    @Published var crosshairPrice: Double?

    // Drawings (Feature #3)
    @Published var drawings: [ChartDrawing] = []
    @Published var drawingMode: DrawingMode = .none
    @Published var activeDrawing: ChartDrawing?
    @Published var selectedDrawingId: Int64?

    // Comparisons (Feature #4)
    @Published var comparisonSymbols: [String] = []
    @Published var comparisonCandles: [String: [Candle]] = [:]
    @Published var normalizeMode: Bool = false

    // Volume Profile
    @Published var volumeProfileData: VolumeProfileData?

    // Trade Plan
    @Published var tradePlan: TradePlan?
    @Published var showTradePlanPanel: Bool = false

    // Dependencies — set via configure()
    weak var appState: AppState?

    /// Price axis width reserved on the right side of the chart
    static let priceAxisWidth: CGFloat = 60

    func configure(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Computed

    /// Computes candle width for a given chart width. Call from Canvas rendering.
    func candleWidth(for chartWidth: CGFloat) -> CGFloat {
        let count = visibleRange.count
        guard count > 0 else { return 8 }
        let available = chartWidth - Self.priceAxisWidth
        return max(2, available / CGFloat(count))
    }

    /// Chart area width (excluding price axis) for a given total width
    func chartAreaWidth(for totalWidth: CGFloat) -> CGFloat {
        totalWidth - Self.priceAxisWidth
    }

    /// Price range for the visible candles with padding
    func visiblePriceRange() -> (min: Double, max: Double, range: Double)? {
        guard visibleRange.count > 0,
              visibleRange.lowerBound >= 0,
              visibleRange.upperBound <= candles.count else { return nil }

        let visible = candles[visibleRange]
        guard let lo = visible.map(\.low).min(),
              let hi = visible.map(\.high).max() else { return nil }

        let rawRange = hi - lo
        let padding = max(rawRange * 0.05, 0.01) // 5% padding or minimum
        let minP = lo - padding
        let maxP = hi + padding
        return (min: minP, max: maxP, range: maxP - minP)
    }

    // MARK: - Load Data

    func loadData() async {
        guard let appState, !symbol.isEmpty else { return }
        isLoading = true
        error = nil

        do {
            switch interval {
            case .daily, .weekly:
                let bars = try appState.dailyBarRepo.forSymbol(symbol, limit: 365)
                candles = bars.map { bar in
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

                if candles.count < 30 {
                    let calendar = Calendar.current
                    let to = Date()
                    let from = calendar.date(byAdding: .day, value: -180, to: to)!
                    let fetchedBars = try await appState.dataProvider.fetchDailyBars(symbol: symbol, from: from, to: to)
                    try appState.dailyBarRepo.save(fetchedBars)
                    candles = fetchedBars.map { bar in
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
                }

            default:
                let range = DateRange.lastDays(5)
                candles = try await appState.dataProvider.fetchCandles(symbol: symbol, range: range, interval: interval)
            }

            // Ensure chronological order
            candles.sort { $0.timestamp < $1.timestamp }

            // Show the most recent 60 candles (or fewer if not enough data)
            let visibleCount = max(20, min(candles.count, 60))
            let start = max(0, candles.count - visibleCount)
            visibleRange = start..<candles.count

            recalculateIndicators()
            loadDrawings()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Indicator Recalculation

    func recalculateIndicators() {
        guard !candles.isEmpty else { return }

        let closes = candles.map(\.close)
        let highs = candles.map(\.high)
        let lows = candles.map(\.low)
        let volumes = candles.map(\.volume)

        var data = ChartIndicatorData()

        for overlay in configuration.overlays {
            switch overlay.type {
            case .sma:
                let period = Int(overlay.parameters["period"] ?? 20)
                let values = TechnicalIndicators.sma(closes, period: period)
                data.smaLines.append((color: overlay.color, period: period, values: values))

            case .ema:
                let period = Int(overlay.parameters["period"] ?? 9)
                let values = TechnicalIndicators.ema(closes, period: period)
                data.emaLines.append((color: overlay.color, period: period, values: values))

            case .bollingerBands:
                let period = Int(overlay.parameters["period"] ?? 20)
                let multiplier = overlay.parameters["multiplier"] ?? 2.0
                let bb = TechnicalIndicators.bollingerBands(closes, period: period, multiplier: multiplier)
                data.bollingerBands = (color: overlay.color, upper: bb.upper, middle: bb.middle, lower: bb.lower)

            case .vwap:
                let values = TechnicalIndicators.vwap(highs: highs, lows: lows, closes: closes, volumes: volumes)
                data.vwap = (color: overlay.color, values: values)

            case .ichimokuCloud:
                let t = Int(overlay.parameters["tenkan"] ?? 9)
                let k = Int(overlay.parameters["kijun"] ?? 26)
                let s = Int(overlay.parameters["senkou"] ?? 52)
                data.ichimoku = TechnicalIndicators.ichimokuCloud(highs: highs, lows: lows, closes: closes, tenkan: t, kijun: k, senkou: s)
            }
        }

        for subchart in configuration.subchartIndicators {
            switch subchart.type {
            case .rsi:
                let period = Int(subchart.parameters["period"] ?? 14)
                data.rsi = TechnicalIndicators.rsi(closes, period: period)

            case .macd:
                let fast = Int(subchart.parameters["fast"] ?? 12)
                let slow = Int(subchart.parameters["slow"] ?? 26)
                let signal = Int(subchart.parameters["signal"] ?? 9)
                data.macd = TechnicalIndicators.macd(closes, fast: fast, slow: slow, signal: signal)

            case .atr:
                let period = Int(subchart.parameters["period"] ?? 14)
                data.atr = TechnicalIndicators.atr(highs: highs, lows: lows, closes: closes, period: period)

            case .stochastic:
                let kPeriod = Int(subchart.parameters["kPeriod"] ?? 14)
                let dPeriod = Int(subchart.parameters["dPeriod"] ?? 3)
                data.stochastic = TechnicalIndicators.stochastic(highs: highs, lows: lows, closes: closes, kPeriod: kPeriod, dPeriod: dPeriod)

            case .obv:
                data.obv = TechnicalIndicators.obv(closes: closes, volumes: volumes)

            case .adx:
                let period = Int(subchart.parameters["period"] ?? 14)
                data.adx = TechnicalIndicators.adx(highs: highs, lows: lows, closes: closes, period: period)
            }
        }

        indicatorData = data

        // Recalculate volume profile if enabled
        if configuration.showVolumeProfile {
            recalculateVolumeProfile()
        } else {
            volumeProfileData = nil
        }
    }

    // MARK: - Volume Profile

    func recalculateVolumeProfile() {
        guard visibleRange.count > 0,
              visibleRange.lowerBound >= 0,
              visibleRange.upperBound <= candles.count else {
            volumeProfileData = nil
            return
        }

        let visibleCandles = Array(candles[visibleRange])
        guard let pr = visiblePriceRange() else {
            volumeProfileData = nil
            return
        }

        volumeProfileData = VolumeProfileRenderer.compute(
            candles: visibleCandles,
            priceMin: pr.min,
            priceMax: pr.max
        )
    }

    // MARK: - Viewport Control

    /// Zoom by changing the number of visible candles.
    /// Positive step = zoom out (more candles), negative = zoom in (fewer).
    func zoom(step: Int, anchor: CGFloat = 0.5) {
        let currentCount = visibleRange.count
        let newCount = max(15, min(candles.count, currentCount + step))
        guard newCount != currentCount else { return }

        // Keep the anchor point stable (0.0 = left edge, 1.0 = right edge)
        let anchorIndex = visibleRange.lowerBound + Int(CGFloat(currentCount) * anchor)
        let leftPortion = CGFloat(anchorIndex - visibleRange.lowerBound) / CGFloat(currentCount)
        let newStart = anchorIndex - Int(CGFloat(newCount) * leftPortion)

        let clampedStart = max(0, min(candles.count - newCount, newStart))
        visibleRange = clampedStart..<(clampedStart + newCount)
    }

    /// Pan by a number of candles (positive = shift right / newer, negative = shift left / older)
    func pan(candleShift: Int) {
        guard candleShift != 0 else { return }

        let count = visibleRange.count
        var newStart = visibleRange.lowerBound - candleShift
        newStart = max(0, min(candles.count - count, newStart))
        visibleRange = newStart..<(newStart + count)
    }

    func handleHover(at location: CGPoint, chartSize: CGSize) {
        guard !candles.isEmpty, visibleRange.count > 0 else {
            crosshairIndex = nil
            crosshairPrice = nil
            return
        }

        let cw = candleWidth(for: chartSize.width)
        let chartW = chartAreaWidth(for: chartSize.width)
        let index = visibleRange.lowerBound + Int(location.x / cw)

        guard index >= visibleRange.lowerBound, index < visibleRange.upperBound,
              location.x < chartW else {
            crosshairIndex = nil
            crosshairPrice = nil
            return
        }

        crosshairIndex = index

        if let pr = visiblePriceRange() {
            let yFraction = 1.0 - Double(location.y / chartSize.height)
            crosshairPrice = pr.min + yFraction * pr.range
        }
    }

    func clearCrosshair() {
        crosshairIndex = nil
        crosshairPrice = nil
    }

    // MARK: - Drawings

    func loadDrawings() {
        guard let appState, !symbol.isEmpty else { return }
        drawings = appState.chartDrawingRepo.forSymbol(symbol)
    }

    func saveDrawing(_ drawing: ChartDrawing) {
        guard let appState else { return }
        var d = drawing
        do {
            try appState.chartDrawingRepo.save(&d)
            loadDrawings()
        } catch {
            print("[Chart] Failed to save drawing: \(error)")
        }
    }

    func deleteDrawing(id: Int64) {
        guard let appState else { return }
        do {
            try appState.chartDrawingRepo.delete(id: id)
            loadDrawings()
            if selectedDrawingId == id { selectedDrawingId = nil }
        } catch {
            print("[Chart] Failed to delete drawing: \(error)")
        }
    }

    func clearAllDrawings() {
        guard let appState, !symbol.isEmpty else { return }
        do {
            try appState.chartDrawingRepo.deleteAll(symbol: symbol)
            drawings = []
            selectedDrawingId = nil
        } catch {
            print("[Chart] Failed to clear drawings: \(error)")
        }
    }

    /// Converts screen coordinates to price/time for drawing creation
    func handleDrawingGesture(start: CGPoint, current: CGPoint, ended: Bool, chartSize: CGSize) {
        guard drawingMode != .none, visibleRange.count > 0 else { return }
        guard let pr = visiblePriceRange() else { return }

        let cw = candleWidth(for: chartSize.width)

        func pointToData(_ pt: CGPoint) -> (price: Double, time: Date) {
            let candleIdx = visibleRange.lowerBound + Int(pt.x / cw)
            let clampedIdx = max(0, min(candles.count - 1, candleIdx))
            let time = candles[clampedIdx].timestamp
            let yFraction = 1.0 - Double(pt.y / chartSize.height)
            let price = pr.min + yFraction * pr.range
            return (price, time)
        }

        let startData = pointToData(start)
        let currentData = pointToData(current)

        let drawingType: DrawingType
        switch drawingMode {
        case .trendLine: drawingType = .trendLine
        case .horizontalLine: drawingType = .horizontalLine
        case .fibonacci: drawingType = .fibonacciRetracement
        case .textAnnotation: drawingType = .textAnnotation
        case .none: return
        }

        if ended {
            let drawing = ChartDrawing(
                symbol: symbol,
                type: drawingType,
                startPrice: startData.price,
                startTime: startData.time,
                endPrice: drawingType == .horizontalLine ? nil : currentData.price,
                endTime: drawingType == .horizontalLine ? nil : currentData.time,
                color: "#00FFFF"
            )
            saveDrawing(drawing)
            activeDrawing = nil
        } else {
            activeDrawing = ChartDrawing(
                symbol: symbol,
                type: drawingType,
                startPrice: startData.price,
                startTime: startData.time,
                endPrice: currentData.price,
                endTime: currentData.time,
                color: "#00FFFF"
            )
        }
    }

    // MARK: - Comparisons

    static let comparisonColors: [String] = ["#00FFFF", "#FF8C00", "#FF69B4", "#98FB98", "#6366F1"]

    func addComparison(symbol compSymbol: String) {
        let sym = compSymbol.uppercased()
        guard !sym.isEmpty, !comparisonSymbols.contains(sym), sym != symbol else { return }
        comparisonSymbols.append(sym)
        Task { await loadComparisonData(for: sym) }
    }

    func removeComparison(symbol compSymbol: String) {
        comparisonSymbols.removeAll { $0 == compSymbol }
        comparisonCandles.removeValue(forKey: compSymbol)
    }

    func loadComparisonData(for compSymbol: String) async {
        guard let appState else { return }
        do {
            let calendar = Calendar.current
            let from = calendar.date(byAdding: .day, value: -365, to: Date())!
            let bars = try await appState.dataProvider.fetchDailyBars(symbol: compSymbol, from: from, to: Date())
            let compCandles = bars
                .sorted { $0.date < $1.date }
                .map { Candle(symbol: $0.symbol, timestamp: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }
            comparisonCandles[compSymbol] = compCandles
        } catch {
            print("[Chart] Failed to load comparison for \(compSymbol): \(error)")
        }
    }

    // MARK: - Helpers

    var currentCandle: Candle? {
        guard let index = crosshairIndex, index >= 0, index < candles.count else { return nil }
        return candles[index]
    }

    var latestQuote: Quote? {
        appState?.quote(for: symbol)
    }

    // MARK: - Export Helpers

    func exportableCandles() -> [Candle] {
        guard visibleRange.count > 0,
              visibleRange.lowerBound >= 0,
              visibleRange.upperBound <= candles.count else { return [] }
        return Array(candles[visibleRange])
    }

    func exportableIndicatorData() -> ChartIndicatorData {
        indicatorData
    }
}
