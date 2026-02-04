// MonthlyPnlGrid.swift
// MarketCompanion
//
// Calendar-style grid showing monthly P&L values.

import SwiftUI

struct MonthlyPnlGrid: View {
    let monthlyData: [(month: String, pnl: Double)]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Monthly P&L")
                .font(AppFont.subheadline())
                .foregroundStyle(Color.textPrimary)

            if monthlyData.isEmpty {
                Text("No monthly data yet.")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
            } else {
                LazyVGrid(columns: columns, spacing: Spacing.xxs) {
                    ForEach(monthlyData, id: \.month) { entry in
                        monthCell(entry)
                    }
                }
            }
        }
    }

    private func monthCell(_ entry: (month: String, pnl: Double)) -> some View {
        VStack(spacing: 2) {
            Text(formatMonthLabel(entry.month))
                .font(AppFont.caption())
                .foregroundStyle(Color.textTertiary)

            Text(FormatHelper.pnl(entry.pnl))
                .font(AppFont.monoSmall())
                .foregroundStyle(Color.forChange(entry.pnl))
        }
        .padding(Spacing.xxs)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                .fill(entry.pnl >= 0 ? Color.gainGreen.opacity(0.1) : Color.lossRed.opacity(0.1))
        }
    }

    private func formatMonthLabel(_ yyyyMM: String) -> String {
        let parts = yyyyMM.split(separator: "-")
        guard parts.count == 2 else { return yyyyMM }
        let monthNames = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let monthNum = Int(parts[1]) ?? 0
        let year = String(parts[0].suffix(2))
        if monthNum > 0, monthNum <= 12 {
            return "\(monthNames[monthNum]) '\(year)"
        }
        return yyyyMM
    }
}
