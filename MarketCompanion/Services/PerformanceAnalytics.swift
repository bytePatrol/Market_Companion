// PerformanceAnalytics.swift
// MarketCompanion
//
// Pure-function analytics engine for trade performance metrics.

import Foundation

// MARK: - Performance Metrics

struct PerformanceMetrics {
    let totalPnl: Double
    let winRate: Double
    let profitFactor: Double
    let sharpeRatio: Double
    let maxDrawdown: Double
    let maxDrawdownPercent: Double
    let averageWin: Double
    let averageLoss: Double
    let largestWin: Double
    let largestLoss: Double
    let expectancy: Double
    let averageHoldingPeriodMinutes: Double
    let consecutiveWins: Int
    let consecutiveLosses: Int
    let bestDay: (date: Date, pnl: Double)?
    let worstDay: (date: Date, pnl: Double)?
    let tradeCount: Int
    let winCount: Int
    let lossCount: Int
}

// MARK: - Performance Analytics

enum PerformanceAnalytics {

    // MARK: - Compute Metrics

    static func compute(from trades: [Trade]) -> PerformanceMetrics {
        let closed = trades.filter { $0.isClosed }
        guard !closed.isEmpty else {
            return PerformanceMetrics(
                totalPnl: 0, winRate: 0, profitFactor: 0, sharpeRatio: 0,
                maxDrawdown: 0, maxDrawdownPercent: 0, averageWin: 0, averageLoss: 0,
                largestWin: 0, largestLoss: 0, expectancy: 0, averageHoldingPeriodMinutes: 0,
                consecutiveWins: 0, consecutiveLosses: 0, bestDay: nil, worstDay: nil,
                tradeCount: 0, winCount: 0, lossCount: 0
            )
        }

        let pnls = closed.compactMap(\.pnl)
        let totalPnl = pnls.reduce(0, +)

        let wins = pnls.filter { $0 > 0 }
        let losses = pnls.filter { $0 < 0 }

        let winRate = Double(wins.count) / Double(pnls.count) * 100
        let grossProfits = wins.reduce(0, +)
        let grossLosses = abs(losses.reduce(0, +))
        let profitFactor = grossLosses > 0 ? grossProfits / grossLosses : (grossProfits > 0 ? .infinity : 0)

        let averageWin = wins.isEmpty ? 0 : grossProfits / Double(wins.count)
        let averageLoss = losses.isEmpty ? 0 : grossLosses / Double(losses.count)
        let largestWin = wins.max() ?? 0
        let largestLoss = losses.min() ?? 0

        let expectancy = wins.isEmpty && losses.isEmpty ? 0 :
            (winRate / 100 * averageWin) - ((1 - winRate / 100) * averageLoss)

        // Sharpe ratio (annualized, assuming 252 trading days)
        let meanReturn = pnls.reduce(0, +) / Double(pnls.count)
        let variance = pnls.reduce(0.0) { $0 + ($1 - meanReturn) * ($1 - meanReturn) } / Double(pnls.count)
        let stdDev = sqrt(variance)
        let sharpeRatio = stdDev > 0 ? (meanReturn / stdDev) * sqrt(252.0) : 0

        // Max drawdown
        var peak = 0.0
        var cumPnl = 0.0
        var maxDD = 0.0
        var maxDDPercent = 0.0

        for pnl in pnls {
            cumPnl += pnl
            if cumPnl > peak { peak = cumPnl }
            let dd = peak - cumPnl
            if dd > maxDD {
                maxDD = dd
                maxDDPercent = peak > 0 ? dd / peak * 100 : 0
            }
        }

        // Holding period
        let durations = closed.compactMap { trade -> Double? in
            guard let exit = trade.exitTime else { return nil }
            return exit.timeIntervalSince(trade.entryTime) / 60.0
        }
        let avgHolding = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)

        // Consecutive wins/losses
        let sorted = closed.sorted { ($0.exitTime ?? $0.entryTime) < ($1.exitTime ?? $1.entryTime) }
        var maxConsWins = 0, maxConsLosses = 0
        var currentWins = 0, currentLosses = 0

        for trade in sorted {
            let isWin = (trade.pnl ?? 0) > 0
            if isWin {
                currentWins += 1
                currentLosses = 0
                maxConsWins = max(maxConsWins, currentWins)
            } else {
                currentLosses += 1
                currentWins = 0
                maxConsLosses = max(maxConsLosses, currentLosses)
            }
        }

        // Best/worst day
        let calendar = Calendar.current
        let dailyPnl = Dictionary(grouping: closed) { trade in
            calendar.startOfDay(for: trade.exitTime ?? trade.entryTime)
        }.map { (date: $0.key, pnl: $0.value.compactMap(\.pnl).reduce(0, +)) }

        let bestDay = dailyPnl.max(by: { $0.pnl < $1.pnl })
        let worstDay = dailyPnl.min(by: { $0.pnl < $1.pnl })

        return PerformanceMetrics(
            totalPnl: totalPnl,
            winRate: winRate,
            profitFactor: profitFactor,
            sharpeRatio: sharpeRatio,
            maxDrawdown: maxDD,
            maxDrawdownPercent: maxDDPercent,
            averageWin: averageWin,
            averageLoss: averageLoss,
            largestWin: largestWin,
            largestLoss: largestLoss,
            expectancy: expectancy,
            averageHoldingPeriodMinutes: avgHolding,
            consecutiveWins: maxConsWins,
            consecutiveLosses: maxConsLosses,
            bestDay: bestDay,
            worstDay: worstDay,
            tradeCount: closed.count,
            winCount: wins.count,
            lossCount: losses.count
        )
    }

    // MARK: - Equity Curve

    static func equityCurve(from trades: [Trade]) -> [(date: Date, cumPnl: Double)] {
        let closed = trades.filter { $0.isClosed }
            .sorted { ($0.exitTime ?? $0.entryTime) < ($1.exitTime ?? $1.entryTime) }

        var cumPnl = 0.0
        return closed.compactMap { trade -> (date: Date, cumPnl: Double)? in
            guard let pnl = trade.pnl else { return nil }
            cumPnl += pnl
            return (date: trade.exitTime ?? trade.entryTime, cumPnl: cumPnl)
        }
    }

    // MARK: - Drawdown Series

    static func drawdownSeries(from trades: [Trade]) -> [(date: Date, drawdown: Double)] {
        let curve = equityCurve(from: trades)
        var peak = 0.0

        return curve.map { point in
            if point.cumPnl > peak { peak = point.cumPnl }
            let dd = peak - point.cumPnl
            return (date: point.date, drawdown: dd)
        }
    }

    // MARK: - By Tag

    static func byTag(from trades: [Trade]) -> [(tag: String, metrics: PerformanceMetrics)] {
        let closed = trades.filter { $0.isClosed }
        var tagGroups: [String: [Trade]] = [:]

        for trade in closed {
            let tags = trade.tagList
            if tags.isEmpty {
                tagGroups["untagged", default: []].append(trade)
            } else {
                for tag in tags {
                    tagGroups[tag, default: []].append(trade)
                }
            }
        }

        return tagGroups
            .map { (tag: $0.key, metrics: compute(from: $0.value)) }
            .sorted { $0.metrics.totalPnl > $1.metrics.totalPnl }
    }

    // MARK: - Monthly P&L

    static func monthlyPnl(from trades: [Trade]) -> [(month: String, pnl: Double)] {
        let closed = trades.filter { $0.isClosed }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        let grouped = Dictionary(grouping: closed) { trade in
            formatter.string(from: trade.exitTime ?? trade.entryTime)
        }

        return grouped.map { (month: $0.key, pnl: $0.value.compactMap(\.pnl).reduce(0, +)) }
            .sorted { $0.month < $1.month }
    }
}
