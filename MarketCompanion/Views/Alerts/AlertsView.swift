// AlertsView.swift
// MarketCompanion

import SwiftUI

struct AlertsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreateRule = false
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .top) {
                    PageHeader(title: "Alerts", subtitle: "Smart monitoring beyond price")
                    Spacer()
                    Button {
                        Task { await appState.triggerAlertCheck() }
                    } label: {
                        Label("Check Now", systemImage: "bolt.fill")
                            .font(AppFont.subheadline())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Trigger an immediate alert check against all rules")
                }

                // Engine status
                if let lastCheck = appState.alertEngine.lastCheckTime {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(Color.gainGreen)
                            .frame(width: 6, height: 6)
                        Text("Engine active \u{2022} Last check: \(FormatHelper.relativeDate(lastCheck))")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Picker("View", selection: $selectedTab) {
                    Text("Events (\(appState.alertEvents.count))").tag(0)
                    Text("Rules (\(appState.alertRules.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                .help("Events shows triggered alerts. Rules shows your monitoring conditions.")

                if selectedTab == 0 {
                    eventsTab
                } else {
                    rulesTab
                }
            }
            .padding(Spacing.lg)
        }
        .sheet(isPresented: $showCreateRule) {
            CreateAlertRuleSheet()
                .environmentObject(appState)
        }
    }

    // MARK: - Events

    private var eventsTab: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if appState.alertEvents.isEmpty {
                EmptyStateView(
                    icon: "bell.slash",
                    title: "No Alert Events",
                    message: "When your alert rules trigger, events will appear here.",
                    actionTitle: "Create Rule"
                ) {
                    showCreateRule = true
                }
                .frame(height: 300)
            } else {
                ForEach(appState.alertEvents) { event in
                    alertEventRow(event)
                }
            }
        }
    }

    private func alertEventRow(_ event: AlertEvent) -> some View {
        CardView(padding: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.warningAmber)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.summary)
                        .font(AppFont.subheadline())
                        .foregroundStyle(Color.textPrimary)

                    if !event.details.isEmpty {
                        Text(event.details)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(2)
                    }

                    Text(FormatHelper.fullDate(event.triggeredAt))
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Rules

    private var rulesTab: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Active Rules", icon: "bell.badge") {
                Button {
                    showCreateRule = true
                } label: {
                    Label("New Rule", systemImage: "plus")
                        .font(AppFont.subheadline())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Create a new alert rule for volume, volatility, or technical conditions")
            }

            if appState.alertRules.isEmpty {
                EmptyStateView(
                    icon: "bell.badge",
                    title: "No Alert Rules",
                    message: "Create rules for volume spikes, trend breaks, and unusual volatility.",
                    actionTitle: "Create First Rule"
                ) {
                    showCreateRule = true
                }
                .frame(height: 300)
            } else {
                ForEach(appState.alertRules) { rule in
                    alertRuleRow(rule)
                }
            }
        }
    }

    private func alertRuleRow(_ rule: AlertRule) -> some View {
        CardView(padding: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: rule.enabled ? "bell.fill" : "bell.slash")
                    .foregroundStyle(rule.enabled ? Color.accentColor : Color.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.displayName)
                        .font(AppFont.subheadline())
                    Text("Threshold: \(String(format: "%.1fx", rule.thresholdValue))")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Toggle("", isOn: .init(
                    get: { rule.enabled },
                    set: { _ in
                        if let id = rule.id {
                            do {
                                try appState.alertRuleRepo.toggleEnabled(id: id)
                                appState.loadFromDatabase()
                            } catch {}
                        }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Enable or disable this alert rule")

                Button {
                    if let id = rule.id {
                        appState.deleteAlertRule(id: id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.lossRed)
                }
                .buttonStyle(.plain)
                .help("Permanently delete this alert rule")
            }
        }
    }
}

// MARK: - Create Alert Rule Sheet

struct CreateAlertRuleSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var symbol = ""
    @State private var ruleType: AlertRuleType = .volumeSpike
    @State private var threshold = "2.0"
    @State private var compositeConditions: [CompositeAlertCondition] = [
        CompositeAlertCondition(indicator: .rsi, comparison: .below, value: 30),
        CompositeAlertCondition(indicator: .volume, comparison: .above, value: 2.0)
    ]

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Create Alert Rule")
                .font(AppFont.title())

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    TextField("Symbol (leave empty for market-wide)", text: $symbol)
                        .textFieldStyle(.roundedBorder)
                        .help("Leave empty to monitor all symbols, or enter a specific ticker")

                    Picker("Alert Type", selection: $ruleType) {
                        ForEach(AlertRuleType.allCases, id: \.self) { type in
                            Text(alertTypeLabel(type)).tag(type)
                        }
                    }

                    if ruleType == .composite {
                        compositeBuilder
                    } else {
                        HStack {
                            Text("Threshold:")
                                .font(AppFont.body())
                            TextField("2.0", text: $threshold)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .help("The trigger threshold — meaning depends on alert type")
                            Text("x")
                                .font(AppFont.body())
                                .foregroundStyle(Color.textSecondary)
                        }
                    }

                    Text(thresholdDescription)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textTertiary)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    createRule()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(ruleType == .composite && compositeConditions.count < 2)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 450, height: 480)
    }

    // MARK: - Composite Builder

    private var compositeBuilder: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Conditions (all must be true)")
                .font(AppFont.subheadline())
                .foregroundStyle(Color.textSecondary)

            ForEach(compositeConditions.indices, id: \.self) { i in
                HStack(spacing: Spacing.xs) {
                    Picker("", selection: $compositeConditions[i].indicator) {
                        ForEach(CompositeAlertCondition.CompositeIndicator.allCases, id: \.self) { ind in
                            Text(ind.rawValue).tag(ind)
                        }
                    }
                    .frame(width: 110)

                    Picker("", selection: $compositeConditions[i].comparison) {
                        ForEach(CompositeAlertCondition.CompositeComparison.allCases, id: \.self) { cmp in
                            Text(cmp.rawValue).tag(cmp)
                        }
                    }
                    .frame(width: 80)

                    TextField("Value", value: $compositeConditions[i].value, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)

                    if compositeConditions.count > 2 {
                        Button {
                            compositeConditions.remove(at: i)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(Color.lossRed)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if compositeConditions.count < 5 {
                Button {
                    compositeConditions.append(CompositeAlertCondition(indicator: .price, comparison: .above, value: 0))
                } label: {
                    Label("Add Condition", systemImage: "plus.circle")
                        .font(AppFont.caption())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func createRule() {
        let sym = symbol.trimmingCharacters(in: .whitespaces).uppercased()

        if ruleType == .composite {
            let json = (try? String(data: JSONEncoder().encode(compositeConditions), encoding: .utf8)) ?? "[]"
            var rule = AlertRule(
                symbol: sym.isEmpty ? nil : sym,
                type: .composite,
                compositeConditions: json
            )
            do {
                try appState.alertRuleRepo.save(&rule)
                appState.loadFromDatabase()
            } catch {}
        } else {
            appState.addAlertRule(
                symbol: sym.isEmpty ? nil : sym,
                sector: nil,
                type: ruleType,
                threshold: Double(threshold) ?? 2.0
            )
        }
        dismiss()
    }

    private func alertTypeLabel(_ type: AlertRuleType) -> String {
        switch type {
        case .volumeSpike: return "Volume Spike"
        case .trendBreak: return "Trend Break"
        case .unusualVolatility: return "Unusual Volatility"
        case .rsiOverbought: return "RSI Overbought"
        case .rsiOversold: return "RSI Oversold"
        case .macdCrossover: return "MACD Crossover"
        case .bollingerSqueeze: return "Bollinger Squeeze"
        case .priceAboveMA: return "Price Above MA"
        case .priceBelowMA: return "Price Below MA"
        case .bullishEngulfing: return "Bullish Engulfing"
        case .bearishEngulfing: return "Bearish Engulfing"
        case .hammer: return "Hammer"
        case .doji: return "Doji"
        case .composite: return "Composite (Multi-Condition)"
        }
    }

    private var thresholdDescription: String {
        switch ruleType {
        case .volumeSpike:
            return "Alert when volume exceeds \(threshold)x the average daily volume."
        case .trendBreak:
            return "Alert when price crosses a moving average or key level."
        case .unusualVolatility:
            return "Alert when intraday range exceeds \(threshold)x the typical range."
        case .rsiOverbought:
            return "Alert when RSI(14) rises above \(threshold) (default 70)."
        case .rsiOversold:
            return "Alert when RSI(14) falls below \(threshold) (default 30)."
        case .macdCrossover:
            return "Alert when MACD histogram crosses the zero line."
        case .bollingerSqueeze:
            return "Alert when Bollinger bandwidth falls to \(threshold)x of average (squeeze)."
        case .priceAboveMA:
            return "Alert when price crosses above the \(Int(Double(threshold) ?? 20))-period SMA."
        case .priceBelowMA:
            return "Alert when price crosses below the \(Int(Double(threshold) ?? 20))-period SMA."
        case .bullishEngulfing:
            return "Alert when a bullish engulfing candlestick pattern is detected."
        case .bearishEngulfing:
            return "Alert when a bearish engulfing candlestick pattern is detected."
        case .hammer:
            return "Alert when a hammer candlestick pattern is detected."
        case .doji:
            return "Alert when a doji candlestick pattern is detected."
        case .composite:
            return "Alert when all specified conditions are met simultaneously."
        }
    }
}
