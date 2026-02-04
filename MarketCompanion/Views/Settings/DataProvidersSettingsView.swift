// DataProvidersSettingsView.swift
// MarketCompanion
//
// Per-provider configuration: connect, disconnect, test, set primary/fallback.

import SwiftUI

struct DataProvidersSettingsView: View {
    @EnvironmentObject var appState: AppState

    @State private var healthResults: [ProviderID: ProviderHealth] = [:]
    @State private var isTesting = false
    @State private var expandedProvider: ProviderID? = nil

    private let registry = ProviderRegistry.shared
    private let keychain = KeychainService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                PageHeader(title: "Data Providers", subtitle: "Connect and configure market data sources")

                dataModeSection
                providerSelectionSection
                providerListSection
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - Data Mode

    private var dataModeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Data Mode", icon: "antenna.radiowaves.left.and.right")

            CardView {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Source")
                            .font(AppFont.subheadline())
                        Text(appState.isUsingDemoData
                             ? "Using generated demo data. No API keys needed."
                             : "Fetching live market data from \(appState.providerRouter.displayName).")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Picker("", selection: $appState.dataMode) {
                        Text("Demo").tag(DataMode.demo)
                        Text("Live").tag(DataMode.live)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                    .onChange(of: appState.dataMode) { _, newValue in
                        appState.setDataMode(newValue)
                    }
                    .help("Demo uses generated sample data. Live fetches real market data from your API provider.")
                }
            }
        }
    }

    // MARK: - Provider Selection

    private var providerSelectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Provider Selection", icon: "arrow.triangle.branch")

            CardView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Text("Primary")
                            .font(AppFont.subheadline())
                        Spacer()
                        Picker("", selection: Binding(
                            get: { appState.providerRouter.primaryProviderID },
                            set: { appState.setPrimaryProvider($0) }
                        )) {
                            ForEach(liveProviderIDs, id: \.self) { id in
                                HStack {
                                    Text(id.displayName)
                                    if keychain.hasProviderCredentials(providerID: id) {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                                .tag(id)
                            }
                        }
                        .frame(width: 160)
                        .help("The main data source used for all market data requests")
                    }

                    SubtleDivider()

                    HStack {
                        Text("Fallback")
                            .font(AppFont.subheadline())
                        Spacer()
                        Picker("", selection: Binding(
                            get: { appState.providerRouter.fallbackProviderID ?? .mock },
                            set: { appState.setFallbackProvider($0 == .mock ? nil : $0) }
                        )) {
                            Text("None (Mock)").tag(ProviderID.mock)
                            ForEach(liveProviderIDs, id: \.self) { id in
                                Text(id.displayName).tag(id)
                            }
                        }
                        .frame(width: 160)
                        .help("If the primary provider fails, requests automatically fall to this provider, then to demo data")
                    }

                    SubtleDivider()

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                        Text("If the primary provider fails, requests fall back to the secondary, then to demo data.")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Provider List

    private var providerListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                SectionHeader(title: "Providers", icon: "server.rack")
                Spacer()
                Button {
                    Task { await testAllProviders() }
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Test All")
                    }
                }
                .controlSize(.small)
                .disabled(isTesting)
                .help("Run a health check on all configured providers")
            }

            ForEach(liveProviderIDs, id: \.self) { id in
                providerCard(for: id)
            }
        }
    }

    private func providerCard(for id: ProviderID) -> some View {
        let hasKey = keychain.hasProviderCredentials(providerID: id)
        let health = healthResults[id]
        let isExpanded = expandedProvider == id

        return CardView {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedProvider = isExpanded ? nil : id
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: Spacing.xs) {
                                Text(id.displayName)
                                    .font(AppFont.subheadline())
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.textPrimary)
                                statusChip(hasKey: hasKey, health: health)
                            }
                            capabilitySummary(for: id)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Expanded detail
                if isExpanded {
                    SubtleDivider()
                        .padding(.vertical, Spacing.sm)

                    ProviderDetailView(
                        providerID: id,
                        health: health,
                        onTest: { await testProvider(id) },
                        onDisconnect: { disconnectProvider(id) }
                    )
                    .environmentObject(appState)
                }
            }
        }
    }

    // MARK: - Status Chip

    private func statusChip(hasKey: Bool, health: ProviderHealth?) -> some View {
        let (text, color): (String, Color) = {
            if let h = health {
                switch h.status {
                case .healthy: return ("Connected", .gainGreen)
                case .degraded: return ("Degraded", .warningAmber)
                case .rateLimited: return ("Rate Limited", .warningAmber)
                case .noCredentials: return ("No Key", .textTertiary)
                case .unavailable, .error: return ("Error", .lossRed)
                }
            }
            return hasKey ? ("Key Set", .infoBlue) : ("Not Connected", .textTertiary)
        }()

        return Text(text)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func capabilitySummary(for id: ProviderID) -> some View {
        guard let provider = registry.provider(for: id) else {
            return Text("").font(AppFont.caption())
        }
        let caps = provider.capabilities
        var items: [String] = []
        if caps.supportsRealtimeQuotes { items.append("Quotes") }
        if caps.supportsDailyBars { items.append("Daily") }
        if caps.supportsIntradayBars { items.append("Intraday") }
        if caps.supportsCompanyNews { items.append("News") }
        if caps.supportsEarningsCalendar { items.append("Calendar") }
        if caps.supportsOptionsData { items.append("Options") }

        return Text(items.joined(separator: " \u{2022} "))
            .font(AppFont.caption())
            .foregroundStyle(Color.textTertiary)
    }

    // MARK: - Helpers

    private var liveProviderIDs: [ProviderID] {
        ProviderID.allCases.filter { $0 != .mock }
    }

    private func testAllProviders() async {
        isTesting = true
        let results = await appState.providerRouter.runDiagnostics()
        for (id, health) in results {
            healthResults[id] = health
        }
        isTesting = false
    }

    private func testProvider(_ id: ProviderID) async {
        guard let provider = registry.provider(for: id) else { return }
        do {
            let health = try await provider.healthCheck()
            healthResults[id] = health
        } catch {
            healthResults[id] = .error(error.localizedDescription)
        }
    }

    private func disconnectProvider(_ id: ProviderID) {
        try? keychain.deleteAllProviderSecrets(providerID: id)
        healthResults[id] = nil
        if appState.providerRouter.primaryProviderID == id {
            appState.setPrimaryProvider(.mock)
            appState.setDataMode(.demo)
        }
    }
}

// MARK: - Provider Detail View

private struct ProviderDetailView: View {
    @EnvironmentObject var appState: AppState
    let providerID: ProviderID
    let health: ProviderHealth?
    let onTest: () async -> Void
    let onDisconnect: () -> Void

    @State private var apiKeyInput = ""
    @State private var secretInput = ""
    @State private var baseURLInput = ""
    @State private var isTesting = false
    @State private var statusMessage = ""

    private let keychain = KeychainService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // API Key
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("API Key")
                    .font(AppFont.subheadline())
                HStack(spacing: Spacing.sm) {
                    SecureField("Enter API key", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .help("API keys are stored securely in the macOS Keychain")
                    Button("Save") {
                        saveAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    .help("Save this API key to the macOS Keychain")
                }
            }

            // Secret (for providers that need it)
            if needsSecret {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("API Secret")
                        .font(AppFont.subheadline())
                    HStack(spacing: Spacing.sm) {
                        SecureField("Enter API secret", text: $secretInput)
                            .textFieldStyle(.roundedBorder)
                        Button("Save") {
                            saveSecret()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(secretInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }

            // Base URL (for providers that support it)
            if needsBaseURL {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Base URL")
                        .font(AppFont.subheadline())
                    HStack(spacing: Spacing.sm) {
                        TextField("https://api.example.com", text: $baseURLInput)
                            .textFieldStyle(.roundedBorder)
                        Button("Save") {
                            saveBaseURL()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            SubtleDivider()

            // Capabilities
            capabilitiesGrid

            SubtleDivider()

            // Actions
            HStack {
                Button {
                    isTesting = true
                    Task {
                        await onTest()
                        isTesting = false
                    }
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Test Connection")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isTesting || !keychain.hasProviderCredentials(providerID: providerID))
                .help("Send a test request to verify your API key and check latency")

                if let h = health {
                    healthBadge(h)
                }

                Spacer()

                if keychain.hasProviderCredentials(providerID: providerID) {
                    Button("Disconnect") {
                        onDisconnect()
                        apiKeyInput = ""
                        secretInput = ""
                    }
                    .controlSize(.small)
                    .foregroundStyle(Color.lossRed)
                    .help("Remove the API key from Keychain and disconnect this provider")
                }
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    // MARK: - Capabilities Grid

    private var capabilitiesGrid: some View {
        let provider = ProviderRegistry.shared.provider(for: providerID)
        let caps = provider?.capabilities ?? .none

        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Capabilities")
                .font(AppFont.subheadline())
                .foregroundStyle(Color.textSecondary)

            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading),
            ], spacing: Spacing.xxs) {
                capRow("Quotes", on: caps.supportsRealtimeQuotes)
                capRow("Daily Bars", on: caps.supportsDailyBars)
                capRow("Intraday", on: caps.supportsIntradayBars)
                capRow("News", on: caps.supportsCompanyNews)
                capRow("Calendar", on: caps.supportsEarningsCalendar)
                capRow("Options", on: caps.supportsOptionsData)
                capRow("WebSocket", on: caps.supportsWebSocketStreaming)
            }
        }
    }

    private func capRow(_ label: String, on: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 10))
                .foregroundStyle(on ? Color.gainGreen : Color.textTertiary)
            Text(label)
                .font(AppFont.caption())
                .foregroundStyle(on ? Color.textPrimary : Color.textTertiary)
        }
    }

    private func healthBadge(_ h: ProviderHealth) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(h.status == .healthy ? Color.gainGreen : (h.status == .error || h.status == .unavailable ? Color.lossRed : Color.warningAmber))
                .frame(width: 6, height: 6)
            if let ms = h.latencyMs {
                Text("\(ms)ms")
                    .font(AppFont.monoSmall())
                    .foregroundStyle(Color.textSecondary)
            } else if let msg = h.message {
                Text(msg)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Provider-Specific Config

    private var needsSecret: Bool {
        providerID == .alpaca
    }

    private var needsBaseURL: Bool {
        providerID == .massive || providerID == .thetaData
    }

    // MARK: - Actions

    private func saveAPIKey() {
        do {
            try keychain.saveProviderSecret(providerID: providerID, key: "api_key", value: apiKeyInput)
            apiKeyInput = ""
            statusMessage = "API key saved to Keychain."
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }
    }

    private func saveSecret() {
        do {
            try keychain.saveProviderSecret(providerID: providerID, key: "api_secret", value: secretInput)
            secretInput = ""
            statusMessage = "API secret saved."
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }
    }

    private func saveBaseURL() {
        do {
            try keychain.saveProviderSecret(providerID: providerID, key: "base_url", value: baseURLInput)
            baseURLInput = ""
            statusMessage = "Base URL saved."
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }
    }
}
