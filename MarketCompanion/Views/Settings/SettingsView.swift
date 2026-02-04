// SettingsView.swift
// MarketCompanion

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                PageHeader(title: "Settings", subtitle: "Configuration & preferences")

                // Appearance
                AppearanceSettingsView(appearanceManager: appState.appearanceManager)

                // Data Provider summary
                dataProviderSummarySection

                // Reports
                reportPreferencesSection

                // Scheduling
                schedulingSection

                // Audio
                audioSection

                // Database
                databaseSection

                // Danger Zone
                dangerZoneSection
            }
            .padding(Spacing.lg)
        }
        .alert("Delete All Data", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                appState.deleteAllData()
            }
        } message: {
            Text("This will permanently delete all holdings, watchlist items, trades, reports, alerts, and API keys. This cannot be undone.")
        }
    }

    // MARK: - Data Provider Summary

    private var dataProviderSummarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Data Provider", icon: "antenna.radiowaves.left.and.right")

            CardView {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(appState.isUsingDemoData ? Color.warningAmber : Color.gainGreen)
                                .frame(width: 8, height: 8)
                            Text(appState.isUsingDemoData ? "Demo Mode" : appState.dataProvider.displayName)
                                .font(AppFont.subheadline())
                        }
                        Text("Configure API keys and providers in the Providers page.")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                    }
                    Spacer()
                    Button("Open Providers") {
                        appState.selectedPage = .dataProviders
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Report Preferences

    private var reportPreferencesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Report Preferences", icon: "doc.text")

            CardView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Text("Default Report Mode")
                            .font(AppFont.subheadline())
                        Spacer()
                        Picker("", selection: $appState.reportMode) {
                            ForEach(ReportMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 180)
                        .help("Concise shows top 3 items per section. Detailed includes rotation analysis and key levels.")
                    }

                    SubtleDivider()

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                        Text("Concise mode shows top 3 items per section and skips rotation analysis and key levels.")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Scheduling

    private var schedulingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Report Schedule", icon: "clock.badge")

            CardView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Toggle("Morning Report", isOn: $appState.scheduler.isMorningScheduled)
                            .font(AppFont.subheadline())
                            .help("Auto-generate a morning briefing at the scheduled time on weekdays")
                        Spacer()
                        DatePicker("", selection: $appState.scheduler.morningTime, displayedComponents: .hourAndMinute)
                            .frame(width: 100)
                            .disabled(!appState.scheduler.isMorningScheduled)
                            .help("Time to auto-generate the morning report (weekdays only)")
                    }

                    HStack {
                        Toggle("Close Report", isOn: $appState.scheduler.isCloseScheduled)
                            .font(AppFont.subheadline())
                            .help("Auto-generate a close summary at the scheduled time on weekdays")
                        Spacer()
                        DatePicker("", selection: $appState.scheduler.closeTime, displayedComponents: .hourAndMinute)
                            .frame(width: 100)
                            .disabled(!appState.scheduler.isCloseScheduled)
                            .help("Time to auto-generate the close report (weekdays only)")
                    }

                    SubtleDivider()

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                        Text("Reports auto-generate when the app is running on weekdays.")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                    }

                    if let lastRun = appState.scheduler.lastScheduledRun {
                        Text("Last scheduled run: \(FormatHelper.fullDate(lastRun))")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                    }

                    SubtleDivider()

                    // LaunchAgent
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Background Scheduling")
                            .font(AppFont.subheadline())
                        Text("Install a macOS LaunchAgent to open the app at scheduled times, even when it's closed.")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                    }

                    HStack {
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(appState.scheduler.isLaunchAgentInstalled ? Color.gainGreen : Color.textTertiary)
                                .frame(width: 8, height: 8)
                            Text(appState.scheduler.isLaunchAgentInstalled ? "LaunchAgent active" : "Not installed")
                                .font(AppFont.caption())
                                .foregroundStyle(Color.textSecondary)
                        }

                        Spacer()

                        if appState.scheduler.isLaunchAgentInstalled {
                            Button("Uninstall") {
                                try? appState.scheduler.uninstallLaunchAgent()
                            }
                            .controlSize(.small)
                            .foregroundStyle(Color.lossRed)
                            .help("Remove the LaunchAgent so macOS no longer opens the app on a schedule")
                        } else {
                            Button("Install LaunchAgent") {
                                try? appState.scheduler.installLaunchAgent()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Install a macOS LaunchAgent to open the app at report times, even when it's closed")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Audio

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Audio Briefing", icon: "speaker.wave.2.fill")

            CardView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Text("Speech Rate")
                            .font(AppFont.subheadline())
                        Spacer()
                        Text(speedLabel)
                            .font(AppFont.monoSmall())
                            .foregroundStyle(Color.textSecondary)
                    }

                    Slider(value: $appState.audioBriefing.speechRateSlider, in: 0.0...1.0, step: 0.1)
                        .help("Adjust text-to-speech speed: Slow (left) to Very Fast (right)")

                    SubtleDivider()

                    HStack(spacing: Spacing.xs) {
                        Button {
                            appState.audioBriefing.toggle("This is a sample of the Market Companion audio briefing. Your morning and close reports will be read aloud at this speed.")
                        } label: {
                            Label(
                                appState.audioBriefing.isSpeaking ? "Stop Preview" : "Preview Voice",
                                systemImage: appState.audioBriefing.isSpeaking ? "stop.fill" : "play.fill"
                            )
                            .font(AppFont.subheadline())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Listen to a sample of the audio briefing at the current speed")
                    }
                }
            }
        }
    }

    private var speedLabel: String {
        let rate = appState.audioBriefing.speechRateSlider
        if rate < 0.3 { return "Slow" }
        if rate < 0.6 { return "Normal" }
        if rate < 0.8 { return "Fast" }
        return "Very Fast"
    }

    // MARK: - Database

    private var databaseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Storage", icon: "internaldrive")

            CardView {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("Database Location")
                            .font(AppFont.subheadline())
                        Spacer()
                        Button("Reveal") {
                            let path = appState.db.databasePath
                            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                        }
                        .controlSize(.small)
                        .help("Open the database file location in Finder")
                    }

                    Text(appState.db.databasePath)
                        .font(AppFont.monoSmall())
                        .foregroundStyle(Color.textTertiary)
                        .textSelection(.enabled)

                    SubtleDivider()

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Holdings: \(appState.holdings.count)")
                            Text("Watch Items: \(appState.watchItems.count)")
                            Text("Trades: \(appState.trades.count)")
                        }
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)

                        Spacer()

                        VStack(alignment: .leading) {
                            Text("Reports: \(appState.reports.count)")
                            Text("Alert Rules: \(appState.alertRules.count)")
                            Text("Alert Events: \(appState.alertEvents.count)")
                        }
                        .font(AppFont.caption())
                        .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Danger Zone", icon: "exclamationmark.triangle.fill")

            CardView {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete All Data")
                            .font(AppFont.subheadline())
                            .foregroundStyle(Color.lossRed)
                        Text("Remove all holdings, trades, reports, alerts, and API keys.")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textSecondary)
                    }

                    Spacer()

                    Button("Delete Everything") {
                        showDeleteConfirm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                    .help("Permanently delete all holdings, trades, reports, alerts, and API keys")
                }
            }
        }
    }

}
