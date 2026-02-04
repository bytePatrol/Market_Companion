// ChartModels.swift
// MarketCompanion
//
// Configuration and data models for the interactive candlestick chart.

import SwiftUI

// MARK: - Drawing Mode

enum DrawingMode: Equatable {
    case none
    case trendLine
    case horizontalLine
    case fibonacci
    case textAnnotation
}

// MARK: - Chart Configuration

struct ChartConfiguration {
    var interval: CandleInterval = .daily
    var overlays: [OverlayIndicator] = []
    var subchartIndicators: [SubchartIndicator] = []
    var showVolume: Bool = true
    var showVolumeProfile: Bool = false
    var showCrosshair: Bool = true
    var drawingMode: DrawingMode = .none
}

// MARK: - Overlay Indicator (drawn on price chart)

struct OverlayIndicator: Identifiable, Hashable {
    let id = UUID()
    var type: OverlayType
    var parameters: [String: Double]
    var color: Color

    enum OverlayType: String, CaseIterable, Hashable {
        case sma = "SMA"
        case ema = "EMA"
        case bollingerBands = "BB"
        case vwap = "VWAP"
        case ichimokuCloud = "Ichimoku"
    }

    static func defaultSMA(period: Int = 20) -> OverlayIndicator {
        OverlayIndicator(type: .sma, parameters: ["period": Double(period)], color: .yellow)
    }

    static func defaultEMA(period: Int = 9) -> OverlayIndicator {
        OverlayIndicator(type: .ema, parameters: ["period": Double(period)], color: .cyan)
    }

    static func defaultBB() -> OverlayIndicator {
        OverlayIndicator(type: .bollingerBands, parameters: ["period": 20, "multiplier": 2.0], color: .purple)
    }

    static func defaultVWAP() -> OverlayIndicator {
        OverlayIndicator(type: .vwap, parameters: [:], color: .orange)
    }

    static func defaultIchimoku() -> OverlayIndicator {
        OverlayIndicator(type: .ichimokuCloud, parameters: ["tenkan": 9, "kijun": 26, "senkou": 52], color: .teal)
    }
}

// MARK: - Subchart Indicator (drawn in separate pane)

struct SubchartIndicator: Identifiable, Hashable {
    let id = UUID()
    var type: SubchartType
    var parameters: [String: Double]

    enum SubchartType: String, CaseIterable, Hashable {
        case rsi = "RSI"
        case macd = "MACD"
        case atr = "ATR"
        case stochastic = "Stochastic"
        case obv = "OBV"
        case adx = "ADX"
    }

    static func defaultRSI() -> SubchartIndicator {
        SubchartIndicator(type: .rsi, parameters: ["period": 14])
    }

    static func defaultMACD() -> SubchartIndicator {
        SubchartIndicator(type: .macd, parameters: ["fast": 12, "slow": 26, "signal": 9])
    }

    static func defaultATR() -> SubchartIndicator {
        SubchartIndicator(type: .atr, parameters: ["period": 14])
    }

    static func defaultStochastic() -> SubchartIndicator {
        SubchartIndicator(type: .stochastic, parameters: ["kPeriod": 14, "dPeriod": 3])
    }

    static func defaultOBV() -> SubchartIndicator {
        SubchartIndicator(type: .obv, parameters: [:])
    }

    static func defaultADX() -> SubchartIndicator {
        SubchartIndicator(type: .adx, parameters: ["period": 14])
    }
}

// MARK: - Pre-computed Indicator Data

struct ChartIndicatorData {
    // Overlays
    var smaLines: [(color: Color, period: Int, values: [Double])] = []
    var emaLines: [(color: Color, period: Int, values: [Double])] = []
    var bollingerBands: (color: Color, upper: [Double], middle: [Double], lower: [Double])?
    var vwap: (color: Color, values: [Double])?

    // Overlays (extended)
    var ichimoku: IchimokuResult?

    // Subcharts
    var rsi: RSIResult?
    var macd: MACDResult?
    var atr: [Double]?
    var stochastic: StochasticResult?
    var obv: [Double]?
    var adx: ADXResult?
}
