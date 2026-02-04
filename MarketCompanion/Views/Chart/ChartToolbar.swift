// ChartToolbar.swift
// MarketCompanion
//
// Symbol input, interval picker, and indicator menu for the chart view.

import SwiftUI

struct ChartToolbar: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: ChartViewModel
    @State private var symbolInput = ""

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Symbol + price
            symbolSection

            Divider().frame(height: 20)

            // Interval picker
            intervalPicker

            Divider().frame(height: 20)

            // Indicators menu
            indicatorsMenu

            Divider().frame(height: 20)

            // Drawing tools
            drawingTools

            Divider().frame(height: 20)

            // Compare button
            compareMenu

            Divider().frame(height: 20)

            // Trade Plan button
            planButton

            Spacer()

            // Export button
            exportButton
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(.bar)
    }

    // MARK: - Symbol Section

    private var symbolSection: some View {
        HStack(spacing: Spacing.xs) {
            TextField("Symbol", text: $symbolInput)
                .textFieldStyle(.plain)
                .font(AppFont.symbol())
                .frame(width: 70)
                .onSubmit {
                    let sym = symbolInput.trimmingCharacters(in: .whitespaces).uppercased()
                    guard !sym.isEmpty else { return }
                    viewModel.symbol = sym
                    appState.selectedChartSymbol = sym
                    Task { await viewModel.loadData() }
                }
                .onAppear {
                    symbolInput = viewModel.symbol
                }
                .onChange(of: viewModel.symbol) {
                    symbolInput = viewModel.symbol
                }
                .help("Type a ticker symbol and press Return to load the chart")

            if let quote = viewModel.latestQuote {
                Text(FormatHelper.price(quote.last))
                    .font(AppFont.price())
                ChangeBadge(changePct: quote.changePct)
            }
        }
    }

    // MARK: - Interval Picker

    private var intervalPicker: some View {
        HStack(spacing: 2) {
            ForEach(CandleInterval.allCases, id: \.self) { interval in
                Button {
                    viewModel.interval = interval
                    viewModel.configuration.interval = interval
                } label: {
                    Text(interval.rawValue)
                        .font(.system(size: 10, weight: viewModel.interval == interval ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(viewModel.interval == interval ? Color.accentColor : Color.textTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background {
                            if viewModel.interval == interval {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentColor.opacity(0.12))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Indicators Menu

    private var indicatorsMenu: some View {
        Menu {
            Section("Overlays") {
                overlayToggle("SMA (20)", overlay: .defaultSMA())
                overlayToggle("EMA (9)", overlay: .defaultEMA())
                overlayToggle("Bollinger Bands", overlay: .defaultBB())
                overlayToggle("VWAP", overlay: .defaultVWAP())
                overlayToggle("Ichimoku Cloud", overlay: .defaultIchimoku())
            }

            Section("Studies") {
                subchartToggle("RSI (14)", indicator: .defaultRSI())
                subchartToggle("MACD", indicator: .defaultMACD())
                subchartToggle("ATR (14)", indicator: .defaultATR())
                subchartToggle("Stochastic", indicator: .defaultStochastic())
                subchartToggle("OBV", indicator: .defaultOBV())
                subchartToggle("ADX", indicator: .defaultADX())
            }

            Section("Volume") {
                Toggle("Volume Bars", isOn: Binding(
                    get: { viewModel.configuration.showVolume },
                    set: { viewModel.configuration.showVolume = $0 }
                ))
                Toggle("Volume Profile", isOn: Binding(
                    get: { viewModel.configuration.showVolumeProfile },
                    set: {
                        viewModel.configuration.showVolumeProfile = $0
                        viewModel.recalculateIndicators()
                    }
                ))
            }
        } label: {
            Label("Indicators", systemImage: "waveform.path.ecg")
                .font(AppFont.subheadline())
        }
        .menuStyle(.borderlessButton)
        .frame(width: 110)
        .help("Add overlays like SMA, EMA, Bollinger Bands and studies like RSI, MACD")
    }

    private func overlayToggle(_ name: String, overlay: OverlayIndicator) -> some View {
        let isActive = viewModel.configuration.overlays.contains(where: { $0.type == overlay.type })

        return Toggle(name, isOn: Binding(
            get: { isActive },
            set: { enabled in
                if enabled {
                    viewModel.configuration.overlays.append(overlay)
                } else {
                    viewModel.configuration.overlays.removeAll(where: { $0.type == overlay.type })
                }
                viewModel.recalculateIndicators()
            }
        ))
    }

    private func subchartToggle(_ name: String, indicator: SubchartIndicator) -> some View {
        let isActive = viewModel.configuration.subchartIndicators.contains(where: { $0.type == indicator.type })

        return Toggle(name, isOn: Binding(
            get: { isActive },
            set: { enabled in
                if enabled {
                    viewModel.configuration.subchartIndicators.append(indicator)
                } else {
                    viewModel.configuration.subchartIndicators.removeAll(where: { $0.type == indicator.type })
                }
                viewModel.recalculateIndicators()
            }
        ))
    }

    // MARK: - Drawing Tools

    private var drawingTools: some View {
        HStack(spacing: 2) {
            drawingButton(mode: .trendLine, icon: "line.diagonal", tooltip: "Trend Line")
            drawingButton(mode: .horizontalLine, icon: "minus", tooltip: "Horizontal Line")
            drawingButton(mode: .fibonacci, icon: "ruler", tooltip: "Fibonacci")
            drawingButton(mode: .textAnnotation, icon: "textformat", tooltip: "Text")

            if !viewModel.drawings.isEmpty {
                Button {
                    viewModel.clearAllDrawings()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.lossRed)
                }
                .buttonStyle(.plain)
                .help("Clear all drawings")
            }
        }
    }

    private func drawingButton(mode: DrawingMode, icon: String, tooltip: String) -> some View {
        let isActive = viewModel.drawingMode == mode

        return Button {
            viewModel.drawingMode = isActive ? .none : mode
        } label: {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(isActive ? Color.accentColor : Color.textTertiary)
                .padding(4)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentColor.opacity(0.12))
                    }
                }
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // MARK: - Compare Menu

    @State private var compareSymbolInput = ""

    private var compareMenu: some View {
        Menu {
            Section("Add Comparison") {
                HStack {
                    TextField("Symbol", text: $compareSymbolInput)
                    Button("Add") {
                        viewModel.addComparison(symbol: compareSymbolInput)
                        compareSymbolInput = ""
                    }
                }
            }

            if !viewModel.comparisonSymbols.isEmpty {
                Section("Active Comparisons") {
                    ForEach(viewModel.comparisonSymbols, id: \.self) { sym in
                        Button {
                            viewModel.removeComparison(symbol: sym)
                        } label: {
                            Label(sym, systemImage: "xmark.circle")
                        }
                    }
                }
            }

            Divider()

            Toggle("Normalize %", isOn: $viewModel.normalizeMode)

            Section("Quick Add") {
                Button("SPY") { viewModel.addComparison(symbol: "SPY") }
                Button("QQQ") { viewModel.addComparison(symbol: "QQQ") }
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11))
                Text("Compare")
                    .font(.system(size: 10))
                if !viewModel.comparisonSymbols.isEmpty {
                    Text("(\(viewModel.comparisonSymbols.count))")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .foregroundStyle(viewModel.comparisonSymbols.isEmpty ? Color.textTertiary : Color.accentColor)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 100)
        .help("Overlay other symbols for relative performance comparison")
    }

    // MARK: - Plan Button

    private var planButton: some View {
        Button {
            viewModel.showTradePlanPanel.toggle()
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "target")
                    .font(.system(size: 11))
                Text("Plan")
                    .font(.system(size: 10))
                if let plan = viewModel.tradePlan {
                    Text(String(format: "%.1fR", plan.rewardToRisk))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(plan.rewardToRisk >= 2 ? Color.gainGreen : Color.warningAmber)
                        )
                }
            }
            .foregroundStyle(viewModel.tradePlan != nil ? Color.accentColor : Color.textTertiary)
        }
        .buttonStyle(.plain)
        .help("Set entry, stop, and target prices to visualize risk/reward on the chart")
        .popover(isPresented: $viewModel.showTradePlanPanel) {
            TradePlanPanel(viewModel: viewModel)
                .frame(width: 280)
        }
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Menu {
            Button {
                ChartExporter.copyToClipboard(viewModel: viewModel)
            } label: {
                Label("Copy to Clipboard", systemImage: "doc.on.doc")
            }
            .keyboardShortcut("C", modifiers: [.command, .shift])

            Button {
                ChartExporter.exportToPNG(viewModel: viewModel)
            } label: {
                Label("Save as PNG...", systemImage: "square.and.arrow.down")
            }
        } label: {
            Image(systemName: "camera")
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 28)
        .help("Copy chart to clipboard or save as PNG")
    }
}
