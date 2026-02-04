// AppState.swift
// MarketCompanion
//
// Central observable state for the entire app.
// Manages data provider, repositories, and shared state.

import SwiftUI

// MARK: - Navigation

enum NavigationPage: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case heatmap = "Heatmap"
    case chart = "Chart"
    case portfolio = "Portfolio"
    case watchlist = "Watchlist"
    case alerts = "Alerts"
    case screener = "Screener"
    case research = "Research"
    case journal = "Journal"
    case reports = "Reports"
    case replay = "Replay"
    case dataProviders = "Data Providers"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .heatmap: return "square.grid.3x3.fill"
        case .chart: return "chart.xyaxis.line"
        case .portfolio: return "chart.pie"
        case .watchlist: return "eye"
        case .alerts: return "bell.badge"
        case .screener: return "magnifyingglass"
        case .research: return "newspaper"
        case .journal: return "book"
        case .reports: return "doc.text"
        case .replay: return "clock.arrow.circlepath"
        case .dataProviders: return "externaldrive.connected.to.line.below"
        case .settings: return "gearshape"
        }
    }

    var shortLabel: String {
        switch self {
        case .dashboard: return "Today"
        case .heatmap: return "Heatmap"
        case .chart: return "Chart"
        case .portfolio: return "Portfolio"
        case .watchlist: return "Watchlist"
        case .alerts: return "Alerts"
        case .screener: return "Screener"
        case .research: return "Research"
        case .journal: return "Journal"
        case .reports: return "Reports"
        case .replay: return "Replay"
        case .dataProviders: return "Providers"
        case .settings: return "Settings"
        }
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    // Navigation
    @Published var selectedPage: NavigationPage = .dashboard

    // Data
    @Published var holdings: [Holding] = []
    @Published var watchItems: [WatchItem] = []
    @Published var quotes: [Quote] = []
    @Published var marketOverview: MarketOverview?
    @Published var reports: [Report] = []
    @Published var alertRules: [AlertRule] = []
    @Published var alertEvents: [AlertEvent] = []
    @Published var trades: [Trade] = []
    @Published var newsItems: [NewsItem] = []
    @Published var calendarEvents: [CalendarEvent] = []

    // UI State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCompanionWindow = false
    @Published var showTradeEntry = false
    @Published var showCommandPalette = false
    @Published var selectedChartSymbol: String? = nil
    @Published var showPositionSizer = false
    @Published var showHelpWindow = false

    // Preferences
    @Published var reportMode: ReportMode = .detailed
    @Published var companionFocusMode = false
    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    // Provider State
    @Published var dataMode: DataMode = .demo
    @Published var isUsingDemoData = true

    // Services
    let keychainService = KeychainService.shared
    let db = DatabaseManager.shared
    lazy var scheduler = SchedulerService()
    lazy var audioBriefing = AudioBriefingService()
    let appearanceManager = AppearanceManager()

    // Provider Router (replaces single-provider model)
    let providerRouter = ProviderRouter()

    // Convenience: the router *is* the data provider (composite pattern)
    var dataProvider: MarketDataProvider { providerRouter }

    // Repositories
    lazy var holdingRepo = HoldingRepository(db: db)
    lazy var watchItemRepo = WatchItemRepository(db: db)
    lazy var quoteRepo = QuoteRepository(db: db)
    lazy var dailyBarRepo = DailyBarRepository(db: db)
    lazy var reportRepo = ReportRepository(db: db)
    lazy var alertRuleRepo = AlertRuleRepository(db: db)
    lazy var alertEventRepo = AlertEventRepository(db: db)
    lazy var tradeRepo = TradeRepository(db: db)
    lazy var tradeContextRepo = TradeContextRepository(db: db)
    lazy var newsRepo = NewsRepository(db: db)
    lazy var calendarEventRepo = CalendarEventRepository(db: db)
    lazy var chartDrawingRepo = ChartDrawingRepository(db: db)
    lazy var workspaceRepo = WorkspaceRepository(db: db)
    lazy var watchlistGroupRepo = WatchlistGroupRepository(db: db)

    // Workspaces
    @Published var workspaces: [WorkspaceLayout] = []
    @Published var currentWorkspaceName: String?

    // Watchlist Groups
    @Published var watchlistGroups: [WatchlistGroup] = []

    init() {
        self.dataMode = providerRouter.dataMode
        self.isUsingDemoData = providerRouter.dataMode == .demo
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        // Seed demo data if first run
        do {
            try holdingRepo.seedIfEmpty()
            try watchItemRepo.seedIfEmpty()
        } catch {
            print("[AppState] Seed error: \(error)")
        }

        // Load persisted data
        loadFromDatabase()

        // Fetch fresh quotes
        await refreshData()

        // Start alert engine
        startAlertEngine()

        // Start in-app scheduler
        scheduler.startScheduler(
            morningAction: { [weak self] in await self?.generateMorningReport() },
            closeAction: { [weak self] in await self?.generateCloseReport() }
        )
    }

    // MARK: - Load from DB

    func loadFromDatabase() {
        do {
            holdings = try holdingRepo.all()
            watchItems = try watchItemRepo.all()
            quotes = try quoteRepo.all()
            reports = try reportRepo.all()
            alertRules = try alertRuleRepo.all()
            alertEvents = try alertEventRepo.all(limit: 50)
            trades = try tradeRepo.all()
            newsItems = try newsRepo.recent(days: 7)
            calendarEvents = try calendarEventRepo.upcoming(days: 30)
            workspaces = (try? workspaceRepo.all()) ?? []
            watchlistGroups = (try? watchlistGroupRepo.all()) ?? []
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
    }

    // MARK: - Refresh Data

    func refreshData() async {
        isLoading = true
        errorMessage = nil

        do {
            let allSymbols = Array(Set(holdings.map(\.symbol) + watchItems.map(\.symbol)))
            guard !allSymbols.isEmpty else {
                isLoading = false
                return
            }

            // Fetch quotes
            let freshQuotes = try await dataProvider.fetchQuotes(symbols: allSymbols)
            try quoteRepo.upsert(freshQuotes)
            quotes = freshQuotes

            // Fetch market overview
            let overview = try await dataProvider.fetchMarketOverview()
            marketOverview = overview

            // Fetch daily bars for sparklines and chart
            let calendar = Calendar.current
            let to = Date()
            let from = calendar.date(byAdding: .day, value: -180, to: to)!

            for symbol in allSymbols {
                // Skip if we already have recent bars
                if let latest = try? dailyBarRepo.latestDate(for: symbol),
                   calendar.isDateInToday(latest) {
                    continue
                }
                let bars = try await dataProvider.fetchDailyBars(symbol: symbol, from: from, to: to)
                try dailyBarRepo.save(bars)
            }

            // Fetch news for tracked symbols (last 7 days)
            let newsRange = DateRange.lastDays(7)
            for symbol in allSymbols {
                if let news = try? await dataProvider.fetchCompanyNews(symbol: symbol, range: newsRange) {
                    try? newsRepo.save(news)
                }
            }
            newsItems = (try? newsRepo.recent(days: 7)) ?? []

            // Fetch calendar (next 30 days)
            let calRange = DateRange(from: Date(), to: Calendar.current.date(byAdding: .day, value: 30, to: Date())!)
            if let events = try? await dataProvider.fetchCalendar(range: calRange) {
                try? calendarEventRepo.save(events)
            }
            calendarEvents = (try? calendarEventRepo.upcoming(days: 30)) ?? []

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Provider Management

    func setDataMode(_ mode: DataMode) {
        providerRouter.setDataMode(mode)
        dataMode = mode
        isUsingDemoData = (mode == .demo)
    }

    func setPrimaryProvider(_ id: ProviderID) {
        providerRouter.setPrimary(id)
        objectWillChange.send()
    }

    func setFallbackProvider(_ id: ProviderID?) {
        providerRouter.setFallback(id)
        objectWillChange.send()
    }

    // MARK: - Holding Management

    func addHolding(symbol: String, shares: Double? = nil, costBasis: Double? = nil, tags: String = "") async {
        var holding = Holding(symbol: symbol.uppercased(), shares: shares, costBasis: costBasis, tags: tags)
        do {
            try holdingRepo.save(&holding)
            loadFromDatabase()
            await refreshData()
        } catch {
            errorMessage = "Failed to add holding: \(error.localizedDescription)"
        }
    }

    func removeHolding(id: Int64) {
        do {
            try holdingRepo.delete(id: id)
            loadFromDatabase()
        } catch {
            errorMessage = "Failed to remove holding: \(error.localizedDescription)"
        }
    }

    // MARK: - Watch Item Management

    func addWatchItem(symbol: String, reason: String, note: String? = nil) async {
        var item = WatchItem(symbol: symbol.uppercased(), reasonTag: reason, note: note)
        do {
            try watchItemRepo.save(&item)
            loadFromDatabase()
            await refreshData()
        } catch {
            errorMessage = "Failed to add watch item: \(error.localizedDescription)"
        }
    }

    func removeWatchItem(id: Int64) {
        do {
            try watchItemRepo.delete(id: id)
            loadFromDatabase()
        } catch {
            errorMessage = "Failed to remove watch item: \(error.localizedDescription)"
        }
    }

    // MARK: - Quote Helpers

    func quote(for symbol: String) -> Quote? {
        quotes.first(where: { $0.symbol == symbol })
    }

    func sparklineData(for symbol: String) -> [Double] {
        (try? dailyBarRepo.forSymbol(symbol, limit: 20))?.map(\.close) ?? []
    }

    // MARK: - Report Generation

    private lazy var reportGenerator = ReportGenerator(
        dataProvider: dataProvider,
        holdingRepo: holdingRepo,
        watchItemRepo: watchItemRepo,
        quoteRepo: quoteRepo,
        dailyBarRepo: dailyBarRepo,
        tradeRepo: tradeRepo,
        reportRepo: reportRepo
    )

    @Published var isGeneratingReport = false

    func generateMorningReport() async {
        isGeneratingReport = true
        do {
            _ = try await reportGenerator.generateMorningReport(mode: reportMode)
            loadFromDatabase()
        } catch {
            errorMessage = "Failed to generate morning report: \(error.localizedDescription)"
        }
        isGeneratingReport = false
    }

    func generateCloseReport() async {
        isGeneratingReport = true
        do {
            _ = try await reportGenerator.generateCloseReport(mode: reportMode)
            loadFromDatabase()
        } catch {
            errorMessage = "Failed to generate close report: \(error.localizedDescription)"
        }
        isGeneratingReport = false
    }

    func generateAutoReport() async {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            await generateMorningReport()
        } else {
            await generateCloseReport()
        }
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    // MARK: - Alert Engine

    private(set) lazy var alertEngine = AlertEngine(
        dataProvider: dataProvider,
        alertRuleRepo: alertRuleRepo,
        alertEventRepo: alertEventRepo,
        quoteRepo: quoteRepo,
        dailyBarRepo: dailyBarRepo
    )

    func startAlertEngine() {
        alertEngine.startPolling(interval: 60)
    }

    func stopAlertEngine() {
        alertEngine.stopPolling()
    }

    func triggerAlertCheck() async {
        await alertEngine.checkAllRules()
        loadFromDatabase()
    }

    // MARK: - Alert Management

    func addAlertRule(symbol: String?, sector: String?, type: AlertRuleType, threshold: Double) {
        var rule = AlertRule(symbol: symbol, sector: sector, type: type, thresholdValue: threshold)
        do {
            try alertRuleRepo.save(&rule)
            loadFromDatabase()
        } catch {
            errorMessage = "Failed to create alert rule: \(error.localizedDescription)"
        }
    }

    func deleteAlertRule(id: Int64) {
        do {
            try alertRuleRepo.delete(id: id)
            loadFromDatabase()
        } catch {
            errorMessage = "Failed to delete alert rule: \(error.localizedDescription)"
        }
    }

    // MARK: - Trade Management

    func logTrade(symbol: String, side: TradeSide, qty: Double, entryPrice: Double, notes: String = "", tags: String = "", checklistJson: String = "") {
        var trade = Trade(symbol: symbol.uppercased(), side: side, qty: qty, entryPrice: entryPrice, notes: notes, tags: tags)
        do {
            try tradeRepo.save(&trade)

            // Auto-capture context
            if let tradeId = trade.id {
                var context = TradeContext(
                    tradeId: tradeId,
                    vixProxy: marketOverview?.vixProxy,
                    marketBreadthProxy: marketOverview.map { Double($0.breadthAdvancing) / Double($0.breadthAdvancing + $0.breadthDeclining) },
                    volatilityRegime: marketOverview?.volatilityRegime.rawValue ?? "unknown",
                    timeOfDay: FormatHelper.timeOnly(Date()),
                    checklistJson: checklistJson
                )
                try tradeContextRepo.save(&context)
            }

            loadFromDatabase()
        } catch {
            errorMessage = "Failed to log trade: \(error.localizedDescription)"
        }
    }

    func closeTrade(id: Int64, exitPrice: Double) {
        do {
            try db.dbQueue.write { db in
                if var trade = try Trade.fetchOne(db, id: id) {
                    trade.exitPrice = exitPrice
                    trade.exitTime = Date()
                    try trade.update(db)
                }
            }
            loadFromDatabase()
        } catch {
            errorMessage = "Failed to close trade: \(error.localizedDescription)"
        }
    }

    // MARK: - Workspace Management

    func loadWorkspaces() {
        do {
            workspaces = try workspaceRepo.all()
        } catch {
            print("[AppState] Failed to load workspaces: \(error)")
        }
    }

    func saveWorkspace(name: String) {
        var layout = WorkspaceLayout(
            name: name,
            selectedPage: selectedPage.rawValue,
            companionVisible: showCompanionWindow,
            companionFocusMode: companionFocusMode,
            chartSymbol: selectedChartSymbol
        )
        do {
            try workspaceRepo.save(&layout)
            loadWorkspaces()
            currentWorkspaceName = name
        } catch {
            errorMessage = "Failed to save workspace: \(error.localizedDescription)"
        }
    }

    func loadWorkspace(_ workspace: WorkspaceLayout) {
        if let page = NavigationPage(rawValue: workspace.selectedPage) {
            selectedPage = page
        }
        showCompanionWindow = workspace.companionVisible
        companionFocusMode = workspace.companionFocusMode
        selectedChartSymbol = workspace.chartSymbol
        currentWorkspaceName = workspace.name
    }

    func deleteWorkspace(id: Int64) {
        do {
            try workspaceRepo.delete(id: id)
            loadWorkspaces()
        } catch {
            errorMessage = "Failed to delete workspace: \(error.localizedDescription)"
        }
    }

    // MARK: - Watchlist Group Management

    func loadWatchlistGroups() {
        do {
            watchlistGroups = try watchlistGroupRepo.all()
        } catch {
            print("[AppState] Failed to load watchlist groups: \(error)")
        }
    }

    func addWatchlistGroup(name: String, colorHex: String = "#00BFBF") {
        let sortOrder = (watchlistGroups.map(\.sortOrder).max() ?? -1) + 1
        var group = WatchlistGroup(name: name, sortOrder: sortOrder, colorHex: colorHex)
        do {
            try watchlistGroupRepo.save(&group)
            loadWatchlistGroups()
        } catch {
            errorMessage = "Failed to create group: \(error.localizedDescription)"
        }
    }

    func deleteWatchlistGroup(id: Int64) {
        do {
            try watchlistGroupRepo.delete(id: id)
            loadWatchlistGroups()
        } catch {
            errorMessage = "Failed to delete group: \(error.localizedDescription)"
        }
    }

    func moveHoldingToGroup(holdingId: Int64, groupId: Int64?) {
        do {
            try db.dbQueue.write { db in
                if var holding = try Holding.fetchOne(db, id: holdingId) {
                    holding.groupId = groupId
                    try holding.update(db)
                }
            }
            loadFromDatabase()
        } catch {
            errorMessage = "Failed to move holding: \(error.localizedDescription)"
        }
    }

    func moveWatchItemToGroup(itemId: Int64, groupId: Int64?) {
        do {
            try db.dbQueue.write { db in
                if var item = try WatchItem.fetchOne(db, id: itemId) {
                    item.groupId = groupId
                    try item.update(db)
                }
            }
            loadFromDatabase()
        } catch {
            errorMessage = "Failed to move watch item: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete All

    func deleteAllData() {
        do {
            try db.deleteAllData()
            try keychainService.deleteAll()
            holdings = []
            watchItems = []
            quotes = []
            reports = []
            alertRules = []
            alertEvents = []
            trades = []
            newsItems = []
            calendarEvents = []
            marketOverview = nil
        } catch {
            errorMessage = "Failed to delete data: \(error.localizedDescription)"
        }
    }
}
