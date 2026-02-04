// MarketCompanionApp.swift
// MarketCompanion
//
// "ThinkorSwim for execution. Market Companion for intelligence."

import SwiftUI

@main
struct MarketCompanionApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Main Window
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.appearanceManager.resolvedColorScheme)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    await appState.bootstrap()
                }
                .onChange(of: appState.showHelpWindow) { _, show in
                    if show {
                        openWindow(id: "help")
                        appState.showHelpWindow = false
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Market") {
                Button("Generate Report") {
                    Task { await appState.generateAutoReport() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Log Trade...") {
                    appState.showTradeEntry = true
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("Quick Search...") {
                    appState.showCommandPalette = true
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Button("Refresh Data") {
                    Task { await appState.refreshData() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Divider()

                Button("Generate Morning Report") {
                    Task { await appState.generateMorningReport() }
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Button("Generate Close Report") {
                    Task { await appState.generateCloseReport() }
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .help) {
                Button("Market Companion Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)
            }

            CommandMenu("View") {
                ForEach(NavigationPage.allCases) { page in
                    Button(page.rawValue) {
                        appState.selectedPage = page
                    }
                }

                Divider()

                Button("Toggle Companion Window") {
                    openWindow(id: "companion")
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }

        // Help Window
        Window("Help", id: "help") {
            HelpView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 900, height: 650)

        // Companion Window (compact, always-on-top capable)
        Window("Companion", id: "companion") {
            CompanionWindowView()
                .environmentObject(appState)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 320, height: 500)

        // Menu Bar Extra
        MenuBarExtra("Market Companion", systemImage: "chart.line.uptrend.xyaxis") {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        // Settings
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Menu Bar View

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                Text("Market Companion")
                    .font(AppFont.headline())
                Spacer()
                if let overview = appState.marketOverview {
                    RegimeBadge(regime: overview.marketRegime)
                }
            }

            SubtleDivider()

            // Open positions summary
            let openTrades = appState.trades.filter { !$0.isClosed }
            if !openTrades.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                    Text("\(openTrades.count) open position\(openTrades.count == 1 ? "" : "s")")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)
                }
                SubtleDivider()
            }

            // Top movers in holdings
            if !appState.quotes.isEmpty {
                let sorted = appState.quotes.sorted { abs($0.changePct) > abs($1.changePct) }
                ForEach(sorted.prefix(5)) { quote in
                    HStack {
                        Text(quote.symbol)
                            .font(AppFont.symbol())
                            .frame(width: 50, alignment: .leading)
                        Spacer()
                        Text(FormatHelper.price(quote.last))
                            .font(AppFont.monoSmall())
                            .foregroundStyle(Color.textSecondary)
                        ChangeBadge(changePct: quote.changePct)
                    }
                }
            } else {
                Text("No data loaded")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
            }

            SubtleDivider()

            // Quick actions
            Button {
                openWindow(id: "companion")
            } label: {
                Label("Open Companion", systemImage: "sidebar.right")
                    .font(AppFont.body())
            }
            .buttonStyle(.plain)

            Button {
                appState.showTradeEntry = true
            } label: {
                Label("Log Trade...", systemImage: "plus.circle")
                    .font(AppFont.body())
            }
            .buttonStyle(.plain)

            Button {
                Task { await appState.refreshData() }
            } label: {
                Label("Refresh Data", systemImage: "arrow.clockwise")
                    .font(AppFont.body())
            }
            .buttonStyle(.plain)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .font(AppFont.body())
            .keyboardShortcut("q")
        }
        .padding(Spacing.md)
        .frame(width: 280)
    }
}
