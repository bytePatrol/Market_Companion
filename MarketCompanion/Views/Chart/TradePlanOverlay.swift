// TradePlanOverlay.swift
// MarketCompanion
//
// Trade plan data model and Canvas renderer for chart overlay.

import SwiftUI

// MARK: - Trade Plan Model

struct TradePlan {
    var symbol: String
    var entryPrice: Double
    var stopPrice: Double
    var targetPrice: Double
    var side: TradeSide
    var shares: Double

    var riskPerShare: Double {
        abs(entryPrice - stopPrice)
    }

    var rewardPerShare: Double {
        abs(targetPrice - entryPrice)
    }

    var rewardToRisk: Double {
        guard riskPerShare > 0 else { return 0 }
        return rewardPerShare / riskPerShare
    }

    var totalRisk: Double {
        riskPerShare * shares
    }

    var totalReward: Double {
        rewardPerShare * shares
    }

    var isLong: Bool {
        side == .long
    }
}

// MARK: - Trade Plan Renderer

enum TradePlanRenderer {

    static func draw(
        plan: TradePlan,
        context: inout GraphicsContext,
        size: CGSize,
        priceRange: (min: Double, max: Double, range: Double),
        chartWidth: CGFloat
    ) {
        func priceToY(_ price: Double) -> CGFloat {
            let topPad: CGFloat = 4
            let bottomPad: CGFloat = 4
            let drawableHeight = size.height - topPad - bottomPad
            return topPad + drawableHeight * CGFloat(1.0 - (price - priceRange.min) / priceRange.range)
        }

        func drawLine(price: Double, color: Color, label: String) {
            let y = priceToY(price)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: chartWidth, y: y))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))

            let text = Text("\(label): \(String(format: "%.2f", price))")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(color)
            context.draw(context.resolve(text), at: CGPoint(x: 4, y: y - 10), anchor: .leading)
        }

        drawLine(price: plan.entryPrice, color: .cyan, label: "Entry")
        drawLine(price: plan.stopPrice, color: .red, label: "Stop")
        drawLine(price: plan.targetPrice, color: .green, label: "Target")

        // Fill zones
        let entryY = priceToY(plan.entryPrice)
        let stopY = priceToY(plan.stopPrice)
        let targetY = priceToY(plan.targetPrice)

        // Risk zone
        let riskRect = CGRect(x: 0, y: min(entryY, stopY), width: chartWidth, height: abs(stopY - entryY))
        context.fill(Path(riskRect), with: .color(.lossRed.opacity(0.05)))

        // Reward zone
        let rewardRect = CGRect(x: 0, y: min(entryY, targetY), width: chartWidth, height: abs(targetY - entryY))
        context.fill(Path(rewardRect), with: .color(.gainGreen.opacity(0.05)))

        // R:R badge
        let rrText = Text(String(format: "R:R %.1f", plan.rewardToRisk))
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white)
        context.draw(context.resolve(rrText), at: CGPoint(x: chartWidth - 65, y: min(entryY, targetY) + 12), anchor: .leading)
    }
}
