// EquityCurveView.swift
// MarketCompanion
//
// Canvas-based equity curve with drawdown overlay.

import SwiftUI

struct EquityCurveView: View {
    let curve: [(date: Date, cumPnl: Double)]
    let drawdowns: [(date: Date, drawdown: Double)]

    @State private var hoverIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Equity Curve")
                .font(AppFont.subheadline())
                .foregroundStyle(Color.textPrimary)

            if curve.count < 2 {
                Text("Not enough closed trades to plot equity curve.")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
                    .frame(height: 160)
            } else {
                ZStack(alignment: .topLeading) {
                    Canvas { context, size in
                        drawEquityCurve(context: context, size: size)
                    }
                    .frame(height: 160)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let fraction = location.x / 300 // approximate
                            hoverIndex = min(curve.count - 1, max(0, Int(fraction * CGFloat(curve.count))))
                        case .ended:
                            hoverIndex = nil
                        }
                    }

                    if let idx = hoverIndex, idx < curve.count {
                        let point = curve[idx]
                        VStack(alignment: .leading, spacing: 1) {
                            Text(FormatHelper.shortDate(point.date))
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textTertiary)
                            Text(FormatHelper.pnl(point.cumPnl))
                                .font(AppFont.mono())
                                .foregroundStyle(Color.forChange(point.cumPnl))
                            if idx < drawdowns.count {
                                Text("DD: \(FormatHelper.pnl(-drawdowns[idx].drawdown))")
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.lossRed)
                            }
                        }
                        .padding(Spacing.xxs)
                        .background(Color.surfaceSecondary.opacity(0.9))
                        .cornerRadius(CornerRadius.sm)
                    }
                }
            }
        }
    }

    private func drawEquityCurve(context: GraphicsContext, size: CGSize) {
        guard curve.count >= 2 else { return }

        let values = curve.map(\.cumPnl)
        let minVal = min(0, values.min() ?? 0)
        let maxVal = max(0, values.max() ?? 1)
        let range = maxVal - minVal
        guard range > 0 else { return }

        let padding: CGFloat = 4

        // Drawdown shading
        if !drawdowns.isEmpty {
            var ddPath = Path()
            let zeroY = padding + (size.height - padding * 2) * CGFloat(1.0 - (0 - minVal) / range)

            for (i, dd) in drawdowns.enumerated() {
                let x = padding + (size.width - padding * 2) * CGFloat(i) / CGFloat(curve.count - 1)
                let ddVal = curve[i].cumPnl - dd.drawdown
                _ = padding + (size.height - padding * 2) * CGFloat(1.0 - (ddVal - minVal) / range)
                let curveY = padding + (size.height - padding * 2) * CGFloat(1.0 - (curve[i].cumPnl - minVal) / range)

                if i == 0 {
                    ddPath.move(to: CGPoint(x: x, y: curveY))
                } else {
                    ddPath.addLine(to: CGPoint(x: x, y: curveY))
                }
            }

            // Close below to zero line for shading region
            for i in stride(from: drawdowns.count - 1, through: 0, by: -1) {
                let x = padding + (size.width - padding * 2) * CGFloat(i) / CGFloat(curve.count - 1)
                let peakPnl = curve[i].cumPnl + drawdowns[i].drawdown
                _ = padding + (size.height - padding * 2) * CGFloat(1.0 - (peakPnl - minVal) / range)
                ddPath.addLine(to: CGPoint(x: x, y: zeroY))
            }
        }

        // Zero line
        let zeroY = padding + (size.height - padding * 2) * CGFloat(1.0 - (0 - minVal) / range)
        var zeroLine = Path()
        zeroLine.move(to: CGPoint(x: 0, y: zeroY))
        zeroLine.addLine(to: CGPoint(x: size.width, y: zeroY))
        context.stroke(zeroLine, with: .color(.textTertiary.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))

        // Equity line
        var path = Path()
        for (i, point) in curve.enumerated() {
            let x = padding + (size.width - padding * 2) * CGFloat(i) / CGFloat(curve.count - 1)
            let y = padding + (size.height - padding * 2) * CGFloat(1.0 - (point.cumPnl - minVal) / range)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Fill area under curve
        var fillPath = path
        let lastX = padding + (size.width - padding * 2)
        fillPath.addLine(to: CGPoint(x: lastX, y: zeroY))
        fillPath.addLine(to: CGPoint(x: padding, y: zeroY))
        fillPath.closeSubpath()

        let finalPnl = curve.last?.cumPnl ?? 0
        let fillColor: Color = finalPnl >= 0 ? .gainGreen.opacity(0.1) : .lossRed.opacity(0.1)
        context.fill(fillPath, with: .color(fillColor))

        let lineColor: Color = finalPnl >= 0 ? .gainGreen : .lossRed
        context.stroke(path, with: .color(lineColor), lineWidth: 2)
    }
}
