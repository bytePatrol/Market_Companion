// PortfolioAnalytics.swift
// MarketCompanion
//
// Portfolio-level risk analytics: correlation, beta, concentration, volatility.

import Foundation

enum PortfolioAnalytics {

    // MARK: - Correlation Matrix

    /// Pairwise Pearson correlations from daily returns.
    static func correlationMatrix(bars: [String: [DailyBar]], period: Int = 60) -> (symbols: [String], matrix: [[Double]]) {
        let symbols = Array(bars.keys).sorted()
        guard symbols.count >= 2 else { return (symbols, []) }

        // Compute daily returns for each symbol
        var returns: [String: [Double]] = [:]
        for sym in symbols {
            guard let dailyBars = bars[sym], dailyBars.count > 1 else { continue }
            let sorted = dailyBars.sorted { $0.date < $1.date }.suffix(period + 1)
            let closes = Array(sorted.map(\.close))
            var rets: [Double] = []
            for i in 1..<closes.count {
                rets.append((closes[i] - closes[i-1]) / closes[i-1])
            }
            returns[sym] = rets
        }

        // Build matrix
        var matrix = Array(repeating: Array(repeating: 0.0, count: symbols.count), count: symbols.count)
        for i in 0..<symbols.count {
            for j in 0..<symbols.count {
                if i == j {
                    matrix[i][j] = 1.0
                } else if i < j {
                    let corr = pearsonCorrelation(returns[symbols[i]] ?? [], returns[symbols[j]] ?? [])
                    matrix[i][j] = corr
                    matrix[j][i] = corr
                }
            }
        }

        return (symbols, matrix)
    }

    // MARK: - Beta

    /// Beta = covariance(symbol, benchmark) / variance(benchmark)
    static func beta(symbolBars: [DailyBar], benchmarkBars: [DailyBar]) -> Double {
        let symReturns = dailyReturns(symbolBars)
        let benchReturns = dailyReturns(benchmarkBars)

        let n = min(symReturns.count, benchReturns.count)
        guard n > 1 else { return 1.0 }

        let sym = Array(symReturns.suffix(n))
        let bench = Array(benchReturns.suffix(n))

        let meanSym = sym.reduce(0, +) / Double(n)
        let meanBench = bench.reduce(0, +) / Double(n)

        var covariance = 0.0
        var variance = 0.0
        for i in 0..<n {
            covariance += (sym[i] - meanSym) * (bench[i] - meanBench)
            variance += (bench[i] - meanBench) * (bench[i] - meanBench)
        }

        guard variance > 0 else { return 1.0 }
        return covariance / variance
    }

    // MARK: - Sector Concentration

    static func sectorConcentration(holdings: [Holding], quotes: [Quote]) -> [(sector: String, pctOfPortfolio: Double)] {
        var sectorValues: [String: Double] = [:]
        var totalValue = 0.0

        for holding in holdings {
            let price = quotes.first(where: { $0.symbol == holding.symbol })?.last ?? 0
            let shares = holding.shares ?? 0
            let value = price * shares
            let sector = MarketSector.classify(holding.symbol).rawValue
            sectorValues[sector, default: 0] += value
            totalValue += value
        }

        guard totalValue > 0 else { return [] }

        return sectorValues
            .map { (sector: $0.key, pctOfPortfolio: $0.value / totalValue * 100) }
            .sorted { $0.pctOfPortfolio > $1.pctOfPortfolio }
    }

    // MARK: - Portfolio Volatility

    /// Annualized portfolio standard deviation.
    static func portfolioVolatility(bars: [String: [DailyBar]], weights: [String: Double]) -> Double {
        let symbols = Array(weights.keys).sorted()
        guard symbols.count > 0 else { return 0 }

        var returns: [String: [Double]] = [:]
        for sym in symbols {
            returns[sym] = dailyReturns(bars[sym] ?? [])
        }

        // Compute portfolio returns per day
        let n = returns.values.map(\.count).min() ?? 0
        guard n > 1 else { return 0 }

        var portfolioReturns: [Double] = []
        for i in 0..<n {
            var dayReturn = 0.0
            for sym in symbols {
                let w = weights[sym] ?? 0
                let r = returns[sym]?[returns[sym]!.count - n + i] ?? 0
                dayReturn += w * r
            }
            portfolioReturns.append(dayReturn)
        }

        let mean = portfolioReturns.reduce(0, +) / Double(portfolioReturns.count)
        let variance = portfolioReturns.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(portfolioReturns.count)
        return sqrt(variance) * sqrt(252.0) * 100  // annualized, as percentage
    }

    // MARK: - Herfindahl Concentration Index

    static func herfindahlIndex(holdings: [Holding], quotes: [Quote]) -> Double {
        var totalValue = 0.0
        var values: [Double] = []

        for holding in holdings {
            let price = quotes.first(where: { $0.symbol == holding.symbol })?.last ?? 0
            let value = price * (holding.shares ?? 0)
            values.append(value)
            totalValue += value
        }

        guard totalValue > 0 else { return 0 }
        let weights = values.map { $0 / totalValue }
        return weights.reduce(0) { $0 + $1 * $1 }
    }

    // MARK: - Hypothetical Impact

    static func hypotheticalImpact(
        bars: [String: [DailyBar]],
        currentWeights: [String: Double],
        newSymbol: String,
        newWeight: Double,
        newBars: [DailyBar]
    ) -> (newVolatility: Double, deltaVolatility: Double) {
        let currentVol = portfolioVolatility(bars: bars, weights: currentWeights)

        // Adjust weights: scale existing down to make room for new
        let scaleFactor = 1.0 - newWeight
        var newWeights: [String: Double] = [:]
        for (sym, w) in currentWeights {
            newWeights[sym] = w * scaleFactor
        }
        newWeights[newSymbol] = newWeight

        var newBarsMap = bars
        newBarsMap[newSymbol] = newBars

        let newVol = portfolioVolatility(bars: newBarsMap, weights: newWeights)
        return (newVolatility: newVol, deltaVolatility: newVol - currentVol)
    }

    // MARK: - Helpers

    private static func dailyReturns(_ bars: [DailyBar]) -> [Double] {
        let sorted = bars.sorted { $0.date < $1.date }
        guard sorted.count > 1 else { return [] }
        var rets: [Double] = []
        for i in 1..<sorted.count {
            guard sorted[i-1].close > 0 else { continue }
            rets.append((sorted[i].close - sorted[i-1].close) / sorted[i-1].close)
        }
        return rets
    }

    private static func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        let n = min(x.count, y.count)
        guard n > 1 else { return 0 }

        let xSlice = Array(x.suffix(n))
        let ySlice = Array(y.suffix(n))

        let meanX = xSlice.reduce(0, +) / Double(n)
        let meanY = ySlice.reduce(0, +) / Double(n)

        var num = 0.0
        var denomX = 0.0
        var denomY = 0.0

        for i in 0..<n {
            let dx = xSlice[i] - meanX
            let dy = ySlice[i] - meanY
            num += dx * dy
            denomX += dx * dx
            denomY += dy * dy
        }

        let denom = sqrt(denomX * denomY)
        guard denom > 0 else { return 0 }
        return num / denom
    }
}
