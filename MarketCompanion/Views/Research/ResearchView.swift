// ResearchView.swift
// MarketCompanion
//
// News feed and earnings calendar for tracked symbols.

import SwiftUI

struct ResearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var filterSymbol: String = ""
    @State private var filterDays: Int = 7

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .top) {
                    PageHeader(title: "Research", subtitle: "News & earnings calendar")
                    Spacer()
                    Button {
                        Task { await appState.refreshData() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(AppFont.subheadline())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(appState.isLoading)
                    .help("Fetch the latest news and calendar data")
                }

                Picker("View", selection: $selectedTab) {
                    Text("News").tag(0)
                    Text("Calendar").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .help("Switch between the news feed and earnings calendar")

                if selectedTab == 0 {
                    newsTab
                } else {
                    calendarTab
                }
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - News Tab

    private var newsTab: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Filter bar
            HStack(spacing: Spacing.sm) {
                TextField("Filter by symbol", text: $filterSymbol)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .help("Show only news related to a specific ticker")

                Picker("Days", selection: $filterDays) {
                    Text("1 day").tag(1)
                    Text("3 days").tag(3)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }
                .frame(width: 100)
                .help("Show news from the last 1, 3, 7, or 30 days")

                Spacer()
            }

            let news = filteredNews
            if news.isEmpty {
                EmptyStateView(
                    icon: "newspaper",
                    title: "No News",
                    message: "News for your holdings and watchlist will appear here once fetched.",
                    actionTitle: "Refresh"
                ) {
                    Task { await appState.refreshData() }
                }
                .frame(height: 300)
            } else {
                let grouped = Dictionary(grouping: news) { item in
                    Calendar.current.startOfDay(for: item.publishedAt)
                }.sorted { $0.key > $1.key }

                ForEach(grouped, id: \.key) { date, items in
                    SectionHeader(title: FormatHelper.shortDate(date), icon: "calendar")

                    ForEach(items, id: \.id) { item in
                        newsCard(item)
                    }
                }
            }
        }
    }

    private var filteredNews: [NewsItem] {
        var items = appState.newsItems
        let sym = filterSymbol.trimmingCharacters(in: .whitespaces).uppercased()
        if !sym.isEmpty {
            items = items.filter { $0.relatedSymbols.contains(sym) }
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -filterDays, to: Date())!
        items = items.filter { $0.publishedAt >= cutoff }
        return items
    }

    private func newsCard(_ item: NewsItem) -> some View {
        CardView(padding: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    if let url = URL(string: item.url) {
                        Link(destination: url) {
                            Text(item.headline)
                                .font(AppFont.subheadline())
                                .foregroundStyle(Color.accentColor)
                                .lineLimit(2)
                        }
                    } else {
                        Text(item.headline)
                            .font(AppFont.subheadline())
                            .lineLimit(2)
                    }
                    Spacer()
                }

                HStack(spacing: Spacing.xs) {
                    TagPill(text: item.source, style: .subtle)

                    if let sentiment = item.sentiment, !sentiment.isEmpty {
                        TagPill(
                            text: sentiment.capitalized,
                            color: sentimentColor(sentiment),
                            style: .filled
                        )
                    }

                    Spacer()

                    Text(FormatHelper.relativeDate(item.publishedAt))
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textTertiary)
                }

                if !item.relatedSymbols.isEmpty {
                    HStack(spacing: Spacing.xxs) {
                        ForEach(item.relatedSymbols.prefix(5), id: \.self) { sym in
                            Button {
                                appState.selectedChartSymbol = sym
                                appState.selectedPage = .chart
                            } label: {
                                Text(sym)
                                    .font(AppFont.caption())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !item.summary.isEmpty {
                    Text(item.summary)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(3)
                }
            }
        }
    }

    private func sentimentColor(_ sentiment: String) -> Color {
        switch sentiment.lowercased() {
        case "positive", "bullish": return .gainGreen
        case "negative", "bearish": return .lossRed
        default: return .textTertiary
        }
    }

    // MARK: - Calendar Tab

    private var calendarTab: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Filter
            HStack(spacing: Spacing.sm) {
                Picker("Show", selection: $calendarFilter) {
                    Text("All").tag(CalendarFilter.all)
                    Text("Holdings Only").tag(CalendarFilter.holdings)
                    Text("Watchlist Only").tag(CalendarFilter.watchlist)
                }
                .frame(width: 180)
                .help("Filter calendar events by holdings, watchlist, or show all")
                Spacer()
            }

            let events = filteredCalendarEvents
            if events.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "No Upcoming Events",
                    message: "Earnings and economic events for the next 30 days will appear here.",
                    actionTitle: "Refresh"
                ) {
                    Task { await appState.refreshData() }
                }
                .frame(height: 300)
            } else {
                // Group by week
                let grouped = Dictionary(grouping: events) { event in
                    Calendar.current.dateInterval(of: .weekOfYear, for: event.date)?.start ?? event.date
                }.sorted { $0.key < $1.key }

                ForEach(grouped, id: \.key) { weekStart, weekEvents in
                    let isThisWeek = Calendar.current.isDate(weekStart, equalTo: Date(), toGranularity: .weekOfYear)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text(weekLabel(weekStart))
                                .font(AppFont.subheadline())
                                .foregroundStyle(Color.textPrimary)
                            if isThisWeek {
                                TagPill(text: "This Week", color: .accentColor, style: .filled)
                            }
                        }
                        .padding(.top, Spacing.xs)

                        ForEach(weekEvents, id: \.id) { event in
                            calendarEventRow(event, highlight: isThisWeek)
                        }
                    }
                }
            }
        }
    }

    @State private var calendarFilter: CalendarFilter = .all

    private enum CalendarFilter {
        case all, holdings, watchlist
    }

    private var filteredCalendarEvents: [CalendarEvent] {
        let holdingSymbols = Set(appState.holdings.map(\.symbol))
        let watchSymbols = Set(appState.watchItems.map(\.symbol))

        switch calendarFilter {
        case .all:
            return appState.calendarEvents
        case .holdings:
            return appState.calendarEvents.filter { holdingSymbols.contains($0.symbol) }
        case .watchlist:
            return appState.calendarEvents.filter { watchSymbols.contains($0.symbol) }
        }
    }

    private func calendarEventRow(_ event: CalendarEvent, highlight: Bool) -> some View {
        CardView(padding: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Button {
                            appState.selectedChartSymbol = event.symbol
                            appState.selectedPage = .chart
                        } label: {
                            Text(event.symbol)
                                .font(AppFont.symbol())
                        }
                        .buttonStyle(.plain)

                        TagPill(text: event.eventType, color: .infoBlue, style: .subtle)
                    }

                    Text(FormatHelper.shortDate(event.date))
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                if let est = event.estimatedEPS {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Est: \(String(format: "%.2f", est))")
                            .font(AppFont.mono())
                            .foregroundStyle(Color.textSecondary)
                        if let actual = event.actualEPS {
                            let beat = actual >= est
                            Text("Act: \(String(format: "%.2f", actual))")
                                .font(AppFont.mono())
                                .foregroundStyle(beat ? Color.gainGreen : Color.lossRed)
                        }
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(highlight ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func weekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let end = Calendar.current.date(byAdding: .day, value: 6, to: date)!
        return "Week of \(formatter.string(from: date)) – \(formatter.string(from: end))"
    }
}
