// EmptyStateView.swift
// MarketCompanion

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.textTertiary)
                .symbolEffect(.pulse, options: .repeating.speed(0.3))

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(AppFont.title())
                    .foregroundStyle(Color.textPrimary)

                Text(message)
                    .font(AppFont.body())
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                        Text(actionTitle)
                    }
                    .font(AppFont.headline())
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background {
                        RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                            .fill(Color.accentColor)
                    }
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xs)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Demo Banner

struct DemoBanner: View {
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))

            Text("Using demo data")
                .font(AppFont.caption())
                .fontWeight(.medium)

            Spacer()

            Text("Add API key in Settings")
                .font(AppFont.caption())
                .foregroundStyle(Color.textTertiary)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .foregroundStyle(Color.warningAmber)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                    .fill(Color.warningAmber.opacity(0.1))
                RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                    .strokeBorder(Color.warningAmber.opacity(0.3), lineWidth: 0.5)
            }
        }
    }
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "chart.bar.doc.horizontal",
        title: "No Reports Yet",
        message: "Reports are generated automatically at market open and close.",
        actionTitle: "Generate Now"
    ) {
        print("Generate tapped")
    }
}
