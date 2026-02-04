// JournalCalendarView.swift
// MarketCompanion
//
// Calendar grid showing past 3 months with day cells colored by P&L.

import SwiftUI

struct JournalCalendarView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDate: Date?

    private let calendar = Calendar.current
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var closedTrades: [Trade] {
        appState.trades.filter { $0.isClosed }
    }

    private var tradesByDay: [String: [Trade]] {
        Dictionary(grouping: closedTrades) { trade in
            dayKey(for: trade.exitTime ?? trade.entryTime)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            ForEach(monthsToShow, id: \.self) { monthDate in
                monthSection(for: monthDate)
            }

            if let selectedDate {
                DayDetailPopover(
                    date: selectedDate,
                    trades: tradesByDay[dayKey(for: selectedDate)] ?? []
                )
                .transition(.opacity)
            }
        }
    }

    private var monthsToShow: [Date] {
        let now = Date()
        return (0..<3).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: now)
        }.reversed()
    }

    // MARK: - Month Section

    private func monthSection(for monthDate: Date) -> some View {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
        let range = calendar.range(of: .day, in: .month, for: monthStart)!
        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1
        let monthName = monthFormatter.string(from: monthStart)

        let monthTrades = closedTrades.filter {
            let exitDate = $0.exitTime ?? $0.entryTime
            return calendar.isDate(exitDate, equalTo: monthStart, toGranularity: .month)
        }
        let monthPnl = monthTrades.compactMap(\.pnl).reduce(0, +)
        let monthWins = monthTrades.filter { ($0.pnl ?? 0) > 0 }.count
        let winRate = monthTrades.isEmpty ? 0 : Double(monthWins) / Double(monthTrades.count) * 100

        return VStack(alignment: .leading, spacing: Spacing.xs) {
            // Month header
            HStack {
                Text(monthName)
                    .font(AppFont.headline())
                Spacer()
                if !monthTrades.isEmpty {
                    HStack(spacing: Spacing.sm) {
                        Text(FormatHelper.pnl(monthPnl))
                            .font(AppFont.mono())
                            .foregroundStyle(Color.forChange(monthPnl))
                        Text("\(monthTrades.count) trades")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                        Text(String(format: "%.0f%% WR", winRate))
                            .font(AppFont.caption())
                            .foregroundStyle(winRate >= 50 ? Color.gainGreen : Color.lossRed)
                    }
                }
            }

            // Day name headers
            HStack(spacing: 2) {
                ForEach(dayNames, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells grid
            let totalCells = firstWeekday + range.count
            let rows = (totalCells + 6) / 7

            VStack(spacing: 2) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { col in
                            let cellIndex = row * 7 + col
                            let dayNumber = cellIndex - firstWeekday + 1

                            if dayNumber >= 1 && dayNumber <= range.count {
                                let cellDate = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart)!
                                let key = dayKey(for: cellDate)
                                let dayTrades = tradesByDay[key] ?? []
                                let dayPnl = dayTrades.compactMap(\.pnl).reduce(0, +)

                                dayCell(day: dayNumber, pnl: dayPnl, hasTrades: !dayTrades.isEmpty, date: cellDate)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                            }
                        }
                    }
                }
            }
        }
        .padding(Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                .fill(Color.surfaceSecondary.opacity(0.3))
        }
    }

    // MARK: - Day Cell

    private func dayCell(day: Int, pnl: Double, hasTrades: Bool, date: Date) -> some View {
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)

        let bgColor: Color = {
            if !hasTrades { return Color.surfaceSecondary.opacity(0.3) }
            if pnl > 0 { return Color.gainGreen.opacity(min(0.15 + abs(pnl) / 500 * 0.4, 0.6)) }
            if pnl < 0 { return Color.lossRed.opacity(min(0.15 + abs(pnl) / 500 * 0.4, 0.6)) }
            return Color.textTertiary.opacity(0.15)
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedDate = nil
                } else {
                    selectedDate = date
                }
            }
        } label: {
            VStack(spacing: 1) {
                Text("\(day)")
                    .font(.system(size: 10, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.accentColor : Color.textPrimary)

                if hasTrades {
                    Text(shortPnl(pnl))
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.forChange(pnl))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(bgColor)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func dayKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year!)-\(comps.month!)-\(comps.day!)"
    }

    private func shortPnl(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        if abs(value) >= 1000 {
            return "\(sign)\(String(format: "%.0fK", value / 1000))"
        }
        return "\(sign)\(String(format: "%.0f", value))"
    }

    private var monthFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }
}
