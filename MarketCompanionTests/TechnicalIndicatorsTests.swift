// TechnicalIndicatorsTests.swift
// MarketCompanion

import XCTest
@testable import MarketCompanion

final class TechnicalIndicatorsTests: XCTestCase {

    // MARK: - SMA Tests

    func testSMABasic() {
        let closes = [1.0, 2.0, 3.0, 4.0, 5.0]
        let result = TechnicalIndicators.sma(closes, period: 3)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], 2.0, accuracy: 0.001) // (1+2+3)/3
        XCTAssertEqual(result[1], 3.0, accuracy: 0.001) // (2+3+4)/3
        XCTAssertEqual(result[2], 4.0, accuracy: 0.001) // (3+4+5)/3
    }

    func testSMAInsufficientData() {
        let closes = [1.0, 2.0]
        let result = TechnicalIndicators.sma(closes, period: 5)
        XCTAssertTrue(result.isEmpty)
    }

    func testSMAPeriodOne() {
        let closes = [10.0, 20.0, 30.0]
        let result = TechnicalIndicators.sma(closes, period: 1)
        XCTAssertEqual(result, closes)
    }

    func testSMAPeriodEqualsCount() {
        let closes = [2.0, 4.0, 6.0]
        let result = TechnicalIndicators.sma(closes, period: 3)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], 4.0, accuracy: 0.001)
    }

    // MARK: - EMA Tests

    func testEMABasic() {
        let closes = [22.27, 22.19, 22.08, 22.17, 22.18, 22.13, 22.23, 22.43, 22.24, 22.29,
                      22.15, 22.39, 22.38, 22.61, 23.36, 24.05, 23.75, 23.83, 23.95, 23.63]
        let result = TechnicalIndicators.ema(closes, period: 10)
        XCTAssertEqual(result.count, 11) // 20 - 10 + 1
        // First value is SMA of first 10
        let expectedSMA = closes[0..<10].reduce(0, +) / 10.0
        XCTAssertEqual(result[0], expectedSMA, accuracy: 0.01)
    }

    func testEMAInsufficientData() {
        let closes = [1.0, 2.0]
        let result = TechnicalIndicators.ema(closes, period: 5)
        XCTAssertTrue(result.isEmpty)
    }

    func testEMAConvergence() {
        // Constant series should produce constant EMA
        let closes = Array(repeating: 50.0, count: 30)
        let result = TechnicalIndicators.ema(closes, period: 10)
        for value in result {
            XCTAssertEqual(value, 50.0, accuracy: 0.001)
        }
    }

    // MARK: - RSI Tests

    func testRSIBasic() {
        // Known RSI test data (14-period)
        let closes: [Double] = [
            44.34, 44.09, 43.61, 44.33, 44.83, 45.10, 45.42, 45.84,
            46.08, 45.89, 46.03, 45.61, 46.28, 46.28, 46.00, 46.03,
            46.41, 46.22, 45.64
        ]
        let result = TechnicalIndicators.rsi(closes, period: 14)
        XCTAssertFalse(result.values.isEmpty)

        // First RSI value for this dataset with Wilder's smoothing
        XCTAssertEqual(result.values[0], 66.94, accuracy: 1.0)
    }

    func testRSIBounds() {
        // RSI should always be between 0 and 100
        let closes = [10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0,
                      26.0, 28.0, 30.0, 32.0, 34.0, 36.0, 38.0, 40.0]
        let result = TechnicalIndicators.rsi(closes, period: 14)
        for value in result.values {
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 100)
        }
    }

    func testRSIAllGains() {
        let closes = Array(stride(from: 1.0, through: 20.0, by: 1.0))
        let result = TechnicalIndicators.rsi(closes, period: 14)
        if let first = result.values.first {
            XCTAssertEqual(first, 100.0, accuracy: 0.001)
        }
    }

    func testRSIInsufficientData() {
        let closes = [1.0, 2.0, 3.0]
        let result = TechnicalIndicators.rsi(closes, period: 14)
        XCTAssertTrue(result.values.isEmpty)
    }

    // MARK: - MACD Tests

    func testMACDStructure() {
        // Generate enough data for MACD (need at least 26 + 9 = 35 points)
        var closes: [Double] = []
        for i in 0..<50 {
            closes.append(100.0 + sin(Double(i) * 0.2) * 10)
        }

        let result = TechnicalIndicators.macd(closes)
        XCTAssertFalse(result.macdLine.isEmpty)
        XCTAssertFalse(result.signalLine.isEmpty)
        XCTAssertFalse(result.histogram.isEmpty)
        XCTAssertEqual(result.histogram.count, result.signalLine.count)
    }

    func testMACDInsufficientData() {
        let closes = [1.0, 2.0, 3.0]
        let result = TechnicalIndicators.macd(closes)
        XCTAssertTrue(result.macdLine.isEmpty)
    }

    func testMACDConstantPrice() {
        // Constant price should yield MACD line near zero
        let closes = Array(repeating: 100.0, count: 50)
        let result = TechnicalIndicators.macd(closes)
        for value in result.macdLine {
            XCTAssertEqual(value, 0, accuracy: 0.001)
        }
    }

    // MARK: - Bollinger Bands Tests

    func testBollingerBandsBasic() {
        var closes: [Double] = []
        for i in 0..<30 {
            closes.append(100.0 + Double(i % 5))
        }

        let result = TechnicalIndicators.bollingerBands(closes, period: 20)
        XCTAssertEqual(result.upper.count, result.middle.count)
        XCTAssertEqual(result.lower.count, result.middle.count)
        XCTAssertEqual(result.bandwidth.count, result.middle.count)

        // Upper should always be above middle, middle above lower
        for i in 0..<result.middle.count {
            XCTAssertGreaterThanOrEqual(result.upper[i], result.middle[i])
            XCTAssertLessThanOrEqual(result.lower[i], result.middle[i])
        }
    }

    func testBollingerBandwidthPositive() {
        var closes: [Double] = []
        for i in 0..<30 {
            closes.append(50.0 + sin(Double(i)) * 5)
        }

        let result = TechnicalIndicators.bollingerBands(closes)
        for bw in result.bandwidth {
            XCTAssertGreaterThanOrEqual(bw, 0)
        }
    }

    func testBollingerBandsConstantPrice() {
        let closes = Array(repeating: 100.0, count: 25)
        let result = TechnicalIndicators.bollingerBands(closes, period: 20)
        // With constant price, upper == middle == lower
        for i in 0..<result.middle.count {
            XCTAssertEqual(result.upper[i], result.middle[i], accuracy: 0.001)
            XCTAssertEqual(result.lower[i], result.middle[i], accuracy: 0.001)
        }
    }

    // MARK: - ATR Tests

    func testATRBasic() {
        let highs:  [Double] = [48.70, 48.72, 48.90, 48.87, 48.82, 49.05, 49.20, 49.35, 49.92, 50.19,
                                50.12, 49.66, 49.88, 50.19, 50.36, 50.57]
        let lows:   [Double] = [47.79, 48.14, 48.39, 48.37, 48.24, 48.64, 48.94, 48.86, 49.50, 49.87,
                                49.20, 48.90, 49.43, 49.73, 49.26, 50.09]
        let closes: [Double] = [48.16, 48.61, 48.75, 48.63, 48.74, 49.03, 49.07, 49.32, 49.91, 50.13,
                                49.53, 49.50, 49.75, 50.03, 50.31, 50.52]

        let result = TechnicalIndicators.atr(highs: highs, lows: lows, closes: closes, period: 14)
        XCTAssertFalse(result.isEmpty)
        // ATR should be positive
        for value in result {
            XCTAssertGreaterThan(value, 0)
        }
    }

    func testATRInsufficientData() {
        let result = TechnicalIndicators.atr(highs: [10], lows: [9], closes: [9.5], period: 14)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - VWAP Tests

    func testVWAPBasic() {
        let highs:   [Double] = [101, 102, 103, 104, 105]
        let lows:    [Double] = [99, 100, 101, 102, 103]
        let closes:  [Double] = [100, 101, 102, 103, 104]
        let volumes: [Int64]  = [1000, 2000, 1500, 1000, 3000]

        let result = TechnicalIndicators.vwap(highs: highs, lows: lows, closes: closes, volumes: volumes)
        XCTAssertEqual(result.count, 5)

        // First VWAP = typical price of first bar
        let firstTP = (highs[0] + lows[0] + closes[0]) / 3.0
        XCTAssertEqual(result[0], firstTP, accuracy: 0.001)
    }

    func testVWAPMonotonicity() {
        // With increasing prices and equal volume, VWAP should increase
        let highs:   [Double] = [11, 12, 13, 14, 15]
        let lows:    [Double] = [9, 10, 11, 12, 13]
        let closes:  [Double] = [10, 11, 12, 13, 14]
        let volumes: [Int64]  = [100, 100, 100, 100, 100]

        let result = TechnicalIndicators.vwap(highs: highs, lows: lows, closes: closes, volumes: volumes)
        for i in 1..<result.count {
            XCTAssertGreaterThan(result[i], result[i - 1])
        }
    }

    func testVWAPEmpty() {
        let result = TechnicalIndicators.vwap(highs: [], lows: [], closes: [], volumes: [])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - IndicatorType Tests

    func testIndicatorTypeOverlay() {
        XCTAssertTrue(IndicatorType.sma.isOverlay)
        XCTAssertTrue(IndicatorType.ema.isOverlay)
        XCTAssertTrue(IndicatorType.bollingerBands.isOverlay)
        XCTAssertTrue(IndicatorType.vwap.isOverlay)
        XCTAssertFalse(IndicatorType.rsi.isOverlay)
        XCTAssertFalse(IndicatorType.macd.isOverlay)
        XCTAssertFalse(IndicatorType.atr.isOverlay)
    }
}
