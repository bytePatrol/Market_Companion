// VolumeProfileRenderer.swift
// MarketCompanion
//
// Pure function: computes volume profile bins from visible candles.

import Foundation

struct VolumeProfileBin {
    let priceLevel: Double
    let totalVolume: Double
    let buyVolume: Double
    let sellVolume: Double
}

struct VolumeProfileData {
    let bins: [VolumeProfileBin]
    let pointOfControl: Double
    let valueAreaHigh: Double
    let valueAreaLow: Double
    let maxBinVolume: Double
}

enum VolumeProfileRenderer {

    static func compute(candles: [Candle], priceMin: Double, priceMax: Double, binCount: Int = 50) -> VolumeProfileData? {
        guard !candles.isEmpty, priceMax > priceMin, binCount > 0 else { return nil }

        let priceRange = priceMax - priceMin
        let binSize = priceRange / Double(binCount)
        guard binSize > 0 else { return nil }

        var binTotals = [(total: Double, buy: Double, sell: Double)](repeating: (0, 0, 0), count: binCount)

        for candle in candles {
            let candleRange = candle.high - candle.low
            guard candleRange > 0 else { continue }

            let isBullish = candle.close >= candle.open
            let vol = Double(candle.volume)

            // Distribute volume across bins that overlap with this candle
            for b in 0..<binCount {
                let binLow = priceMin + Double(b) * binSize
                let binHigh = binLow + binSize

                let overlapLow = max(candle.low, binLow)
                let overlapHigh = min(candle.high, binHigh)

                if overlapHigh > overlapLow {
                    let overlapFraction = (overlapHigh - overlapLow) / candleRange
                    let allocatedVolume = vol * overlapFraction

                    binTotals[b].total += allocatedVolume
                    if isBullish {
                        binTotals[b].buy += allocatedVolume
                    } else {
                        binTotals[b].sell += allocatedVolume
                    }
                }
            }
        }

        var bins: [VolumeProfileBin] = []
        var maxVolume: Double = 0
        var pocIndex = 0

        for (i, bt) in binTotals.enumerated() {
            let priceLevel = priceMin + (Double(i) + 0.5) * binSize
            bins.append(VolumeProfileBin(
                priceLevel: priceLevel,
                totalVolume: bt.total,
                buyVolume: bt.buy,
                sellVolume: bt.sell
            ))
            if bt.total > maxVolume {
                maxVolume = bt.total
                pocIndex = i
            }
        }

        let poc = bins[pocIndex].priceLevel

        // Value Area: 70% of total volume centered around POC
        let totalVolume = bins.reduce(0) { $0 + $1.totalVolume }
        let targetVolume = totalVolume * 0.7

        var vaHigh = pocIndex
        var vaLow = pocIndex
        var accumulatedVolume = bins[pocIndex].totalVolume

        while accumulatedVolume < targetVolume {
            let canGoUp = vaHigh + 1 < binCount
            let canGoDown = vaLow - 1 >= 0

            if !canGoUp && !canGoDown { break }

            let upVolume = canGoUp ? bins[vaHigh + 1].totalVolume : 0
            let downVolume = canGoDown ? bins[vaLow - 1].totalVolume : 0

            if upVolume >= downVolume && canGoUp {
                vaHigh += 1
                accumulatedVolume += bins[vaHigh].totalVolume
            } else if canGoDown {
                vaLow -= 1
                accumulatedVolume += bins[vaLow].totalVolume
            } else if canGoUp {
                vaHigh += 1
                accumulatedVolume += bins[vaHigh].totalVolume
            } else {
                break
            }
        }

        return VolumeProfileData(
            bins: bins,
            pointOfControl: poc,
            valueAreaHigh: priceMin + (Double(vaHigh) + 1) * binSize,
            valueAreaLow: priceMin + Double(vaLow) * binSize,
            maxBinVolume: maxVolume
        )
    }
}
