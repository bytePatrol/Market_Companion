// TechnicalScreener.swift
// MarketCompanion
//
// Scans symbols against technical criteria using existing indicator library.

import Foundation

// MARK: - Scan Types

enum TechnicalScanCriteria: String, CaseIterable, Identifiable, Hashable {
    case rsiOversold = "RSI Oversold (<30)"
    case rsiOverbought = "RSI Overbought (>70)"
    case macdBullishCross = "MACD Bullish Cross"
    case macdBearishCross = "MACD Bearish Cross"
    case bollingerSqueeze = "Bollinger Squeeze"
    case priceAboveSMA50 = "Price > SMA(50)"
    case priceBelowSMA50 = "Price < SMA(50)"
    case goldenCross = "Golden Cross (SMA 50/200)"
    case deathCross = "Death Cross (SMA 50/200)"
    case volumeSurge = "Volume Surge (>2x Avg)"
    case stochasticOversold = "Stochastic Oversold"
    case adxTrending = "ADX Trending (>25)"

    var id: String { rawValue }
}

struct ScanResult: Identifiable {
    let id = UUID()
    let symbol: String
    let matchedCriteria: [TechnicalScanCriteria]
    let lastPrice: Double
    let changePct: Double
}

struct ScanTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let criteria: [TechnicalScanCriteria]
    let description: String

    static let presets: [ScanTemplate] = [
        ScanTemplate(
            name: "Oversold Bounce",
            icon: "arrow.up.circle",
            criteria: [.rsiOversold, .stochasticOversold],
            description: "RSI and Stochastic both oversold"
        ),
        ScanTemplate(
            name: "Breakout",
            icon: "bolt.circle",
            criteria: [.priceAboveSMA50, .volumeSurge, .adxTrending],
            description: "Above SMA50 with volume and trend"
        ),
        ScanTemplate(
            name: "Momentum",
            icon: "flame.circle",
            criteria: [.macdBullishCross, .priceAboveSMA50],
            description: "MACD bullish with price strength"
        ),
        ScanTemplate(
            name: "Bearish Setup",
            icon: "arrow.down.circle",
            criteria: [.rsiOverbought, .macdBearishCross],
            description: "Overbought with bearish MACD"
        ),
    ]
}

// MARK: - Scanner

enum TechnicalScreener {

    static func scan(
        quotes: [Quote],
        barData: [String: [DailyBar]],
        criteria: Set<TechnicalScanCriteria>
    ) -> [ScanResult] {
        guard !criteria.isEmpty else { return [] }

        var results: [ScanResult] = []

        for quote in quotes {
            guard let bars = barData[quote.symbol], bars.count >= 20 else { continue }

            let closes = bars.map(\.close)
            let highs = bars.map(\.high)
            let lows = bars.map(\.low)
            let volumes = bars.map(\.volume)

            var matched: [TechnicalScanCriteria] = []

            for criterion in criteria {
                if test(criterion, closes: closes, highs: highs, lows: lows, volumes: volumes, quote: quote) {
                    matched.append(criterion)
                }
            }

            if !matched.isEmpty {
                results.append(ScanResult(
                    symbol: quote.symbol,
                    matchedCriteria: matched,
                    lastPrice: quote.last,
                    changePct: quote.changePct
                ))
            }
        }

        // Sort by number of matched criteria descending
        results.sort { $0.matchedCriteria.count > $1.matchedCriteria.count }
        return results
    }

    private static func test(
        _ criterion: TechnicalScanCriteria,
        closes: [Double],
        highs: [Double],
        lows: [Double],
        volumes: [Int64],
        quote: Quote
    ) -> Bool {
        switch criterion {
        case .rsiOversold:
            let rsi = TechnicalIndicators.rsi(closes)
            guard let last = rsi.values.last else { return false }
            return last < 30

        case .rsiOverbought:
            let rsi = TechnicalIndicators.rsi(closes)
            guard let last = rsi.values.last else { return false }
            return last > 70

        case .macdBullishCross:
            let macd = TechnicalIndicators.macd(closes)
            guard macd.histogram.count >= 2 else { return false }
            let prev = macd.histogram[macd.histogram.count - 2]
            let curr = macd.histogram[macd.histogram.count - 1]
            return prev < 0 && curr >= 0

        case .macdBearishCross:
            let macd = TechnicalIndicators.macd(closes)
            guard macd.histogram.count >= 2 else { return false }
            let prev = macd.histogram[macd.histogram.count - 2]
            let curr = macd.histogram[macd.histogram.count - 1]
            return prev > 0 && curr <= 0

        case .bollingerSqueeze:
            let bb = TechnicalIndicators.bollingerBands(closes)
            guard let lastBW = bb.bandwidth.last, bb.bandwidth.count >= 20 else { return false }
            let avgBW = bb.bandwidth.suffix(20).reduce(0, +) / 20.0
            return lastBW < avgBW * 0.5

        case .priceAboveSMA50:
            let sma = TechnicalIndicators.sma(closes, period: 50)
            guard let lastSMA = sma.last, let lastClose = closes.last else { return false }
            return lastClose > lastSMA

        case .priceBelowSMA50:
            let sma = TechnicalIndicators.sma(closes, period: 50)
            guard let lastSMA = sma.last, let lastClose = closes.last else { return false }
            return lastClose < lastSMA

        case .goldenCross:
            let sma50 = TechnicalIndicators.sma(closes, period: 50)
            let sma200 = TechnicalIndicators.sma(closes, period: 200)
            guard sma50.count >= 2, sma200.count >= 2 else { return false }
            let offset50 = sma50.count - sma200.count
            guard offset50 >= 1 else { return false }
            let prev50 = sma50[sma50.count - 2]
            let curr50 = sma50[sma50.count - 1]
            let prev200 = sma200[sma200.count - 2]
            let curr200 = sma200[sma200.count - 1]
            return prev50 <= prev200 && curr50 > curr200

        case .deathCross:
            let sma50 = TechnicalIndicators.sma(closes, period: 50)
            let sma200 = TechnicalIndicators.sma(closes, period: 200)
            guard sma50.count >= 2, sma200.count >= 2 else { return false }
            let offset50 = sma50.count - sma200.count
            guard offset50 >= 1 else { return false }
            let prev50 = sma50[sma50.count - 2]
            let curr50 = sma50[sma50.count - 1]
            let prev200 = sma200[sma200.count - 2]
            let curr200 = sma200[sma200.count - 1]
            return prev50 >= prev200 && curr50 < curr200

        case .volumeSurge:
            return quote.volumeRatio >= 2.0

        case .stochasticOversold:
            let stoch = TechnicalIndicators.stochastic(highs: highs, lows: lows, closes: closes)
            guard let lastK = stoch.k.last else { return false }
            return lastK < 20

        case .adxTrending:
            let adxResult = TechnicalIndicators.adx(highs: highs, lows: lows, closes: closes)
            guard let lastADX = adxResult.adx.last else { return false }
            return lastADX > 25
        }
    }
}
