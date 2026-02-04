// TechnicalScanView.swift
// MarketCompanion
//
// Predefined scan templates and custom multi-criteria scanner.

import SwiftUI

struct TechnicalScanView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCriteria: Set<TechnicalScanCriteria> = []
    @State private var scanResults: [ScanResult] = []
    @State private var isScanning = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Preset templates
            SectionHeader(title: "Scan Templates", icon: "wand.and.stars")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(ScanTemplate.presets) { template in
                        Button {
                            selectedCriteria = Set(template.criteria)
                            runScan()
                        } label: {
                            VStack(spacing: Spacing.xxs) {
                                Image(systemName: template.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.accentColor)
                                Text(template.name)
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.textPrimary)
                                Text(template.description)
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.textTertiary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 120, height: 80)
                            .background {
                                RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                    .fill(Color.surfaceSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Custom criteria toggles
            SectionHeader(title: "Custom Criteria", icon: "slider.horizontal.3")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: Spacing.xs) {
                ForEach(TechnicalScanCriteria.allCases) { criterion in
                    Toggle(criterion.rawValue, isOn: Binding(
                        get: { selectedCriteria.contains(criterion) },
                        set: { enabled in
                            if enabled { selectedCriteria.insert(criterion) }
                            else { selectedCriteria.remove(criterion) }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(AppFont.caption())
                }
            }

            // Scan button
            HStack {
                Button {
                    runScan()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        if isScanning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Scan (\(selectedCriteria.count) criteria)")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(selectedCriteria.isEmpty || isScanning)
                .help("Run the scan against all tracked symbols using the selected criteria")

                if !selectedCriteria.isEmpty {
                    Button("Clear") {
                        selectedCriteria.removeAll()
                        scanResults.removeAll()
                    }
                    .controlSize(.small)
                    .help("Remove all selected criteria and clear results")
                }

                Spacer()

                Text("\(scanResults.count) matches")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
            }

            // Results
            if scanResults.isEmpty && !selectedCriteria.isEmpty && !isScanning {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Matches",
                    message: "No symbols matched your criteria. Try fewer conditions.",
                    actionTitle: "Clear Criteria"
                ) {
                    selectedCriteria.removeAll()
                }
                .frame(height: 200)
            } else {
                ForEach(scanResults) { result in
                    Button {
                        appState.selectedChartSymbol = result.symbol
                        appState.selectedPage = .chart
                    } label: {
                        CardView(padding: Spacing.sm) {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    HStack(spacing: Spacing.xs) {
                                        Text(result.symbol)
                                            .font(AppFont.symbol())
                                        Text(FormatHelper.price(result.lastPrice))
                                            .font(AppFont.monoSmall())
                                            .foregroundStyle(Color.textSecondary)
                                        ChangeBadge(changePct: result.changePct)
                                    }

                                    HStack(spacing: Spacing.xxs) {
                                        ForEach(result.matchedCriteria) { criterion in
                                            TagPill(text: criterion.rawValue, color: .accentColor, style: .subtle)
                                        }
                                    }
                                }
                                Spacer()
                                Text("\(result.matchedCriteria.count)/\(selectedCriteria.count)")
                                    .font(AppFont.mono())
                                    .foregroundStyle(Color.textTertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func runScan() {
        isScanning = true

        // Gather bar data
        var barData: [String: [DailyBar]] = [:]
        for quote in appState.quotes {
            if let bars = try? appState.dailyBarRepo.forSymbol(quote.symbol, limit: 250) {
                barData[quote.symbol] = bars
            }
        }

        scanResults = TechnicalScreener.scan(
            quotes: appState.quotes,
            barData: barData,
            criteria: selectedCriteria
        )

        isScanning = false
    }
}
