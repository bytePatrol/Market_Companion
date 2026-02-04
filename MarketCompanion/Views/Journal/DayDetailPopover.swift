// DayDetailPopover.swift
// MarketCompanion
//
// Shows all trades for a selected day with P&L and mini equity curve.

import SwiftUI

struct DayDetailPopover: View {
    let date: Date
    let trades: [Trade]

    var body: some View {
        CardView(padding: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Header
                HStack {
                    Text(dateFormatter.string(from: date))
                        .font(AppFont.headline())
                    Spacer()
                    if !trades.isEmpty {
                        Text(FormatHelper.pnl(totalPnl))
                            .font(AppFont.price())
                            .foregroundStyle(Color.forChange(totalPnl))
                    }
                }

                if trades.isEmpty {
                    Text("No trades on this day.")
                        .font(AppFont.body())
                        .foregroundStyle(Color.textTertiary)
                        .padding(.vertical, Spacing.xs)
                } else {
                    // Mini equity curve for the day
                    miniEquityCurve
                        .frame(height: 40)

                    // Trade list
                    ForEach(trades) { trade in
                        HStack(spacing: Spacing.sm) {
                            Text(trade.symbol)
                                .font(AppFont.symbol())
                                .frame(width: 50, alignment: .leading)

                            TagPill(
                                text: trade.side.rawValue.uppercased(),
                                color: trade.side == .long ? .gainGreen : .lossRed,
                                style: .filled
                            )

                            Text("\(Int(trade.qty)) @ \(FormatHelper.price(trade.entryPrice))")
                                .font(AppFont.monoSmall())
                                .foregroundStyle(Color.textSecondary)

                            Spacer()

                            if let pnl = trade.pnl {
                                Text(FormatHelper.pnl(pnl))
                                    .font(AppFont.mono())
                                    .foregroundStyle(Color.forChange(pnl))
                            }
                        }

                        if !trade.tagList.isEmpty {
                            HStack(spacing: Spacing.xxs) {
                                ForEach(trade.tagList, id: \.self) { tag in
                                    TagPill(text: tag, style: .subtle)
                                }
                            }
                            .padding(.leading, 62)
                        }
                    }

                    // Summary
                    SubtleDivider()

                    HStack(spacing: Spacing.lg) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trades")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textTertiary)
                            Text("\(trades.count)")
                                .font(AppFont.mono())
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Win Rate")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textTertiary)
                            Text(String(format: "%.0f%%", winRate))
                                .font(AppFont.mono())
                                .foregroundStyle(winRate >= 50 ? Color.gainGreen : Color.lossRed)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Net P&L")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textTertiary)
                            Text(FormatHelper.pnl(totalPnl))
                                .font(AppFont.mono())
                                .foregroundStyle(Color.forChange(totalPnl))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Computed

    private var totalPnl: Double {
        trades.compactMap(\.pnl).reduce(0, +)
    }

    private var winRate: Double {
        let wins = trades.filter { ($0.pnl ?? 0) > 0 }.count
        return trades.isEmpty ? 0 : Double(wins) / Double(trades.count) * 100
    }

    // MARK: - Mini Equity Curve

    private var miniEquityCurve: some View {
        Canvas { context, size in
            let sorted = trades.sorted { ($0.exitTime ?? $0.entryTime) < ($1.exitTime ?? $1.entryTime) }
            guard sorted.count > 1 else { return }

            var cumPnl: [Double] = [0]
            var running = 0.0
            for trade in sorted {
                running += trade.pnl ?? 0
                cumPnl.append(running)
            }

            let minVal = cumPnl.min() ?? 0
            let maxVal = cumPnl.max() ?? 1
            let range = maxVal - minVal
            guard range > 0 else { return }

            var path = Path()
            for (i, val) in cumPnl.enumerated() {
                let x = CGFloat(i) / CGFloat(cumPnl.count - 1) * size.width
                let y = size.height * CGFloat(1.0 - (val - minVal) / range)
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            let color: Color = (cumPnl.last ?? 0) >= 0 ? .gainGreen : .lossRed
            context.stroke(path, with: .color(color), lineWidth: 1.5)

            // Zero line
            if minVal < 0 && maxVal > 0 {
                let zeroY = size.height * CGFloat(1.0 - (0 - minVal) / range)
                var zeroPath = Path()
                zeroPath.move(to: CGPoint(x: 0, y: zeroY))
                zeroPath.addLine(to: CGPoint(x: size.width, y: zeroY))
                context.stroke(zeroPath, with: .color(.textTertiary.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .full
        return f
    }
}
