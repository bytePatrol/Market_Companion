// TechnicalIndicators.swift
// MarketCompanion
//
// Pure-math technical indicator library. Stateless, no side effects.

import Foundation

// MARK: - Result Types

struct BollingerBands {
    let upper: [Double]
    let middle: [Double]
    let lower: [Double]
    let bandwidth: [Double]
}

struct MACDResult {
    let macdLine: [Double]
    let signalLine: [Double]
    let histogram: [Double]
}

struct RSIResult {
    let values: [Double]
}

struct StochasticResult {
    let k: [Double]
    let d: [Double]
}

struct IchimokuResult {
    let tenkan: [Double]
    let kijun: [Double]
    let senkouA: [Double]
    let senkouB: [Double]
    let chikou: [Double]
}

struct ADXResult {
    let plusDI: [Double]
    let minusDI: [Double]
    let adx: [Double]
}

enum IndicatorType: String, CaseIterable, Identifiable, Hashable {
    case sma = "SMA"
    case ema = "EMA"
    case rsi = "RSI"
    case macd = "MACD"
    case bollingerBands = "Bollinger Bands"
    case atr = "ATR"
    case vwap = "VWAP"

    var id: String { rawValue }

    var isOverlay: Bool {
        switch self {
        case .sma, .ema, .bollingerBands, .vwap: return true
        case .rsi, .macd, .atr: return false
        }
    }
}

// MARK: - Technical Indicators

enum TechnicalIndicators {

    // MARK: - Simple Moving Average

    static func sma(_ closes: [Double], period: Int) -> [Double] {
        guard closes.count >= period, period > 0 else { return [] }

        var result: [Double] = []
        result.reserveCapacity(closes.count - period + 1)

        var windowSum = closes[0..<period].reduce(0, +)
        result.append(windowSum / Double(period))

        for i in period..<closes.count {
            windowSum += closes[i] - closes[i - period]
            result.append(windowSum / Double(period))
        }

        return result
    }

    // MARK: - Exponential Moving Average

    static func ema(_ closes: [Double], period: Int) -> [Double] {
        guard closes.count >= period, period > 0 else { return [] }

        let multiplier = 2.0 / Double(period + 1)
        var result: [Double] = []
        result.reserveCapacity(closes.count - period + 1)

        // Seed with SMA of first `period` values
        let seedSMA = closes[0..<period].reduce(0, +) / Double(period)
        result.append(seedSMA)

        for i in period..<closes.count {
            let emaValue = (closes[i] - result.last!) * multiplier + result.last!
            result.append(emaValue)
        }

        return result
    }

    // MARK: - Relative Strength Index

    static func rsi(_ closes: [Double], period: Int = 14) -> RSIResult {
        guard closes.count > period, period > 0 else { return RSIResult(values: []) }

        var gains: [Double] = []
        var losses: [Double] = []

        for i in 1..<closes.count {
            let change = closes[i] - closes[i - 1]
            gains.append(max(change, 0))
            losses.append(max(-change, 0))
        }

        guard gains.count >= period else { return RSIResult(values: []) }

        var avgGain = gains[0..<period].reduce(0, +) / Double(period)
        var avgLoss = losses[0..<period].reduce(0, +) / Double(period)

        var rsiValues: [Double] = []
        rsiValues.reserveCapacity(gains.count - period + 1)

        let rsiValue: Double
        if avgLoss == 0 {
            rsiValue = 100
        } else {
            let rs = avgGain / avgLoss
            rsiValue = 100 - (100 / (1 + rs))
        }
        rsiValues.append(rsiValue)

        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)

            if avgLoss == 0 {
                rsiValues.append(100)
            } else {
                let rs = avgGain / avgLoss
                rsiValues.append(100 - (100 / (1 + rs)))
            }
        }

        return RSIResult(values: rsiValues)
    }

    // MARK: - MACD

    static func macd(_ closes: [Double], fast: Int = 12, slow: Int = 26, signal: Int = 9) -> MACDResult {
        let fastEMA = ema(closes, period: fast)
        let slowEMA = ema(closes, period: slow)

        guard !fastEMA.isEmpty, !slowEMA.isEmpty else {
            return MACDResult(macdLine: [], signalLine: [], histogram: [])
        }

        // Align: fastEMA has more points than slowEMA
        let offset = fastEMA.count - slowEMA.count
        let macdLine = zip(fastEMA.dropFirst(offset), slowEMA).map { $0 - $1 }

        let signalLine = ema(macdLine, period: signal)

        guard !signalLine.isEmpty else {
            return MACDResult(macdLine: macdLine, signalLine: [], histogram: [])
        }

        let signalOffset = macdLine.count - signalLine.count
        let histogram = zip(macdLine.dropFirst(signalOffset), signalLine).map { $0 - $1 }

        return MACDResult(macdLine: macdLine, signalLine: signalLine, histogram: histogram)
    }

    // MARK: - Bollinger Bands

    static func bollingerBands(_ closes: [Double], period: Int = 20, multiplier: Double = 2.0) -> BollingerBands {
        let middle = sma(closes, period: period)
        guard !middle.isEmpty else {
            return BollingerBands(upper: [], middle: [], lower: [], bandwidth: [])
        }

        var upper: [Double] = []
        var lower: [Double] = []
        var bandwidth: [Double] = []
        upper.reserveCapacity(middle.count)
        lower.reserveCapacity(middle.count)
        bandwidth.reserveCapacity(middle.count)

        for i in 0..<middle.count {
            let windowStart = i
            let windowEnd = i + period
            let window = Array(closes[windowStart..<windowEnd])
            let mean = middle[i]

            let variance = window.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(period)
            let stdDev = sqrt(variance)

            upper.append(mean + multiplier * stdDev)
            lower.append(mean - multiplier * stdDev)

            if mean > 0 {
                bandwidth.append((upper.last! - lower.last!) / mean)
            } else {
                bandwidth.append(0)
            }
        }

        return BollingerBands(upper: upper, middle: middle, lower: lower, bandwidth: bandwidth)
    }

    // MARK: - Average True Range

    static func atr(highs: [Double], lows: [Double], closes: [Double], period: Int = 14) -> [Double] {
        let count = min(highs.count, lows.count, closes.count)
        guard count > period, period > 0 else { return [] }

        // Calculate true ranges
        var trueRanges: [Double] = []
        trueRanges.reserveCapacity(count)

        trueRanges.append(highs[0] - lows[0])

        for i in 1..<count {
            let highLow = highs[i] - lows[i]
            let highClose = abs(highs[i] - closes[i - 1])
            let lowClose = abs(lows[i] - closes[i - 1])
            trueRanges.append(max(highLow, highClose, lowClose))
        }

        // First ATR is simple average
        var atrValues: [Double] = []
        atrValues.reserveCapacity(count - period)

        let firstATR = trueRanges[0..<period].reduce(0, +) / Double(period)
        atrValues.append(firstATR)

        // Subsequent values use smoothed method
        for i in period..<count {
            let smoothed = (atrValues.last! * Double(period - 1) + trueRanges[i]) / Double(period)
            atrValues.append(smoothed)
        }

        return atrValues
    }

    // MARK: - Candlestick Pattern Detection

    static func detectBullishEngulfing(candles: [Candle]) -> Bool {
        guard candles.count >= 2 else { return false }
        let prev = candles[candles.count - 2]
        let curr = candles[candles.count - 1]
        let prevBody = prev.close - prev.open
        let currBody = curr.close - curr.open
        return prevBody < 0 && currBody > 0 &&
               curr.open <= prev.close && curr.close >= prev.open
    }

    static func detectBearishEngulfing(candles: [Candle]) -> Bool {
        guard candles.count >= 2 else { return false }
        let prev = candles[candles.count - 2]
        let curr = candles[candles.count - 1]
        let prevBody = prev.close - prev.open
        let currBody = curr.close - curr.open
        return prevBody > 0 && currBody < 0 &&
               curr.open >= prev.close && curr.close <= prev.open
    }

    static func detectHammer(candles: [Candle]) -> Bool {
        guard let candle = candles.last else { return false }
        let bodySize = abs(candle.close - candle.open)
        let lowerWick = min(candle.open, candle.close) - candle.low
        let upperWick = candle.high - max(candle.open, candle.close)
        let range = candle.high - candle.low
        guard range > 0 else { return false }
        return lowerWick > bodySize * 2 && upperWick < bodySize * 0.5
    }

    static func detectDoji(candles: [Candle]) -> Bool {
        guard let candle = candles.last else { return false }
        let range = candle.high - candle.low
        guard range > 0 else { return false }
        let bodySize = abs(candle.close - candle.open)
        return bodySize / range < 0.001 + 0.001 // within ~0.1% of range
    }

    static func detectMorningStar(candles: [Candle]) -> Bool {
        guard candles.count >= 3 else { return false }
        let first = candles[candles.count - 3]
        let second = candles[candles.count - 2]
        let third = candles[candles.count - 1]

        let firstBody = first.close - first.open
        let secondBodySize = abs(second.close - second.open)
        let thirdBody = third.close - third.open
        let firstRange = first.high - first.low

        guard firstRange > 0 else { return false }
        return firstBody < 0 &&  // first is bearish
               secondBodySize < abs(firstBody) * 0.3 &&  // second is small
               thirdBody > 0 &&  // third is bullish
               third.close > (first.open + first.close) / 2  // third closes above midpoint of first
    }

    // MARK: - VWAP

    static func vwap(highs: [Double], lows: [Double], closes: [Double], volumes: [Int64]) -> [Double] {
        let count = min(highs.count, lows.count, closes.count, volumes.count)
        guard count > 0 else { return [] }

        var cumulativeTPV: Double = 0
        var cumulativeVolume: Double = 0
        var vwapValues: [Double] = []
        vwapValues.reserveCapacity(count)

        for i in 0..<count {
            let typicalPrice = (highs[i] + lows[i] + closes[i]) / 3.0
            let vol = Double(volumes[i])

            cumulativeTPV += typicalPrice * vol
            cumulativeVolume += vol

            if cumulativeVolume > 0 {
                vwapValues.append(cumulativeTPV / cumulativeVolume)
            } else {
                vwapValues.append(typicalPrice)
            }
        }

        return vwapValues
    }

    // MARK: - Stochastic Oscillator

    static func stochastic(
        highs: [Double],
        lows: [Double],
        closes: [Double],
        kPeriod: Int = 14,
        dPeriod: Int = 3
    ) -> StochasticResult {
        let count = min(highs.count, lows.count, closes.count)
        guard count >= kPeriod, kPeriod > 0, dPeriod > 0 else {
            return StochasticResult(k: [], d: [])
        }

        var kValues: [Double] = []
        kValues.reserveCapacity(count - kPeriod + 1)

        for i in (kPeriod - 1)..<count {
            let windowStart = i - kPeriod + 1
            let highestHigh = highs[windowStart...i].max()!
            let lowestLow = lows[windowStart...i].min()!
            let range = highestHigh - lowestLow

            if range > 0 {
                kValues.append((closes[i] - lowestLow) / range * 100)
            } else {
                kValues.append(50)
            }
        }

        let dValues = sma(kValues, period: dPeriod)
        return StochasticResult(k: kValues, d: dValues)
    }

    // MARK: - Ichimoku Cloud

    static func ichimokuCloud(
        highs: [Double],
        lows: [Double],
        closes: [Double],
        tenkan: Int = 9,
        kijun: Int = 26,
        senkou: Int = 52
    ) -> IchimokuResult {
        let count = min(highs.count, lows.count, closes.count)
        guard count >= senkou else {
            return IchimokuResult(tenkan: [], kijun: [], senkouA: [], senkouB: [], chikou: [])
        }

        func midpoint(_ data: [Double], period: Int, at index: Int) -> Double {
            let start = index - period + 1
            guard start >= 0 else { return 0 }
            let slice = data[start...index]
            return (slice.max()! + slice.min()!) / 2.0
        }

        var tenkanValues: [Double] = []
        var kijunValues: [Double] = []
        var senkouAValues: [Double] = []
        var senkouBValues: [Double] = []

        for i in 0..<count {
            let tenkanH = i >= tenkan - 1 ? midpoint(highs, period: tenkan, at: i) : 0
            let tenkanL = i >= tenkan - 1 ? midpoint(lows, period: tenkan, at: i) : 0
            let kijunH = i >= kijun - 1 ? midpoint(highs, period: kijun, at: i) : 0
            let kijunL = i >= kijun - 1 ? midpoint(lows, period: kijun, at: i) : 0

            let tVal = (tenkanH + tenkanL) / 2.0
            let kVal = (kijunH + kijunL) / 2.0

            tenkanValues.append(i >= tenkan - 1 ? tVal : 0)
            kijunValues.append(i >= kijun - 1 ? kVal : 0)

            // Senkou A = (Tenkan + Kijun) / 2, plotted kijun periods ahead
            if i >= kijun - 1 {
                senkouAValues.append((tVal + kVal) / 2.0)
            }

            // Senkou B = midpoint of senkou period, plotted kijun periods ahead
            if i >= senkou - 1 {
                let sH = highs[(i - senkou + 1)...i].max()!
                let sL = lows[(i - senkou + 1)...i].min()!
                senkouBValues.append((sH + sL) / 2.0)
            }
        }

        // Chikou Span = current close plotted kijun periods back
        let chikouValues = Array(closes)

        return IchimokuResult(
            tenkan: tenkanValues,
            kijun: kijunValues,
            senkouA: senkouAValues,
            senkouB: senkouBValues,
            chikou: chikouValues
        )
    }

    // MARK: - On-Balance Volume

    static func obv(closes: [Double], volumes: [Int64]) -> [Double] {
        let count = min(closes.count, volumes.count)
        guard count > 0 else { return [] }

        var obvValues: [Double] = []
        obvValues.reserveCapacity(count)

        var cumulative: Double = 0
        obvValues.append(cumulative)

        for i in 1..<count {
            if closes[i] > closes[i - 1] {
                cumulative += Double(volumes[i])
            } else if closes[i] < closes[i - 1] {
                cumulative -= Double(volumes[i])
            }
            obvValues.append(cumulative)
        }

        return obvValues
    }

    // MARK: - Average Directional Index

    static func adx(
        highs: [Double],
        lows: [Double],
        closes: [Double],
        period: Int = 14
    ) -> ADXResult {
        let count = min(highs.count, lows.count, closes.count)
        guard count > period + 1, period > 0 else {
            return ADXResult(plusDI: [], minusDI: [], adx: [])
        }

        // Step 1: True Range, +DM, -DM
        var trueRanges: [Double] = []
        var plusDM: [Double] = []
        var minusDM: [Double] = []

        for i in 1..<count {
            let highLow = highs[i] - lows[i]
            let highClose = abs(highs[i] - closes[i - 1])
            let lowClose = abs(lows[i] - closes[i - 1])
            trueRanges.append(max(highLow, highClose, lowClose))

            let upMove = highs[i] - highs[i - 1]
            let downMove = lows[i - 1] - lows[i]

            if upMove > downMove && upMove > 0 {
                plusDM.append(upMove)
            } else {
                plusDM.append(0)
            }

            if downMove > upMove && downMove > 0 {
                minusDM.append(downMove)
            } else {
                minusDM.append(0)
            }
        }

        guard trueRanges.count >= period else {
            return ADXResult(plusDI: [], minusDI: [], adx: [])
        }

        // Step 2: Smoothed TR, +DM, -DM (Wilder smoothing)
        var smoothedTR = trueRanges[0..<period].reduce(0, +)
        var smoothedPlusDM = plusDM[0..<period].reduce(0, +)
        var smoothedMinusDM = minusDM[0..<period].reduce(0, +)

        var plusDIValues: [Double] = []
        var minusDIValues: [Double] = []
        var dxValues: [Double] = []

        func computeDI() {
            let pDI = smoothedTR > 0 ? (smoothedPlusDM / smoothedTR) * 100 : 0
            let mDI = smoothedTR > 0 ? (smoothedMinusDM / smoothedTR) * 100 : 0
            plusDIValues.append(pDI)
            minusDIValues.append(mDI)

            let diSum = pDI + mDI
            let dx = diSum > 0 ? abs(pDI - mDI) / diSum * 100 : 0
            dxValues.append(dx)
        }

        computeDI()

        for i in period..<trueRanges.count {
            smoothedTR = smoothedTR - (smoothedTR / Double(period)) + trueRanges[i]
            smoothedPlusDM = smoothedPlusDM - (smoothedPlusDM / Double(period)) + plusDM[i]
            smoothedMinusDM = smoothedMinusDM - (smoothedMinusDM / Double(period)) + minusDM[i]
            computeDI()
        }

        // Step 3: ADX = smoothed average of DX
        guard dxValues.count >= period else {
            return ADXResult(plusDI: plusDIValues, minusDI: minusDIValues, adx: [])
        }

        var adxValues: [Double] = []
        var adxSmoothed = dxValues[0..<period].reduce(0, +) / Double(period)
        adxValues.append(adxSmoothed)

        for i in period..<dxValues.count {
            adxSmoothed = (adxSmoothed * Double(period - 1) + dxValues[i]) / Double(period)
            adxValues.append(adxSmoothed)
        }

        return ADXResult(plusDI: plusDIValues, minusDI: minusDIValues, adx: adxValues)
    }
}
