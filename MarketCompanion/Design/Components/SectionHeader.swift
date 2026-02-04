// SectionHeader.swift
// MarketCompanion

import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                Text(title)
                    .font(AppFont.headline())
                    .foregroundStyle(Color.textPrimary)
            }

            if let subtitle {
                Text(subtitle)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
            }

            Spacer()

            if let trailing {
                trailing
            }
        }
        .padding(.bottom, Spacing.xxs)
    }
}

// MARK: - Convenience Initializer

extension SectionHeader {
    init(title: String, subtitle: String? = nil, icon: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.trailing = nil
    }

    init<Trailing: View>(title: String, subtitle: String? = nil, icon: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.trailing = AnyView(trailing())
    }
}

// MARK: - Page Header

struct PageHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(AppFont.largeTitle())
                .foregroundStyle(Color.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(AppFont.subheadline())
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
}

// MARK: - Divider

struct SubtleDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.borderSubtle.opacity(0.5))
            .frame(height: 0.5)
    }
}

#Preview("Headers") {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        PageHeader(title: "Dashboard", subtitle: "Monday, January 6")

        SectionHeader(
            title: "Holdings in Play",
            subtitle: "3 flagged",
            icon: "flame.fill"
        )

        SubtleDivider()

        SectionHeader(title: "Sector Heat", icon: "square.grid.3x3.fill") {
            Button("View All") {}
                .font(AppFont.caption())
        }
    }
    .padding()
    .frame(width: 400)
}
