// TreemapLayout.swift
// MarketCompanion
//
// Squarified treemap algorithm. Groups items by sector, then lays out
// individual tiles within each sector cluster keeping aspect ratios close to 1.

import Foundation

// MARK: - Data Types

struct TreemapItem {
    let symbol: String
    let sizeValue: Double
    let changePct: Double
    let sector: String
}

struct TreemapRect {
    let symbol: String
    let frame: CGRect
    let changePct: Double
    let sector: String
}

// MARK: - Treemap Layout Engine

enum TreemapLayout {

    /// Main entry: groups by sector, allocates sector areas proportionally,
    /// then squarifies tiles within each sector.
    static func layout(items: [TreemapItem], in rect: CGRect) -> [TreemapRect] {
        guard !items.isEmpty, rect.width > 0, rect.height > 0 else { return [] }

        // Group by sector
        let grouped = Dictionary(grouping: items, by: \.sector)
        let sectorTotals = grouped.mapValues { group in
            group.reduce(0) { $0 + max($1.sizeValue, 0.001) }
        }
        let grandTotal = sectorTotals.values.reduce(0, +)
        guard grandTotal > 0 else { return [] }

        // Sort sectors by total size descending for better layout
        let sortedSectors = sectorTotals.sorted { $0.value > $1.value }

        // Allocate sector-level rectangles using squarify
        let sectorSizes = sortedSectors.map { $0.value / grandTotal * Double(rect.width * rect.height) }
        let sectorRects = squarify(areas: sectorSizes, in: rect)

        var result: [TreemapRect] = []

        for (i, (sectorName, _)) in sortedSectors.enumerated() {
            guard i < sectorRects.count else { break }
            let sectorRect = sectorRects[i]
            let sectorItems = grouped[sectorName] ?? []

            // Sort items by size descending within sector
            let sorted = sectorItems.sorted { max($0.sizeValue, 0.001) > max($1.sizeValue, 0.001) }
            let sectorTotal = sorted.reduce(0.0) { $0 + max($1.sizeValue, 0.001) }
            guard sectorTotal > 0 else { continue }

            let itemAreas = sorted.map { max($0.sizeValue, 0.001) / sectorTotal * Double(sectorRect.width * sectorRect.height) }
            let itemRects = squarify(areas: itemAreas, in: sectorRect)

            for (j, item) in sorted.enumerated() {
                guard j < itemRects.count else { break }
                result.append(TreemapRect(
                    symbol: item.symbol,
                    frame: itemRects[j],
                    changePct: item.changePct,
                    sector: item.sector
                ))
            }
        }

        return result
    }

    // MARK: - Squarified Algorithm

    /// Lays out areas into a rectangle using the squarified treemap algorithm.
    private static func squarify(areas: [Double], in rect: CGRect) -> [CGRect] {
        guard !areas.isEmpty else { return [] }

        var rects: [CGRect] = Array(repeating: .zero, count: areas.count)
        var remaining = rect
        var i = 0

        while i < areas.count {
            let isVertical = remaining.width >= remaining.height
            let side = isVertical ? Double(remaining.height) : Double(remaining.width)
            guard side > 0 else { break }

            // Find optimal row
            var row: [Int] = [i]
            var rowArea = areas[i]
            var bestWorst = worstAspect(row: [areas[i]], side: side, totalArea: rowArea)

            var j = i + 1
            while j < areas.count {
                let newRowArea = rowArea + areas[j]
                var newRow = row.map { areas[$0] }
                newRow.append(areas[j])
                let newWorst = worstAspect(row: newRow, side: side, totalArea: newRowArea)

                if newWorst <= bestWorst {
                    row.append(j)
                    rowArea = newRowArea
                    bestWorst = newWorst
                    j += 1
                } else {
                    break
                }
            }

            // Lay out the row
            let rowWidth = rowArea / Double(side)

            var offset: CGFloat = 0
            for idx in row {
                let itemHeight = CGFloat(areas[idx] / rowWidth)

                if isVertical {
                    rects[idx] = CGRect(
                        x: remaining.minX,
                        y: remaining.minY + offset,
                        width: CGFloat(rowWidth),
                        height: itemHeight
                    )
                } else {
                    rects[idx] = CGRect(
                        x: remaining.minX + offset,
                        y: remaining.minY,
                        width: itemHeight,
                        height: CGFloat(rowWidth)
                    )
                }
                offset += itemHeight
            }

            // Shrink remaining rect
            if isVertical {
                remaining = CGRect(
                    x: remaining.minX + CGFloat(rowWidth),
                    y: remaining.minY,
                    width: remaining.width - CGFloat(rowWidth),
                    height: remaining.height
                )
            } else {
                remaining = CGRect(
                    x: remaining.minX,
                    y: remaining.minY + CGFloat(rowWidth),
                    width: remaining.width,
                    height: remaining.height - CGFloat(rowWidth)
                )
            }

            i = j.isMultiple(of: 1) ? j : i + row.count
            if j <= i { i = j }
        }

        return rects
    }

    /// Worst aspect ratio in a row — lower is better (closer to 1).
    private static func worstAspect(row: [Double], side: Double, totalArea: Double) -> Double {
        guard side > 0, totalArea > 0 else { return .infinity }
        let rowWidth = totalArea / side

        var worst: Double = 0
        for area in row {
            let itemLength = area / rowWidth
            let aspect = max(rowWidth / itemLength, itemLength / rowWidth)
            worst = max(worst, aspect)
        }
        return worst
    }
}
