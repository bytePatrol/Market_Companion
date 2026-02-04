// CommandPaletteView.swift
// MarketCompanion
//
// Spotlight-style command palette for quick navigation and search.

import SwiftUI

struct CommandPaletteView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Scrim
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Palette
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.textTertiary)

                    TextField("Search pages, symbols, reports...", text: $searchText)
                        .font(AppFont.body())
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit {
                            if let first = filteredResults.first {
                                executeResult(first)
                            }
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("ESC")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.surfaceElevated)
                        }
                }
                .padding(Spacing.md)

                SubtleDivider()

                // Results
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if filteredResults.isEmpty && !searchText.isEmpty {
                            HStack {
                                Spacer()
                                Text("No results for \"\(searchText)\"")
                                    .font(AppFont.body())
                                    .foregroundStyle(Color.textTertiary)
                                Spacer()
                            }
                            .padding(Spacing.lg)
                        } else {
                            let grouped = Dictionary(grouping: filteredResults, by: \.category)
                            let sortedKeys = grouped.keys.sorted { $0.order < $1.order }

                            ForEach(sortedKeys, id: \.self) { category in
                                sectionHeader(category.rawValue)
                                ForEach(grouped[category] ?? [], id: \.id) { result in
                                    resultRow(result)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .frame(width: 500)
            .background {
                RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous)
                    .fill(Color.surfacePrimary)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
            .padding(.top, 80)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            isFocused = true
        }
        .onExitCommand {
            dismiss()
        }
    }

    // MARK: - Results

    private enum ResultCategory: String, Hashable {
        case pages = "Pages"
        case symbols = "Symbols"
        case reports = "Reports"
        case actions = "Actions"

        var order: Int {
            switch self {
            case .pages: return 0
            case .actions: return 1
            case .symbols: return 2
            case .reports: return 3
            }
        }
    }

    private struct SearchResult: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let category: ResultCategory
        let action: () -> Void
    }

    private var filteredResults: [SearchResult] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        var results: [SearchResult] = []

        // Pages
        for page in NavigationPage.allCases {
            if query.isEmpty || page.rawValue.lowercased().contains(query) || page.shortLabel.lowercased().contains(query) {
                results.append(SearchResult(
                    icon: page.icon,
                    title: page.shortLabel,
                    subtitle: "Navigate to \(page.rawValue)",
                    category: .pages,
                    action: { [weak appState] in
                        appState?.selectedPage = page
                        dismiss()
                    }
                ))
            }
        }

        // Actions
        if query.isEmpty || "generate report".contains(query) || "morning".contains(query) || "close".contains(query) {
            results.append(SearchResult(
                icon: "doc.badge.plus",
                title: "Generate Report",
                subtitle: "Auto-picks morning or close",
                category: .actions,
                action: { [weak appState] in
                    guard let appState else { return }
                    Task { await appState.generateAutoReport() }
                    dismiss()
                }
            ))
        }

        if query.isEmpty || "log trade".contains(query) {
            results.append(SearchResult(
                icon: "plus.circle",
                title: "Log Trade",
                subtitle: "Record a new trade",
                category: .actions,
                action: { [weak appState] in
                    appState?.showTradeEntry = true
                    dismiss()
                }
            ))
        }

        if query.isEmpty || "help".contains(query) {
            results.append(SearchResult(
                icon: "questionmark.circle",
                title: "Help",
                subtitle: "Open the help window",
                category: .actions,
                action: { [weak appState] in
                    appState?.showHelpWindow = true
                    dismiss()
                }
            ))
        }

        if query.isEmpty || "refresh".contains(query) {
            results.append(SearchResult(
                icon: "arrow.clockwise",
                title: "Refresh Data",
                subtitle: "Fetch latest market data",
                category: .actions,
                action: { [weak appState] in
                    guard let appState else { return }
                    Task { await appState.refreshData() }
                    dismiss()
                }
            ))
        }

        // Workspace actions
        if query.isEmpty || "save layout".contains(query) || "workspace".contains(query) {
            results.append(SearchResult(
                icon: "rectangle.stack.badge.plus",
                title: "Save Current Layout",
                subtitle: "Save workspace as a named layout",
                category: .actions,
                action: { [weak appState] in
                    guard let appState else { return }
                    let name = "Workspace \(appState.workspaces.count + 1)"
                    appState.saveWorkspace(name: name)
                    dismiss()
                }
            ))
        }

        for workspace in (appState.workspaces) {
            if query.isEmpty || workspace.name.lowercased().contains(query) || "switch".contains(query) || "workspace".contains(query) {
                results.append(SearchResult(
                    icon: "rectangle.stack",
                    title: "Switch to \(workspace.name)",
                    subtitle: "\(workspace.selectedPage)\(workspace.chartSymbol.map { " - \($0)" } ?? "")",
                    category: .actions,
                    action: { [weak appState] in
                        appState?.loadWorkspace(workspace)
                        dismiss()
                    }
                ))
            }
        }

        // Symbols
        if !query.isEmpty {
            let matchingQuotes = appState.quotes.filter {
                $0.symbol.lowercased().contains(query)
            }
            for quote in matchingQuotes.prefix(5) {
                results.append(SearchResult(
                    icon: "chart.line.uptrend.xyaxis",
                    title: quote.symbol,
                    subtitle: "\(FormatHelper.price(quote.last)) \(FormatHelper.percent(quote.changePct))",
                    category: .symbols,
                    action: { [weak appState] in
                        appState?.selectedPage = .heatmap
                        dismiss()
                    }
                ))
            }
        }

        // Reports
        if !query.isEmpty && ("report".contains(query) || "morning".contains(query) || "close".contains(query)) {
            for report in appState.reports.prefix(3) {
                results.append(SearchResult(
                    icon: report.type == .morning ? "sunrise.fill" : "sunset.fill",
                    title: "\(report.type == .morning ? "Morning" : "Close") Report",
                    subtitle: FormatHelper.fullDate(report.createdAt),
                    category: .reports,
                    action: { [weak appState] in
                        appState?.selectedPage = .reports
                        dismiss()
                    }
                ))
            }
        }

        // Limit total results when no query
        if query.isEmpty {
            return Array(results.prefix(12))
        }

        return results
    }

    // MARK: - Views

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(Color.textTertiary)
            .tracking(1)
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xxs)
    }

    private func resultRow(_ result: SearchResult) -> some View {
        Button {
            result.action()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: result.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(result.title)
                        .font(AppFont.subheadline())
                        .foregroundStyle(Color.textPrimary)
                    Text(result.subtitle)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
            .background {
                Color.clear
            }
        }
        .buttonStyle(.plain)
    }

    private func executeResult(_ result: SearchResult) {
        result.action()
    }

    private func dismiss() {
        appState.showCommandPalette = false
    }
}
