// PositionSizeCalculator.swift
// MarketCompanion
//
// Position sizing tool: calculates shares from risk parameters.

import SwiftUI

struct PositionSizeCalculator: View {
    @Environment(\.dismiss) private var dismiss

    @State private var accountSize = ""
    @State private var riskPercent = "1.0"
    @State private var entryPrice = ""
    @State private var stopLoss = ""
    @State private var target = ""

    var onConfirmQty: ((Double) -> Void)?

    private var riskAmount: Double? {
        guard let account = Double(accountSize),
              let pct = Double(riskPercent) else { return nil }
        return account * pct / 100.0
    }

    private var stopDistance: Double? {
        guard let entry = Double(entryPrice),
              let stop = Double(stopLoss) else { return nil }
        return abs(entry - stop)
    }

    private var shares: Double? {
        guard let risk = riskAmount,
              let dist = stopDistance, dist > 0 else { return nil }
        return floor(risk / dist)
    }

    private var positionValue: Double? {
        guard let qty = shares, let entry = Double(entryPrice) else { return nil }
        return qty * entry
    }

    private var positionPctOfAccount: Double? {
        guard let value = positionValue,
              let account = Double(accountSize), account > 0 else { return nil }
        return value / account * 100
    }

    private var riskRewardRatio: Double? {
        guard let entry = Double(entryPrice),
              let stop = Double(stopLoss),
              let tgt = Double(target) else { return nil }
        let risk = abs(entry - stop)
        let reward = abs(tgt - entry)
        guard risk > 0 else { return nil }
        return reward / risk
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text("Position Size Calculator")
                    .font(AppFont.title())
                Spacer()
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    inputField("Account Size ($)", text: $accountSize)
                    inputField("Risk %", text: $riskPercent)
                }

                HStack(spacing: Spacing.sm) {
                    inputField("Entry Price", text: $entryPrice)
                    inputField("Stop Loss", text: $stopLoss)
                }

                inputField("Target (optional)", text: $target)
            }

            Divider()

            // Computed outputs
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let risk = riskAmount {
                    outputRow("Risk Amount", value: FormatHelper.price(risk))
                }
                if let qty = shares {
                    outputRow("Shares", value: "\(Int(qty))", highlight: true)
                }
                if let pv = positionValue {
                    outputRow("Position Value", value: FormatHelper.price(pv))
                }
                if let pct = positionPctOfAccount {
                    outputRow("% of Account", value: String(format: "%.1f%%", pct))
                }
                if let rr = riskRewardRatio {
                    outputRow("Risk:Reward", value: String(format: "1:%.1f", rr),
                              color: rr >= 2 ? .gainGreen : rr >= 1 ? .warningAmber : .lossRed)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if let qty = shares, onConfirmQty != nil {
                    Button("Use \(Int(qty)) Shares") {
                        onConfirmQty?(qty)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(Spacing.xl)
        .frame(width: 400)
    }

    private func inputField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppFont.caption())
                .foregroundStyle(Color.textTertiary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func outputRow(_ label: String, value: String, highlight: Bool = false, color: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(AppFont.body())
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(highlight ? AppFont.price() : AppFont.mono())
                .foregroundStyle(color ?? (highlight ? Color.accentColor : Color.textPrimary))
        }
    }
}
