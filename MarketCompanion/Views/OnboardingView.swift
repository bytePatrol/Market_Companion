// OnboardingView.swift
// MarketCompanion
//
// First-launch onboarding: Welcome → Add Symbols → Preferences.

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step = 0
    @State private var symbolsText = "AAPL, MSFT, NVDA, TSLA, AMZN"
    @State private var enableScheduledReports = true
    @State private var enableAlertNotifications = true

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: Spacing.xs) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.accentColor : Color.textTertiary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: step)
                }
            }
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.md)

            // Step content
            Group {
                switch step {
                case 0:
                    welcomeStep
                case 1:
                    symbolsStep
                case 2:
                    preferencesStep
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.3), value: step)

            // Navigation
            HStack {
                if step > 0 {
                    Button("Back") {
                        step -= 1
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                Spacer()

                if step < 2 {
                    Button("Next") {
                        step += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(Spacing.lg)
        }
        .frame(width: 480, height: 420)
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, options: .repeating.speed(0.3))

            VStack(spacing: Spacing.xs) {
                Text("Market Companion")
                    .font(AppFont.largeTitle())
                    .foregroundStyle(Color.textPrimary)

                Text("Intelligence for your trading day")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                featureRow(icon: "doc.text.fill", text: "Automated morning & close reports")
                featureRow(icon: "bell.badge.fill", text: "Smart alerts for volume & volatility")
                featureRow(icon: "book.fill", text: "Trade journal with market context")
                featureRow(icon: "rectangle.split.2x1", text: "Companion window for ThinkorSwim")
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            Text(text)
                .font(AppFont.subheadline())
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Symbols

    private var symbolsStep: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "briefcase.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: Spacing.xs) {
                Text("Add Your Symbols")
                    .font(AppFont.title())
                    .foregroundStyle(Color.textPrimary)

                Text("Enter the tickers you trade or watch.\nThese become your holdings for reports and alerts.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Symbols (comma-separated)")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)

                TextEditor(text: $symbolsText)
                    .font(AppFont.mono())
                    .frame(height: 60)
                    .padding(Spacing.xs)
                    .background {
                        RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                            .fill(Color.surfaceElevated)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                            .strokeBorder(Color.borderSubtle.opacity(0.5), lineWidth: 0.5)
                            .allowsHitTesting(false)
                    }

                Text("\(parsedSymbols.count) symbols")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()
        }
    }

    private var parsedSymbols: [String] {
        symbolsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }

    // MARK: - Preferences

    private var preferencesStep: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "gearshape.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: Spacing.xs) {
                Text("Preferences")
                    .font(AppFont.title())
                    .foregroundStyle(Color.textPrimary)

                Text("Configure how Market Companion works for you.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                Toggle(isOn: $enableScheduledReports) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scheduled Reports")
                            .font(AppFont.subheadline())
                            .foregroundStyle(Color.textPrimary)
                        Text("Auto-generate morning (6:30 AM) and close (1:00 PM) reports")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .help("When enabled, reports auto-generate at 6:30 AM and 1:00 PM PT on weekdays")

                Toggle(isOn: $enableAlertNotifications) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alert Notifications")
                            .font(AppFont.subheadline())
                            .foregroundStyle(Color.textPrimary)
                        Text("Get notified about volume spikes, trend breaks, and volatility")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .help("When enabled, the alert engine monitors for volume spikes, trend breaks, and volatility")
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Complete

    private func completeOnboarding() {
        // Add symbols as holdings
        for symbol in parsedSymbols {
            Task {
                await appState.addHolding(symbol: symbol)
            }
        }

        // Configure preferences
        appState.scheduler.isMorningScheduled = enableScheduledReports
        appState.scheduler.isCloseScheduled = enableScheduledReports

        // Mark complete
        appState.completeOnboarding()
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .environmentObject(AppState())
}
