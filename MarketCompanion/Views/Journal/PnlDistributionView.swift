// PnlDistributionView.swift
// MarketCompanion
//
// Histogram showing the distribution of trade P&L values.

import SwiftUI

struct PnlDistributionView: View {
    let trades: [Trade]

    private var bins: [(range: String, count: Int, isPositive: Bool)] {
        let closed = trades.filter { $0.isClosed }
        let pnls = closed.compactMap(\.pnl)
        guard !pnls.isEmpty else { return [] }

        let minPnl = pnls.min() ?? 0
        let maxPnl = pnls.max() ?? 0
        let spread = maxPnl - minPnl
        guard spread > 0 else { return [("$0", pnls.count, true)] }

        let binCount = min(10, max(3, pnls.count / 2))
        let binWidth = spread / Double(binCount)

        var result: [(range: String, count: Int, isPositive: Bool)] = []
        for i in 0..<binCount {
            let low = minPnl + Double(i) * binWidth
            let high = low + binWidth
            let count = pnls.filter { $0 >= low && (i == binCount - 1 ? $0 <= high : $0 < high) }.count
            let midpoint = (low + high) / 2
            let label = FormatHelper.pnl(midpoint)
            result.append((range: label, count: count, isPositive: midpoint >= 0))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("P&L Distribution")
                .font(AppFont.subheadline())
                .foregroundStyle(Color.textPrimary)

            if bins.isEmpty {
                Text("Not enough data for distribution chart.")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
                    .frame(height: 100)
            } else {
                Canvas { context, size in
                    drawHistogram(context: context, size: size)
                }
                .frame(height: 100)
            }
        }
    }

    private func drawHistogram(context: GraphicsContext, size: CGSize) {
        guard !bins.isEmpty else { return }

        let maxCount = bins.map(\.count).max() ?? 1
        guard maxCount > 0 else { return }

        let barWidth = size.width / CGFloat(bins.count)
        let padding: CGFloat = 2

        for (i, bin) in bins.enumerated() {
            let x = CGFloat(i) * barWidth
            let heightFraction = CGFloat(bin.count) / CGFloat(maxCount)
            let barHeight = (size.height - 16) * heightFraction

            let color: Color = bin.isPositive ? .gainGreen.opacity(0.6) : .lossRed.opacity(0.6)

            let rect = CGRect(
                x: x + padding,
                y: size.height - 16 - barHeight,
                width: barWidth - padding * 2,
                height: barHeight
            )
            context.fill(Path(rect), with: .color(color))

            // Label
            let text = Text(bin.range)
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(Color.textTertiary)
            context.draw(
                context.resolve(text),
                at: CGPoint(x: x + barWidth / 2, y: size.height - 6)
            )
        }
    }
}
