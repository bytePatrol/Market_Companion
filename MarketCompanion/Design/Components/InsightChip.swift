// InsightChip.swift
// MarketCompanion

import SwiftUI

struct InsightChip: View {
    let icon: String
    let text: String
    let color: Color
    var action: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: Spacing.xxs) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(text)
                    .font(AppFont.caption())
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs + 1)
            .foregroundStyle(color)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                        .fill(color.opacity(isHovered ? 0.18 : 0.1))
                    RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                        .strokeBorder(color.opacity(0.3), lineWidth: 0.5)
                }
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Dashboard Insights

struct DashboardInsightsRow: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        let insights = computeInsights()
        if !insights.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                        InsightChip(
                            icon: insight.icon,
                            text: insight.text,
                            color: insight.color,
                            action: insight.action
                        )
                    }
                }
            }
        }
    }

    private struct Insight {
        let icon: String
        let text: String
        let color: Color
        let action: (() -> Void)?
    }

    private func computeInsights() -> [Insight] {
        var insights: [Insight] = []

        let holdingSymbols = Set(appState.holdings.map(\.symbol))
        let holdingQuotes = appState.quotes.filter { holdingSymbols.contains($0.symbol) }

        // Holdings performance
        let greenCount = holdingQuotes.filter { $0.changePct > 0 }.count
        if holdingQuotes.count > 0 {
            let ratio = Double(greenCount) / Double(holdingQuotes.count)
            if ratio > 0.7 {
                insights.append(Insight(
                    icon: "arrow.up.right",
                    text: "\(greenCount)/\(holdingQuotes.count) holdings green",
                    color: .gainGreen,
                    action: { [weak appState] in appState?.selectedPage = .watchlist }
                ))
            } else if ratio < 0.3 {
                insights.append(Insight(
                    icon: "arrow.down.right",
                    text: "\(holdingQuotes.count - greenCount)/\(holdingQuotes.count) holdings red",
                    color: .lossRed,
                    action: { [weak appState] in appState?.selectedPage = .watchlist }
                ))
            }
        }

        // Volume spikes
        let volumeSpikes = appState.quotes.filter { $0.volumeRatio > 2.0 }
            .sorted { $0.volumeRatio > $1.volumeRatio }
        if let top = volumeSpikes.first {
            insights.append(Insight(
                icon: "bolt.fill",
                text: "Volume spike: \(top.symbol) at \(String(format: "%.1f", top.volumeRatio))x avg",
                color: .warningAmber,
                action: { [weak appState] in appState?.selectedPage = .heatmap }
            ))
        }

        // Sector rotation insight
        if let overview = appState.marketOverview {
            let sorted = overview.sectorPerformance.sorted { $0.changePct > $1.changePct }
            if sorted.count >= 2 {
                let leader = sorted.first!
                let laggard = sorted.last!
                if leader.changePct - laggard.changePct > 1.5 {
                    insights.append(Insight(
                        icon: "arrow.triangle.swap",
                        text: "Rotation: \(laggard.sector)\u{2192}\(leader.sector)",
                        color: .infoBlue,
                        action: { [weak appState] in appState?.selectedPage = .heatmap }
                    ))
                }
            }

            // VIX elevated
            if overview.vixProxy > 20 {
                insights.append(Insight(
                    icon: "exclamationmark.triangle",
                    text: "VIX elevated: \(String(format: "%.1f", overview.vixProxy))",
                    color: .lossRed,
                    action: { [weak appState] in appState?.selectedPage = .alerts }
                ))
            }
        }

        // Big movers
        let bigMovers = appState.quotes.filter { abs($0.changePct) > 3.0 }
        if bigMovers.count > 0 {
            insights.append(Insight(
                icon: "chart.line.uptrend.xyaxis",
                text: "\(bigMovers.count) symbol\(bigMovers.count == 1 ? "" : "s") moving 3%+",
                color: .warningAmber,
                action: { [weak appState] in appState?.selectedPage = .heatmap }
            ))
        }

        return insights
    }
}

#Preview("Insight Chips") {
    VStack(spacing: Spacing.md) {
        HStack(spacing: Spacing.xs) {
            InsightChip(icon: "arrow.up.right", text: "7/10 holdings green", color: .gainGreen)
            InsightChip(icon: "bolt.fill", text: "Volume spike: NVDA at 2.1x", color: .warningAmber)
            InsightChip(icon: "arrow.triangle.swap", text: "Rotation: Energy\u{2192}Tech", color: .infoBlue)
        }
    }
    .padding()
}
