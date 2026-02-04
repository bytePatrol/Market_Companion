// ContentView.swift
// MarketCompanion

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            HSplitView {
                SidebarView()
                    .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if appState.showCommandPalette {
                CommandPaletteView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .preferredColorScheme(appState.appearanceManager.resolvedColorScheme)
        .tint(appState.appearanceManager.accentChoice.color)
        .animation(.easeInOut(duration: 0.2), value: appState.showCommandPalette)
        .sheet(isPresented: $appState.showTradeEntry) {
            TradeEntrySheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showPositionSizer) {
            PositionSizeCalculator()
        }
        .alert("Error", isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )) {
            Button("OK") { appState.errorMessage = nil }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .sheet(isPresented: .init(
            get: { !appState.hasCompletedOnboarding && appState.holdings.isEmpty },
            set: { _ in }
        )) {
            OnboardingView()
                .environmentObject(appState)
                .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedPage {
        case .dashboard:
            DashboardView()
        case .heatmap:
            HeatmapView()
        case .chart:
            CandlestickChartView()
        case .portfolio:
            PortfolioRiskView()
        case .watchlist:
            WatchlistView()
        case .alerts:
            AlertsView()
        case .screener:
            ScreenerView()
        case .research:
            ResearchView()
        case .journal:
            JournalView()
        case .reports:
            ReportsView()
        case .replay:
            ReplayView()
        case .dataProviders:
            DataProvidersSettingsView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSaveWorkspace = false
    @State private var workspaceName = ""
    @State private var showWorkspaceManager = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                    Text("Market Companion")
                        .font(AppFont.headline())
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    workspaceMenu
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)

                if appState.isUsingDemoData {
                    DemoBanner()
                        .padding(.horizontal, Spacing.sm)
                }
            }
            .padding(.bottom, Spacing.xs)

            // Navigation items
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    sidebarSection {
                        sidebarButton(.dashboard)
                        sidebarButton(.heatmap)
                        sidebarButton(.chart)
                        sidebarButton(.portfolio)
                    }

                    sidebarSectionHeader("Monitor")
                    sidebarSection {
                        sidebarButton(.watchlist)
                        sidebarButton(.alerts)
                        sidebarButton(.screener)
                        sidebarButton(.research)
                    }

                    sidebarSectionHeader("Record")
                    sidebarSection {
                        sidebarButton(.journal)
                        sidebarButton(.reports)
                        sidebarButton(.replay)
                    }

                    sidebarSectionHeader("Configure")
                    sidebarSection {
                        sidebarButton(.dataProviders)
                        sidebarButton(.settings)
                    }
                }
                .padding(.horizontal, Spacing.sm)
            }

            Spacer(minLength: 0)

            // Status bar at bottom
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(appState.isLoading ? Color.warningAmber : Color.gainGreen)
                    .frame(width: 6, height: 6)
                Text(appState.isLoading ? "Updating..." : "Ready")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
                Spacer()
                if let overview = appState.marketOverview {
                    RegimeBadge(regime: overview.marketRegime)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(.bar)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showSaveWorkspace) {
            VStack(spacing: Spacing.lg) {
                Text("Save Workspace")
                    .font(AppFont.title())
                TextField("Workspace Name", text: $workspaceName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") { showSaveWorkspace = false }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Save") {
                        appState.saveWorkspace(name: workspaceName)
                        workspaceName = ""
                        showSaveWorkspace = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(workspaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(Spacing.xl)
            .frame(width: 350)
        }
        .sheet(isPresented: $showWorkspaceManager) {
            WorkspaceManagerView()
                .environmentObject(appState)
        }
    }

    // MARK: - Workspace Menu

    private var workspaceMenu: some View {
        Menu {
            if !appState.workspaces.isEmpty {
                Section("Saved Layouts") {
                    ForEach(appState.workspaces) { workspace in
                        Button {
                            appState.loadWorkspace(workspace)
                        } label: {
                            Label(workspace.name, systemImage: "square.grid.2x2")
                        }
                    }
                }
            }

            Section {
                Button("Save Current Layout...") {
                    workspaceName = appState.currentWorkspaceName ?? ""
                    showSaveWorkspace = true
                }
                Button("Manage Layouts...") {
                    showWorkspaceManager = true
                }
            }
        } label: {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 20)
    }

    private func sidebarButton(_ page: NavigationPage) -> some View {
        Button {
            appState.selectedPage = page
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: page.icon)
                    .font(.system(size: 13))
                    .frame(width: 20)
                    .foregroundStyle(appState.selectedPage == page ? Color.accentColor : Color.textSecondary)
                Text(page.shortLabel)
                    .font(AppFont.body())
                    .foregroundStyle(appState.selectedPage == page ? Color.textPrimary : Color.textSecondary)
                Spacer()
                if page == .alerts && !appState.alertEvents.isEmpty {
                    Text("\(appState.alertEvents.count)")
                        .font(AppFont.caption())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor))
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                    .fill(appState.selectedPage == page ? Color.accentColor.opacity(0.12) : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }

    private func sidebarSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.textTertiary)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xxs)
    }

    private func sidebarSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            content()
        }
    }
}
