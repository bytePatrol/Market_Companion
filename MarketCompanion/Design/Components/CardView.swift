// CardView.swift
// MarketCompanion

import SwiftUI

struct CardView<Content: View>: View {
    let content: Content
    var padding: CGFloat
    var cornerRadius: CGFloat

    init(
        padding: CGFloat = Spacing.md,
        cornerRadius: CGFloat = CornerRadius.md,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.surfaceSecondary)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.borderSubtle.opacity(0.5), lineWidth: 0.5)
                }
            }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var icon: String? = nil
    var iconColor: Color = .accentColor
    var trend: Double? = nil

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }
                    Text(title)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)
                }

                Text(value)
                    .font(AppFont.bigNumber())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let subtitle {
                    HStack(spacing: Spacing.xxs) {
                        if let trend {
                            Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.forChange(trend))
                        }
                        Text(subtitle)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Symbol Row Card

struct SymbolRowCard: View {
    let quote: Quote
    var showVolume: Bool = false
    var sparklineData: [Double] = []

    var body: some View {
        CardView(padding: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                // Symbol + sector
                VStack(alignment: .leading, spacing: 2) {
                    Text(quote.symbol)
                        .font(AppFont.symbol())
                        .foregroundStyle(Color.textPrimary)
                    Text(MarketSector.classify(quote.symbol).rawValue)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(width: 70, alignment: .leading)

                // Sparkline
                if !sparklineData.isEmpty {
                    SparklineView(
                        data: sparklineData,
                        lineColor: Color.forChange(quote.changePct)
                    )
                    .frame(width: 60, height: 24)
                }

                Spacer()

                // Volume indicator
                if showVolume {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(FormatHelper.volume(quote.volume))
                            .font(AppFont.monoSmall())
                            .foregroundStyle(Color.textSecondary)
                        if quote.volumeRatio > 1.5 {
                            Text("\(String(format: "%.1f", quote.volumeRatio))x")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.warningAmber)
                        }
                    }
                }

                // Price + change
                VStack(alignment: .trailing, spacing: 2) {
                    Text(FormatHelper.price(quote.last))
                        .font(AppFont.price())
                        .foregroundStyle(Color.textPrimary)
                    Text(FormatHelper.percent(quote.changePct))
                        .font(AppFont.mono())
                        .foregroundStyle(Color.forChange(quote.changePct))
                }
                .frame(width: 90, alignment: .trailing)
            }
        }
    }
}

#Preview("Cards") {
    VStack(spacing: Spacing.md) {
        MetricCard(
            title: "Portfolio Value",
            value: "$24,580",
            subtitle: "+2.3% today",
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .gainGreen,
            trend: 2.3
        )

        SymbolRowCard(
            quote: Quote(
                symbol: "AAPL",
                last: 185.42,
                changePct: 1.23,
                volume: 54_000_000,
                avgVolume: 45_000_000,
                dayHigh: 186.10,
                dayLow: 183.50
            ),
            showVolume: true,
            sparklineData: [180, 181, 183, 182, 184, 185, 185.42]
        )
    }
    .padding()
    .frame(width: 400)
}
