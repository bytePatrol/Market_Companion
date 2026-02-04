// WatchlistView.swift
// MarketCompanion

import SwiftUI

struct WatchlistView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddHolding = false
    @State private var showAddWatch = false
    @State private var selectedTab = 0
    @State private var showNewGroupAlert = false
    @State private var newGroupName = ""
    @State private var newGroupColor = "#00BFBF"

    private let groupColors = ["#00BFBF", "#FF6B6B", "#FFD93D", "#6BCB77", "#4D96FF", "#9B59B6"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack {
                    PageHeader(title: "Watchlist", subtitle: "Holdings & tracked symbols")
                    Spacer()
                    Button {
                        showNewGroupAlert = true
                    } label: {
                        Label("New Group", systemImage: "folder.badge.plus")
                            .font(AppFont.subheadline())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Create a named group to organize your holdings and watchlist")
                }

                Picker("View", selection: $selectedTab) {
                    Text("Holdings (\(appState.holdings.count))").tag(0)
                    Text("Watchlist (\(appState.watchItems.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                .help("Switch between your owned positions and tracked symbols")

                if selectedTab == 0 {
                    holdingsTab
                } else {
                    watchlistTab
                }
            }
            .padding(Spacing.lg)
        }
        .sheet(isPresented: $showAddHolding) {
            AddHoldingSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showAddWatch) {
            AddWatchItemSheet()
                .environmentObject(appState)
        }
        .alert("New Group", isPresented: $showNewGroupAlert) {
            TextField("Group name", text: $newGroupName)
            Button("Cancel", role: .cancel) { newGroupName = "" }
            Button("Create") {
                let name = newGroupName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                appState.addWatchlistGroup(name: name, colorHex: groupColors.randomElement() ?? "#00BFBF")
                newGroupName = ""
            }
        }
        .onAppear {
            appState.loadWatchlistGroups()
        }
    }

    // MARK: - Holdings Tab

    private var holdingsTab: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Positions", icon: "briefcase.fill") {
                Button {
                    showAddHolding = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(AppFont.subheadline())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Add a new holding with symbol, shares, cost basis, and tags")
            }

            if appState.holdings.isEmpty {
                EmptyStateView(
                    icon: "briefcase",
                    title: "No Holdings",
                    message: "Add your positions to track them alongside market data.",
                    actionTitle: "Add Holding"
                ) {
                    showAddHolding = true
                }
                .frame(height: 250)
            } else {
                // Grouped holdings
                ForEach(appState.watchlistGroups) { group in
                    let groupHoldings = appState.holdings.filter { $0.groupId == group.id }
                    if !groupHoldings.isEmpty {
                        groupSection(group: group) {
                            ForEach(groupHoldings) { holding in
                                holdingRow(holding)
                                    .contextMenu {
                                        moveToGroupMenu(holdingId: holding.id)
                                    }
                            }
                        }
                    }
                }

                // Ungrouped
                let ungrouped = appState.holdings.filter { $0.groupId == nil }
                if !ungrouped.isEmpty {
                    DisclosureGroup("Ungrouped (\(ungrouped.count))") {
                        ForEach(ungrouped) { holding in
                            holdingRow(holding)
                                .contextMenu {
                                    moveToGroupMenu(holdingId: holding.id)
                                }
                        }
                    }
                    .font(AppFont.subheadline())
                    .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private func moveToGroupMenu(holdingId: Int64?) -> some View {
        Group {
            ForEach(appState.watchlistGroups) { group in
                Button {
                    if let id = holdingId {
                        appState.moveHoldingToGroup(holdingId: id, groupId: group.id)
                    }
                } label: {
                    Label(group.name, systemImage: "folder")
                }
            }
            Divider()
            Button("Remove from Group") {
                if let id = holdingId {
                    appState.moveHoldingToGroup(holdingId: id, groupId: nil)
                }
            }
        }
    }

    private func holdingRow(_ holding: Holding) -> some View {
        let quote = appState.quote(for: holding.symbol)
        let sparkline = appState.sparklineData(for: holding.symbol)

        return CardView(padding: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(holding.symbol)
                        .font(AppFont.symbol())
                        .foregroundStyle(Color.accentColor)
                        .onTapGesture {
                            appState.selectedChartSymbol = holding.symbol
                            appState.selectedPage = .chart
                        }
                    HStack(spacing: Spacing.xxs) {
                        ForEach(holding.tagList, id: \.self) { tag in
                            TagPill(text: tag, color: .textSecondary, style: .subtle)
                        }
                    }
                }

                if !sparkline.isEmpty {
                    SparklineView(
                        data: sparkline,
                        lineColor: Color.forChange(quote?.changePct ?? 0)
                    )
                    .frame(width: 60, height: 24)
                }

                Spacer()

                if let shares = holding.shares {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(shares)) shares")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)
                        if let cost = holding.costBasis {
                            Text("@ \(FormatHelper.price(cost))")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                }

                if let quote {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(FormatHelper.price(quote.last))
                            .font(AppFont.price())
                        ChangeBadge(changePct: quote.changePct)
                    }
                }

                Button {
                    if let id = holding.id {
                        appState.removeHolding(id: id)
                    }
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Remove this holding")
            }
        }
    }

    // MARK: - Watchlist Tab

    private var watchlistTab: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Tracked Symbols", icon: "eye.fill") {
                Button {
                    showAddWatch = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(AppFont.subheadline())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Add a symbol to your watchlist with a reason tag")
            }

            if appState.watchItems.isEmpty {
                EmptyStateView(
                    icon: "eye.slash",
                    title: "Empty Watchlist",
                    message: "Track symbols with reason tags to build your intelligence layer.",
                    actionTitle: "Add to Watchlist"
                ) {
                    showAddWatch = true
                }
                .frame(height: 250)
            } else {
                // Grouped watch items
                ForEach(appState.watchlistGroups) { group in
                    let groupItems = appState.watchItems.filter { $0.groupId == group.id }
                    if !groupItems.isEmpty {
                        groupSection(group: group) {
                            ForEach(groupItems) { item in
                                watchItemRow(item)
                                    .contextMenu {
                                        moveWatchItemToGroupMenu(itemId: item.id)
                                    }
                            }
                        }
                    }
                }

                // Ungrouped
                let ungrouped = appState.watchItems.filter { $0.groupId == nil }
                if !ungrouped.isEmpty {
                    DisclosureGroup("Ungrouped (\(ungrouped.count))") {
                        ForEach(ungrouped) { item in
                            watchItemRow(item)
                                .contextMenu {
                                    moveWatchItemToGroupMenu(itemId: item.id)
                                }
                        }
                    }
                    .font(AppFont.subheadline())
                    .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private func moveWatchItemToGroupMenu(itemId: Int64?) -> some View {
        Group {
            ForEach(appState.watchlistGroups) { group in
                Button {
                    if let id = itemId {
                        appState.moveWatchItemToGroup(itemId: id, groupId: group.id)
                    }
                } label: {
                    Label(group.name, systemImage: "folder")
                }
            }
            Divider()
            Button("Remove from Group") {
                if let id = itemId {
                    appState.moveWatchItemToGroup(itemId: id, groupId: nil)
                }
            }
        }
    }

    private func watchItemRow(_ item: WatchItem) -> some View {
        let quote = appState.quote(for: item.symbol)

        return CardView(padding: Spacing.sm) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Spacing.xs) {
                        Text(item.symbol)
                            .font(AppFont.symbol())
                            .foregroundStyle(Color.accentColor)
                            .onTapGesture {
                                appState.selectedChartSymbol = item.symbol
                                appState.selectedPage = .chart
                            }
                        ReasonTag(reason: item.reasonTag)
                    }
                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let quote {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(FormatHelper.price(quote.last))
                            .font(AppFont.price())
                        ChangeBadge(changePct: quote.changePct)
                    }
                }

                Button {
                    if let id = item.id {
                        appState.removeWatchItem(id: id)
                    }
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Remove this watch item")
            }
        }
    }

    // MARK: - Group Section

    @ViewBuilder
    private func groupSection<Content: View>(group: WatchlistGroup, @ViewBuilder content: @escaping () -> Content) -> some View {
        DisclosureGroup {
            content()
        } label: {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(group.color)
                    .frame(width: 8, height: 8)
                Text(group.name)
                    .font(AppFont.subheadline())
            }
            .contextMenu {
                Button("Rename") {
                    // Inline rename handled by alert
                }
                Menu("Change Color") {
                    ForEach(groupColors, id: \.self) { hex in
                        Button {
                            guard group.id != nil else { return }
                            var updated = group
                            updated.colorHex = hex
                            do {
                                try appState.watchlistGroupRepo.save(&updated)
                                appState.loadWatchlistGroups()
                            } catch {
                                print("[Watchlist] Color change failed: \(error)")
                            }
                        } label: {
                            Label(hex, systemImage: "circle.fill")
                        }
                    }
                }
                Divider()
                Button("Delete Group", role: .destructive) {
                    if let id = group.id {
                        appState.deleteWatchlistGroup(id: id)
                    }
                }
            }
        }
    }
}

// MARK: - Add Holding Sheet

struct AddHoldingSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var symbol = ""
    @State private var shares = ""
    @State private var costBasis = ""
    @State private var tags = ""

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Add Holding")
                .font(AppFont.title())

            VStack(alignment: .leading, spacing: Spacing.sm) {
                TextField("Symbol (e.g., AAPL)", text: $symbol)
                    .textFieldStyle(.roundedBorder)
                    .help("Ticker symbol, e.g. AAPL")

                HStack(spacing: Spacing.sm) {
                    TextField("Shares (optional)", text: $shares)
                        .textFieldStyle(.roundedBorder)
                        .help("Number of shares you own (optional)")
                    TextField("Cost basis (optional)", text: $costBasis)
                        .textFieldStyle(.roundedBorder)
                        .help("Your average purchase price per share (optional)")
                }

                TextField("Tags (comma-separated)", text: $tags)
                    .textFieldStyle(.roundedBorder)
                    .help("Comma-separated labels for grouping, e.g. tech, swing")
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    Task {
                        await appState.addHolding(
                            symbol: symbol,
                            shares: Double(shares),
                            costBasis: Double(costBasis),
                            tags: tags
                        )
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(symbol.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 400)
    }
}

// MARK: - Add Watch Item Sheet

struct AddWatchItemSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var symbol = ""
    @State private var reason = "Sector momentum"
    @State private var note = ""

    private let reasonOptions = [
        "Sector momentum",
        "Earnings catalyst",
        "Unusual volume",
        "Breakout candidate",
        "Support level",
        "Technical setup",
        "News catalyst"
    ]

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Add to Watchlist")
                .font(AppFont.title())

            VStack(alignment: .leading, spacing: Spacing.sm) {
                TextField("Symbol (e.g., TSLA)", text: $symbol)
                    .textFieldStyle(.roundedBorder)
                    .help("Ticker symbol to track")

                Picker("Reason", selection: $reason) {
                    ForEach(reasonOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .help("Why you're watching this symbol")

                TextField("Note (optional)", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .help("Additional context or thesis (optional)")
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    Task {
                        await appState.addWatchItem(symbol: symbol, reason: reason, note: note.isEmpty ? nil : note)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(symbol.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 400)
    }
}
