// Models.swift
// MarketCompanion
//
// Core data models for the Market Companion app.

import Foundation

// MARK: - Holding

struct Holding: Codable, Identifiable, Hashable {
    var id: Int64?
    var symbol: String
    var shares: Double?
    var costBasis: Double?
    var tags: String
    var createdAt: Date
    var groupId: Int64?

    init(id: Int64? = nil, symbol: String, shares: Double? = nil, costBasis: Double? = nil, tags: String = "", createdAt: Date = Date(), groupId: Int64? = nil) {
        self.id = id
        self.symbol = symbol
        self.shares = shares
        self.costBasis = costBasis
        self.tags = tags
        self.createdAt = createdAt
        self.groupId = groupId
    }

    var tagList: [String] {
        tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - WatchItem

struct WatchItem: Codable, Identifiable, Hashable {
    var id: Int64?
    var symbol: String
    var reasonTag: String
    var note: String?
    var createdAt: Date
    var source: String?
    var groupId: Int64?

    init(id: Int64? = nil, symbol: String, reasonTag: String, note: String? = nil, createdAt: Date = Date(), source: String? = nil, groupId: Int64? = nil) {
        self.id = id
        self.symbol = symbol
        self.reasonTag = reasonTag
        self.note = note
        self.createdAt = createdAt
        self.source = source
        self.groupId = groupId
    }
}

// MARK: - Quote

struct Quote: Codable, Identifiable, Hashable {
    var id: Int64?
    var symbol: String
    var last: Double
    var changePct: Double
    var volume: Int64
    var avgVolume: Int64
    var dayHigh: Double
    var dayLow: Double
    var updatedAt: Date
    var marketCap: Double?

    init(id: Int64? = nil, symbol: String, last: Double, changePct: Double, volume: Int64, avgVolume: Int64, dayHigh: Double, dayLow: Double, updatedAt: Date = Date(), marketCap: Double? = nil) {
        self.id = id
        self.symbol = symbol
        self.last = last
        self.changePct = changePct
        self.volume = volume
        self.avgVolume = avgVolume
        self.dayHigh = dayHigh
        self.dayLow = dayLow
        self.updatedAt = updatedAt
        self.marketCap = marketCap
    }

    var isUp: Bool { changePct >= 0 }

    var volumeRatio: Double {
        guard avgVolume > 0 else { return 1.0 }
        return Double(volume) / Double(avgVolume)
    }

    var intradayRange: Double {
        guard dayLow > 0 else { return 0 }
        return (dayHigh - dayLow) / dayLow * 100
    }
}

// MARK: - DailyBar

struct DailyBar: Codable, Identifiable, Hashable {
    var id: Int64?
    var symbol: String
    var date: Date
    var open: Double
    var high: Double
    var low: Double
    var close: Double
    var volume: Int64

    init(id: Int64? = nil, symbol: String, date: Date, open: Double, high: Double, low: Double, close: Double, volume: Int64) {
        self.id = id
        self.symbol = symbol
        self.date = date
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }

    var changePercent: Double {
        guard open > 0 else { return 0 }
        return (close - open) / open * 100
    }
}

// MARK: - Report

enum ReportType: String, Codable, CaseIterable {
    case morning = "morning"
    case close = "close"
}

enum ReportMode: String, CaseIterable {
    case concise = "Concise"
    case detailed = "Detailed"
}

struct Report: Codable, Identifiable, Hashable {
    var id: Int64?
    var type: ReportType
    var createdAt: Date
    var jsonPayload: String
    var renderedMarkdown: String

    init(id: Int64? = nil, type: ReportType, createdAt: Date = Date(), jsonPayload: String = "{}", renderedMarkdown: String = "") {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.jsonPayload = jsonPayload
        self.renderedMarkdown = renderedMarkdown
    }
}

// MARK: - AlertRule

enum AlertRuleType: String, Codable, CaseIterable {
    case volumeSpike = "volumeSpike"
    case trendBreak = "trendBreak"
    case unusualVolatility = "unusualVolatility"
    case rsiOverbought = "rsiOverbought"
    case rsiOversold = "rsiOversold"
    case macdCrossover = "macdCrossover"
    case bollingerSqueeze = "bollingerSqueeze"
    case priceAboveMA = "priceAboveMA"
    case priceBelowMA = "priceBelowMA"
    case bullishEngulfing = "bullishEngulfing"
    case bearishEngulfing = "bearishEngulfing"
    case hammer = "hammer"
    case doji = "doji"
    case composite = "composite"
}

// MARK: - Composite Alert Condition

struct CompositeAlertCondition: Codable, Hashable {
    var indicator: CompositeIndicator
    var comparison: CompositeComparison
    var value: Double

    enum CompositeIndicator: String, Codable, CaseIterable, Hashable {
        case rsi = "RSI"
        case volume = "Volume Ratio"
        case price = "Price"
        case macd = "MACD"
    }

    enum CompositeComparison: String, Codable, CaseIterable, Hashable {
        case above = "Above"
        case below = "Below"
        case crosses = "Crosses"
    }
}

struct AlertRule: Codable, Identifiable, Hashable {
    var id: Int64?
    var symbol: String?
    var sector: String?
    var type: AlertRuleType
    var thresholdValue: Double
    var enabled: Bool
    var createdAt: Date
    var compositeConditions: String?

    init(id: Int64? = nil, symbol: String? = nil, sector: String? = nil, type: AlertRuleType, thresholdValue: Double = 2.0, enabled: Bool = true, createdAt: Date = Date(), compositeConditions: String? = nil) {
        self.id = id
        self.symbol = symbol
        self.sector = sector
        self.type = type
        self.thresholdValue = thresholdValue
        self.enabled = enabled
        self.createdAt = createdAt
        self.compositeConditions = compositeConditions
    }

    var displayName: String {
        let target = symbol ?? sector ?? "Market"
        switch type {
        case .volumeSpike: return "\(target) Volume Spike"
        case .trendBreak: return "\(target) Trend Break"
        case .unusualVolatility: return "\(target) Unusual Volatility"
        case .rsiOverbought: return "\(target) RSI Overbought"
        case .rsiOversold: return "\(target) RSI Oversold"
        case .macdCrossover: return "\(target) MACD Crossover"
        case .bollingerSqueeze: return "\(target) Bollinger Squeeze"
        case .priceAboveMA: return "\(target) Price Above MA"
        case .priceBelowMA: return "\(target) Price Below MA"
        case .bullishEngulfing: return "\(target) Bullish Engulfing"
        case .bearishEngulfing: return "\(target) Bearish Engulfing"
        case .hammer: return "\(target) Hammer"
        case .doji: return "\(target) Doji"
        case .composite: return "\(target) Composite Alert"
        }
    }

    var decodedConditions: [CompositeAlertCondition] {
        guard let json = compositeConditions,
              let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([CompositeAlertCondition].self, from: data)) ?? []
    }
}

// MARK: - AlertEvent

struct AlertEvent: Codable, Identifiable, Hashable {
    var id: Int64?
    var ruleId: Int64
    var triggeredAt: Date
    var summary: String
    var details: String

    init(id: Int64? = nil, ruleId: Int64, triggeredAt: Date = Date(), summary: String, details: String = "") {
        self.id = id
        self.ruleId = ruleId
        self.triggeredAt = triggeredAt
        self.summary = summary
        self.details = details
    }
}

// MARK: - Trade

enum TradeSide: String, Codable, CaseIterable {
    case long = "long"
    case short = "short"
}

struct Trade: Codable, Identifiable, Hashable {
    var id: Int64?
    var symbol: String
    var side: TradeSide
    var qty: Double
    var entryPrice: Double
    var exitPrice: Double?
    var entryTime: Date
    var exitTime: Date?
    var notes: String
    var tags: String
    var planEntryPrice: Double?
    var planStopPrice: Double?
    var planTargetPrice: Double?

    init(id: Int64? = nil, symbol: String, side: TradeSide, qty: Double, entryPrice: Double, exitPrice: Double? = nil, entryTime: Date = Date(), exitTime: Date? = nil, notes: String = "", tags: String = "", planEntryPrice: Double? = nil, planStopPrice: Double? = nil, planTargetPrice: Double? = nil) {
        self.id = id
        self.symbol = symbol
        self.side = side
        self.qty = qty
        self.entryPrice = entryPrice
        self.exitPrice = exitPrice
        self.entryTime = entryTime
        self.exitTime = exitTime
        self.notes = notes
        self.tags = tags
        self.planEntryPrice = planEntryPrice
        self.planStopPrice = planStopPrice
        self.planTargetPrice = planTargetPrice
    }

    var isClosed: Bool { exitPrice != nil }

    var pnl: Double? {
        guard let exit = exitPrice else { return nil }
        let multiplier: Double = side == .long ? 1 : -1
        return (exit - entryPrice) * qty * multiplier
    }

    var pnlPercent: Double? {
        guard let exit = exitPrice, entryPrice > 0 else { return nil }
        let multiplier: Double = side == .long ? 1 : -1
        return (exit - entryPrice) / entryPrice * 100 * multiplier
    }

    var tagList: [String] {
        tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - TradeContext

struct TradeContext: Codable, Identifiable, Hashable {
    var id: Int64?
    var tradeId: Int64
    var vixProxy: Double?
    var marketBreadthProxy: Double?
    var sectorStrengthSnapshot: String
    var volatilityRegime: String
    var timeOfDay: String
    var additionalNotes: String
    var checklistJson: String

    init(id: Int64? = nil, tradeId: Int64, vixProxy: Double? = nil, marketBreadthProxy: Double? = nil, sectorStrengthSnapshot: String = "{}", volatilityRegime: String = "normal", timeOfDay: String = "", additionalNotes: String = "", checklistJson: String = "") {
        self.id = id
        self.tradeId = tradeId
        self.vixProxy = vixProxy
        self.marketBreadthProxy = marketBreadthProxy
        self.sectorStrengthSnapshot = sectorStrengthSnapshot
        self.volatilityRegime = volatilityRegime
        self.timeOfDay = timeOfDay
        self.additionalNotes = additionalNotes
        self.checklistJson = checklistJson
    }
}

// MARK: - Supporting Types

struct MarketOverview: Codable {
    var breadthAdvancing: Int
    var breadthDeclining: Int
    var vixProxy: Double
    var volatilityRegime: VolatilityRegime
    var sectorPerformance: [SectorPerformance]
    var updatedAt: Date

    var breadthRatio: Double {
        let total = breadthAdvancing + breadthDeclining
        guard total > 0 else { return 0.5 }
        return Double(breadthAdvancing) / Double(total)
    }

    var marketRegime: String {
        if breadthRatio > 0.65 && volatilityRegime == .low {
            return "Risk-On"
        } else if breadthRatio < 0.35 || volatilityRegime == .high {
            return "Risk-Off"
        } else {
            return "Neutral"
        }
    }
}

enum VolatilityRegime: String, Codable {
    case low = "Low"
    case normal = "Normal"
    case elevated = "Elevated"
    case high = "High"
}

struct SectorPerformance: Codable, Identifiable, Hashable {
    var id: String { sector }
    var sector: String
    var changePct: Double
    var leaderSymbol: String
    var leaderChangePct: Double
}

// MARK: - Sector Classification

enum MarketSector: String, CaseIterable {
    case technology = "Technology"
    case financials = "Financials"
    case healthcare = "Healthcare"
    case energy = "Energy"
    case consumer = "Consumer"
    case industrials = "Industrials"
    case communication = "Communication"
    case utilities = "Utilities"
    case realEstate = "Real Estate"
    case materials = "Materials"

    static func classify(_ symbol: String) -> MarketSector {
        switch symbol {
        case "AAPL", "MSFT", "NVDA", "AMD", "INTC", "CRM", "ORCL", "ADBE":
            return .technology
        case "GOOGL", "GOOG", "META", "NFLX", "DIS":
            return .communication
        case "AMZN", "TSLA", "NKE", "SBUX", "MCD", "HD", "WMT", "COST":
            return .consumer
        case "JPM", "BAC", "GS", "MS", "V", "MA", "BRK.B":
            return .financials
        case "JNJ", "PFE", "UNH", "ABBV", "MRK", "LLY":
            return .healthcare
        case "XOM", "CVX", "COP", "SLB":
            return .energy
        case "BA", "CAT", "GE", "HON", "UPS":
            return .industrials
        case "NEE", "DUK", "SO":
            return .utilities
        default:
            return .technology
        }
    }
}
