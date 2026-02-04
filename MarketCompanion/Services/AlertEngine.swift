// AlertEngine.swift
// MarketCompanion
//
// Background engine that evaluates alert rules against live market data.
// Supports: volume spikes, trend breaks, unusual volatility.

import Foundation
import UserNotifications

@MainActor
final class AlertEngine: ObservableObject {
    private let dataProvider: MarketDataProvider
    private let alertRuleRepo: AlertRuleRepository
    private let alertEventRepo: AlertEventRepository
    private let quoteRepo: QuoteRepository
    private let dailyBarRepo: DailyBarRepository

    private var pollingTimer: Timer?
    private var isRunning = false

    @Published var lastCheckTime: Date?
    @Published var totalChecks: Int = 0

    init(
        dataProvider: MarketDataProvider,
        alertRuleRepo: AlertRuleRepository,
        alertEventRepo: AlertEventRepository,
        quoteRepo: QuoteRepository,
        dailyBarRepo: DailyBarRepository
    ) {
        self.dataProvider = dataProvider
        self.alertRuleRepo = alertRuleRepo
        self.alertEventRepo = alertEventRepo
        self.quoteRepo = quoteRepo
        self.dailyBarRepo = dailyBarRepo
    }

    // MARK: - Lifecycle

    func startPolling(interval: TimeInterval = 60) {
        guard !isRunning else { return }
        isRunning = true

        requestNotificationPermission()

        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAllRules()
            }
        }

        // Run immediately on start
        Task {
            await checkAllRules()
        }

        print("[AlertEngine] Polling started (interval: \(Int(interval))s)")
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isRunning = false
        print("[AlertEngine] Polling stopped")
    }

    // MARK: - Rule Evaluation

    func checkAllRules() async {
        do {
            let rules = try alertRuleRepo.enabled()
            guard !rules.isEmpty else { return }

            // Gather all symbols from rules
            let symbols = rules.compactMap(\.symbol)
            guard !symbols.isEmpty else { return }

            // Fetch latest quotes
            let quotes = try await dataProvider.fetchQuotes(symbols: Array(Set(symbols)))
            try quoteRepo.upsert(quotes)

            let quoteMap = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0) })

            for rule in rules {
                if let events = try evaluateRule(rule, quoteMap: quoteMap) {
                    for event in events {
                        var mutableEvent = event
                        try alertEventRepo.save(&mutableEvent)
                        await deliverNotification(event: event)
                    }
                }
            }

            lastCheckTime = Date()
            totalChecks += 1
        } catch {
            print("[AlertEngine] Check failed: \(error)")
        }
    }

    private func evaluateRule(_ rule: AlertRule, quoteMap: [String: Quote]) throws -> [AlertEvent]? {
        switch rule.type {
        case .volumeSpike:
            return try evaluateVolumeSpike(rule, quoteMap: quoteMap)
        case .trendBreak:
            return try evaluateTrendBreak(rule, quoteMap: quoteMap)
        case .unusualVolatility:
            return try evaluateUnusualVolatility(rule, quoteMap: quoteMap)
        case .rsiOverbought:
            return try evaluateRSIOverbought(rule, quoteMap: quoteMap)
        case .rsiOversold:
            return try evaluateRSIOversold(rule, quoteMap: quoteMap)
        case .macdCrossover:
            return try evaluateMACDCrossover(rule, quoteMap: quoteMap)
        case .bollingerSqueeze:
            return try evaluateBollingerSqueeze(rule, quoteMap: quoteMap)
        case .priceAboveMA:
            return try evaluatePriceVsMA(rule, quoteMap: quoteMap, above: true)
        case .priceBelowMA:
            return try evaluatePriceVsMA(rule, quoteMap: quoteMap, above: false)
        case .bullishEngulfing:
            return try evaluatePattern(rule, pattern: "Bullish Engulfing") { TechnicalIndicators.detectBullishEngulfing(candles: $0) }
        case .bearishEngulfing:
            return try evaluatePattern(rule, pattern: "Bearish Engulfing") { TechnicalIndicators.detectBearishEngulfing(candles: $0) }
        case .hammer:
            return try evaluatePattern(rule, pattern: "Hammer") { TechnicalIndicators.detectHammer(candles: $0) }
        case .doji:
            return try evaluatePattern(rule, pattern: "Doji") { TechnicalIndicators.detectDoji(candles: $0) }
        case .composite:
            return try evaluateComposite(rule, quoteMap: quoteMap)
        }
    }

    // MARK: - Volume Spike

    private func evaluateVolumeSpike(_ rule: AlertRule, quoteMap: [String: Quote]) throws -> [AlertEvent]? {
        guard let ruleId = rule.id else { return nil }

        if let symbol = rule.symbol {
            // Symbol-specific rule
            guard let quote = quoteMap[symbol] else { return nil }
            if quote.volumeRatio >= rule.thresholdValue {
                // Check if we already alerted recently (within 1 hour)
                let recent = try alertEventRepo.forRule(ruleId)
                if let last = recent.first, Date().timeIntervalSince(last.triggeredAt) < 3600 {
                    return nil
                }

                return [AlertEvent(
                    ruleId: ruleId,
                    summary: "\(symbol) volume spike: \(String(format: "%.1f", quote.volumeRatio))x average",
                    details: "Current volume: \(FormatHelper.volume(quote.volume)) vs avg \(FormatHelper.volume(quote.avgVolume)). Price: \(FormatHelper.price(quote.last)) (\(FormatHelper.percent(quote.changePct)))"
                )]
            }
        } else {
            // Market-wide: check all quotes
            var events: [AlertEvent] = []
            for (symbol, quote) in quoteMap {
                if quote.volumeRatio >= rule.thresholdValue {
                    events.append(AlertEvent(
                        ruleId: ruleId,
                        summary: "\(symbol) volume spike: \(String(format: "%.1f", quote.volumeRatio))x average",
                        details: "Volume: \(FormatHelper.volume(quote.volume)) vs avg \(FormatHelper.volume(quote.avgVolume))"
                    ))
                }
            }
            return events.isEmpty ? nil : events
        }

        return nil
    }

    // MARK: - Trend Break

    private func evaluateTrendBreak(_ rule: AlertRule, quoteMap: [String: Quote]) throws -> [AlertEvent]? {
        guard let ruleId = rule.id, let symbol = rule.symbol else { return nil }
        guard let quote = quoteMap[symbol] else { return nil }

        let bars = try dailyBarRepo.forSymbol(symbol, limit: 50)
        guard bars.count >= 20 else { return nil }

        // Calculate 20-day simple moving average
        let last20 = bars.suffix(20)
        let sma20 = last20.map(\.close).reduce(0, +) / Double(last20.count)

        // Check for cross
        let previousClose = bars.last?.close ?? quote.last
        let crossedAbove = previousClose < sma20 && quote.last >= sma20
        let crossedBelow = previousClose > sma20 && quote.last <= sma20

        if crossedAbove || crossedBelow {
            let direction = crossedAbove ? "above" : "below"
            let recent = try alertEventRepo.forRule(ruleId)
            if let last = recent.first, Date().timeIntervalSince(last.triggeredAt) < 3600 {
                return nil
            }

            return [AlertEvent(
                ruleId: ruleId,
                summary: "\(symbol) crossed \(direction) 20-day MA (\(FormatHelper.price(sma20)))",
                details: "Current: \(FormatHelper.price(quote.last)). SMA20: \(FormatHelper.price(sma20)). Previous close: \(FormatHelper.price(previousClose))"
            )]
        }

        // Check prior day high/low breaks
        if let yesterday = bars.last {
            if quote.last > yesterday.high {
                let recent = try alertEventRepo.forRule(ruleId)
                if let last = recent.first, Date().timeIntervalSince(last.triggeredAt) < 3600 {
                    return nil
                }
                return [AlertEvent(
                    ruleId: ruleId,
                    summary: "\(symbol) broke above prior day high (\(FormatHelper.price(yesterday.high)))",
                    details: "Current: \(FormatHelper.price(quote.last)). Prior high: \(FormatHelper.price(yesterday.high))"
                )]
            }
            if quote.last < yesterday.low {
                let recent = try alertEventRepo.forRule(ruleId)
                if let last = recent.first, Date().timeIntervalSince(last.triggeredAt) < 3600 {
                    return nil
                }
                return [AlertEvent(
                    ruleId: ruleId,
                    summary: "\(symbol) broke below prior day low (\(FormatHelper.price(yesterday.low)))",
                    details: "Current: \(FormatHelper.price(quote.last)). Prior low: \(FormatHelper.price(yesterday.low))"
                )]
            }
        }

        return nil
    }

    // MARK: - Unusual Volatility

    private func evaluateUnusualVolatility(_ rule: AlertRule, quoteMap: [String: Quote]) throws -> [AlertEvent]? {
        guard let ruleId = rule.id else { return nil }

        if let symbol = rule.symbol {
            guard let quote = quoteMap[symbol] else { return nil }
            let bars = try dailyBarRepo.forSymbol(symbol, limit: 20)
            guard bars.count >= 10 else { return nil }

            let avgRange = bars.map { ($0.high - $0.low) / $0.low * 100 }.reduce(0, +) / Double(bars.count)
            let currentRange = quote.intradayRange

            if avgRange > 0 && currentRange / avgRange >= rule.thresholdValue {
                let recent = try alertEventRepo.forRule(ruleId)
                if let last = recent.first, Date().timeIntervalSince(last.triggeredAt) < 3600 {
                    return nil
                }

                return [AlertEvent(
                    ruleId: ruleId,
                    summary: "\(symbol) unusual volatility: \(String(format: "%.1f", currentRange / avgRange))x typical range",
                    details: "Today's range: \(String(format: "%.2f", currentRange))% vs \(String(format: "%.2f", avgRange))% average. Day high: \(FormatHelper.price(quote.dayHigh)), low: \(FormatHelper.price(quote.dayLow))"
                )]
            }
        } else {
            // Market-wide
            var events: [AlertEvent] = []
            for (symbol, quote) in quoteMap {
                let bars = try dailyBarRepo.forSymbol(symbol, limit: 20)
                guard bars.count >= 10 else { continue }

                let avgRange = bars.map { ($0.high - $0.low) / $0.low * 100 }.reduce(0, +) / Double(bars.count)
                let currentRange = quote.intradayRange

                if avgRange > 0 && currentRange / avgRange >= rule.thresholdValue {
                    events.append(AlertEvent(
                        ruleId: ruleId,
                        summary: "\(symbol) unusual volatility: \(String(format: "%.1f", currentRange / avgRange))x typical",
                        details: "Range: \(String(format: "%.2f", currentRange))% vs \(String(format: "%.2f", avgRange))% average"
                    ))
                }
            }
            return events.isEmpty ? nil : events
        }

        return nil
    }

    // MARK: - RSI Overbought

    private func evaluateRSIOverbought(_ rule: AlertRule, quoteMap: [String: Quote]) throws -> [AlertEvent]? {
        guard let ruleId = rule.id, let symbol = rule.symbol else { return nil }
        let bars = try dailyBarRepo.forSymbol(symbol, limit: 50)
        guard bars.count >= 20 else { return nil }

        let closes = bars.map(\.close)
        let rsi = TechnicalIndicators.rsi(closes, period: 14)
        guard let latestRSI = rsi.values.last else { return nil }

        let threshold = rule.thresholdValue > 0 ? rule.thresholdValue : 70
        if latestRSI >= threshold {
            let recent = try alertEventRepo.forRule(ruleId)
            if let last = recent.first, Date().timeIntervalSince(last.triggeredAt) < 3600 { return nil }

            return [AlertEvent(
                ruleId: ruleId,
                summary: "\(symbol) RSI overbought at \(String(format: "%.1f", latestRSI))",
                details: "RSI(14) = \(String(format: "%.1f", latestRSI)), threshold: \(String(format: "%.0f", threshold))"
            )]
        }
        return nil
    }

    // MARK: - RSI Oversold

    private func evaluateRSIOversold(_ rule: AlertRule, quoteMap: [String: Quote]) throws -> [AlertEvent]? {
        guard let ruleId = rule.id, let symbol = rule.symbol else { return nil }
        let bars = try dailyBarRepo.forSymbol(symbol, limit: 50)
        guard bars.count >= 20 else { return nil }

        let closes = bars.map(\.close)
        let rsi = TechnicalIndicators.rsi(closes, period: 14)
        guard let latestRSI = rsi.values.last else { return nil }

        let threshold = rule.thresholdValue > 0 ? rule.thresholdValue : 30
        if latestRSI <= threshold {
            let recent = try alertEventRepo.forRule(ruleId)
            if let last = recent.first, Date().timeIntervalSince(last.triggeredAt) < 3600 { return nil }

            return [AlertEvent(
                ruleId: ruleId,
                summary: "\(symbol) RSI oversold at \(String(format: "%.1f", latestRSI))",
                details: "RSI(14) = \(String(format: "%.1f", latestRSI)), threshold: \(String(format: "%.0f", threshold))"
            )]
        }
        return nil
    }

    // MARK: - MACD Crossover

    private func evaluateMACDCrossover(_ rule: AlertRule, quoteMap: [String: Quote]) throws -> [AlertEvent]? {
        guard let ruleId = rule.id, let symbol = rule.symbol else { return nil }
        let bars = try dailyBarRepo.forSymbol(symbol, limit: 60)
        guard bars.count >= 35 else { return nil }

        let closes = bars.map(\.close)
        let macd = TechnicalIndicators.macd(closes)
        guard macd.histogram.count >= 2 else { return nil }

        let prev = macd.histogram[macd.histogram.count - 2]
        let curr = macd.histogram[macd.histogram.count - 1]

        // Detect zero-line crossover
        let bullishCross = prev < 0 && curr >= 0
        let bearishCross = prev > 0 && curr <= 0

        if bullishCross || bearishCross {
            let recent = try alertEventRepo.forRule(ruleId)
            if let last = recent.first, Date().timeIntervalSince(last.triggeredAt) < 3600 { return nil }

            let direction = bullishCross ? "bullish" : "bearish"
            return [AlertEvent(
                ruleId: ruleId,
                summary: "\(symbol) MACD \(direction) crossover",
                details: "MACD histogram crossed zero: \(String(format: "%.3f", prev)) -> \(String(format: "%.3f", curr))"
            )]
        }
        return nil
    }

    // MARK: - Bollinger Squeeze

    private func evaluateBollingerSqueeze(_ rule: AlertRule, quoteMap: [String: Quote]) throws -> [AlertEvent]? {
        guard let ruleId = rule.id, let symbol = rule.symbol else { return nil }
        let bars = try dailyBarRepo.forSymbol(symbol, limit: 50)
        guard bars.count >= 25 else { return nil }

        let closes = bars.map(\.close)
        let bb = TechnicalIndicators.bollingerBands(closes)
        guard bb.bandwidth.count >= 2 else { return nil }

        let currentBW = bb.bandwidth.last!
        let avgBW = bb.bandwidth.reduce(0, +) / Double(bb.bandwidth.count)

        // Squeeze = bandwidth significantly below average
        let squeezeThreshold = rule.thresholdValue > 0 ? rule.thresholdValue : 0.5
        if currentBW < avgBW * squeezeThreshold {
            let recent = try alertEventRepo.forRule(ruleId)
            if let last = recent.first, Date().timeIntervalSince(last.triggeredAt) < 3600 { return nil }

            return [AlertEvent(
                ruleId: ruleId,
                summary: "\(symbol) Bollinger Band squeeze detected",
                details: "Bandwidth \(String(format: "%.4f", currentBW)) is \(String(format: "%.0f", (1 - currentBW / avgBW) * 100))% below average"
            )]
        }
        return nil
    }

    // MARK: - Price vs MA

    private func evaluatePriceVsMA(_ rule: AlertRule, quoteMap: [String: Quote], above: Bool) throws -> [AlertEvent]? {
        guard let ruleId = rule.id, let symbol = rule.symbol else { return nil }
        guard let quote = quoteMap[symbol] else { return nil }
        let bars = try dailyBarRepo.forSymbol(symbol, limit: 50)
        guard bars.count >= 20 else { return nil }

        let closes = bars.map(\.close)
        let period = Int(rule.thresholdValue > 1 ? rule.thresholdValue : 20)
        let sma = TechnicalIndicators.sma(closes, period: period)
        guard let latestSMA = sma.last else { return nil }
        guard let prevClose = bars.last?.close else { return nil }

        let crossed: Bool
        if above {
            crossed = prevClose < latestSMA && quote.last >= latestSMA
        } else {
            crossed = prevClose > latestSMA && quote.last <= latestSMA
        }

        if crossed {
            let recent = try alertEventRepo.forRule(ruleId)
            if let last = recent.first, Date().timeIntervalSince(last.triggeredAt) < 3600 { return nil }

            let direction = above ? "above" : "below"
            return [AlertEvent(
                ruleId: ruleId,
                summary: "\(symbol) price crossed \(direction) \(period)-SMA (\(FormatHelper.price(latestSMA)))",
                details: "Current: \(FormatHelper.price(quote.last)), SMA(\(period)): \(FormatHelper.price(latestSMA))"
            )]
        }
        return nil
    }

    // MARK: - Pattern Detection

    private func evaluatePattern(_ rule: AlertRule, pattern: String, detector: ([Candle]) -> Bool) throws -> [AlertEvent]? {
        guard let ruleId = rule.id, let symbol = rule.symbol else { return nil }
        let bars = try dailyBarRepo.forSymbol(symbol, limit: 10)
        guard bars.count >= 3 else { return nil }

        let candles = bars.map { Candle(symbol: $0.symbol, timestamp: $0.date, open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume) }

        if detector(candles) {
            let recent = try alertEventRepo.forRule(ruleId)
            if let last = recent.first, Date().timeIntervalSince(last.triggeredAt) < 3600 { return nil }

            return [AlertEvent(
                ruleId: ruleId,
                summary: "\(symbol) \(pattern) pattern detected",
                details: "Detected on the latest candle(s) for \(symbol)"
            )]
        }
        return nil
    }

    // MARK: - Composite Alert

    private func evaluateComposite(_ rule: AlertRule, quoteMap: [String: Quote]) throws -> [AlertEvent]? {
        guard let ruleId = rule.id, let symbol = rule.symbol else { return nil }
        let conditions = rule.decodedConditions
        guard conditions.count >= 2 else { return nil }
        guard let quote = quoteMap[symbol] else { return nil }

        let bars = try dailyBarRepo.forSymbol(symbol, limit: 50)
        guard bars.count >= 20 else { return nil }

        let closes = bars.map(\.close)

        // Evaluate ALL conditions (AND logic)
        for condition in conditions {
            let currentValue: Double
            switch condition.indicator {
            case .rsi:
                let rsi = TechnicalIndicators.rsi(closes, period: 14)
                guard let latest = rsi.values.last else { return nil }
                currentValue = latest
            case .volume:
                currentValue = quote.volumeRatio
            case .price:
                currentValue = quote.last
            case .macd:
                let macd = TechnicalIndicators.macd(closes)
                guard let latest = macd.histogram.last else { return nil }
                currentValue = latest
            }

            let passes: Bool
            switch condition.comparison {
            case .above:
                passes = currentValue > condition.value
            case .below:
                passes = currentValue < condition.value
            case .crosses:
                passes = abs(currentValue - condition.value) < condition.value * 0.02
            }

            if !passes { return nil }
        }

        // All conditions passed
        let recent = try alertEventRepo.forRule(ruleId)
        if let last = recent.first, Date().timeIntervalSince(last.triggeredAt) < 3600 { return nil }

        let condDesc = conditions.map { "\($0.indicator.rawValue) \($0.comparison.rawValue) \($0.value)" }.joined(separator: " AND ")
        return [AlertEvent(
            ruleId: ruleId,
            summary: "\(symbol) composite alert triggered",
            details: "All conditions met: \(condDesc)"
        )]
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[AlertEngine] Notification permission granted")
            } else if let error {
                print("[AlertEngine] Notification permission error: \(error)")
            }
        }
    }

    private func deliverNotification(event: AlertEvent) async {
        let content = UNMutableNotificationContent()
        content.title = "Market Companion Alert"
        content.body = event.summary
        content.sound = .default
        content.categoryIdentifier = "ALERT_EVENT"

        if !event.details.isEmpty {
            content.subtitle = String(event.details.prefix(80))
        }

        let request = UNNotificationRequest(
            identifier: "alert-\(event.id ?? 0)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("[AlertEngine] Failed to deliver notification: \(error)")
        }
    }
}
