// TradePlanPanel.swift
// MarketCompanion
//
// Popover panel for configuring entry/stop/target trade plan on chart.

import SwiftUI

struct TradePlanPanel: View {
    @ObservedObject var viewModel: ChartViewModel
    @State private var entryText = ""
    @State private var stopText = ""
    @State private var targetText = ""
    @State private var sharesText = "100"
    @State private var side: TradeSide = .long

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Trade Plan")
                    .font(AppFont.subheadline())
                Spacer()
                if viewModel.tradePlan != nil {
                    Button("Clear") {
                        viewModel.tradePlan = nil
                    }
                    .font(AppFont.caption())
                    .foregroundStyle(Color.lossRed)
                    .help("Remove the trade plan from the chart")
                }
            }

            Picker("Side", selection: $side) {
                Text("Long").tag(TradeSide.long)
                Text("Short").tag(TradeSide.short)
            }
            .pickerStyle(.segmented)
            .help("Long profits when price rises. Short profits when price falls.")

            VStack(spacing: Spacing.xs) {
                planField("Entry", text: $entryText, color: .cyan)
                    .help("Your planned entry price — auto-populated from current price")
                planField("Stop", text: $stopText, color: .red)
                    .help("Price level where you'll exit to limit losses")
                planField("Target", text: $targetText, color: .green)
                    .help("Price level where you'll take profits")
                planField("Shares", text: $sharesText, color: .textSecondary)
                    .help("Number of shares to trade")
            }

            if let entry = Double(entryText),
               let stop = Double(stopText),
               let target = Double(targetText) {
                let risk = abs(entry - stop)
                let reward = abs(target - entry)
                let rr = risk > 0 ? reward / risk : 0

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Risk: \(FormatHelper.price(risk))/sh")
                            .font(AppFont.monoSmall())
                            .foregroundStyle(Color.lossRed)
                        Text("Reward: \(FormatHelper.price(reward))/sh")
                            .font(AppFont.monoSmall())
                            .foregroundStyle(Color.gainGreen)
                    }
                    Spacer()
                    Text(String(format: "%.1f R:R", rr))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(rr >= 2 ? Color.gainGreen : Color.warningAmber)
                }
                .padding(.vertical, Spacing.xxs)
            }

            HStack(spacing: Spacing.sm) {
                Button("Apply to Chart") {
                    applyPlan()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!isValid)
                .help("Draw entry, stop, and target lines on the chart")

                Button("Log Trade") {
                    logTrade()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!isValid)
                .help("Record this trade in your journal at the planned entry price")
            }
        }
        .padding(Spacing.md)
        .onAppear {
            // Auto-populate entry from current price
            if let quote = viewModel.latestQuote, entryText.isEmpty {
                entryText = String(format: "%.2f", quote.last)
            }
            // Populate from existing plan
            if let plan = viewModel.tradePlan {
                entryText = String(format: "%.2f", plan.entryPrice)
                stopText = String(format: "%.2f", plan.stopPrice)
                targetText = String(format: "%.2f", plan.targetPrice)
                sharesText = String(format: "%.0f", plan.shares)
                side = plan.side
            }
        }
    }

    private var isValid: Bool {
        Double(entryText) != nil && Double(stopText) != nil && Double(targetText) != nil
    }

    private func planField(_ label: String, text: Binding<String>, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(AppFont.caption())
                .frame(width: 50, alignment: .leading)
            TextField("0.00", text: text)
                .textFieldStyle(.roundedBorder)
                .font(AppFont.monoSmall())
        }
    }

    private func applyPlan() {
        guard let entry = Double(entryText),
              let stop = Double(stopText),
              let target = Double(targetText),
              let shares = Double(sharesText) else { return }

        viewModel.tradePlan = TradePlan(
            symbol: viewModel.symbol,
            entryPrice: entry,
            stopPrice: stop,
            targetPrice: target,
            side: side,
            shares: shares
        )
    }

    private func logTrade() {
        guard let entry = Double(entryText),
              let shares = Double(sharesText) else { return }

        viewModel.appState?.logTrade(
            symbol: viewModel.symbol,
            side: side,
            qty: shares,
            entryPrice: entry,
            notes: "Plan: stop=\(stopText) target=\(targetText)"
        )

        viewModel.showTradePlanPanel = false
    }
}
