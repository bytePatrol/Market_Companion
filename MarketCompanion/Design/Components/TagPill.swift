// TagPill.swift
// MarketCompanion

import SwiftUI

struct TagPill: View {
    let text: String
    var color: Color = .accentColor
    var style: TagStyle = .filled

    enum TagStyle {
        case filled
        case outlined
        case subtle
    }

    var body: some View {
        Text(text)
            .font(AppFont.caption())
            .fontWeight(.medium)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .foregroundStyle(foregroundColor)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                        .fill(backgroundColor)
                    if style == .outlined {
                        RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                            .strokeBorder(color.opacity(0.5), lineWidth: 1)
                    }
                }
            }
    }

    private var foregroundColor: Color {
        switch style {
        case .filled: return .white
        case .outlined: return color
        case .subtle: return color
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .filled: return color
        case .outlined: return .clear
        case .subtle: return color.opacity(0.12)
        }
    }
}

// MARK: - Reason Tag

struct ReasonTag: View {
    let reason: String

    var body: some View {
        TagPill(
            text: reason,
            color: colorForReason(reason),
            style: .subtle
        )
    }

    private func colorForReason(_ reason: String) -> Color {
        switch reason.lowercased() {
        case let r where r.contains("earnings"):
            return .warningAmber
        case let r where r.contains("momentum"):
            return .gainGreen
        case let r where r.contains("volume"), let r where r.contains("unusual"):
            return .lossRed
        case let r where r.contains("sector"):
            return .infoBlue
        case let r where r.contains("breakout"):
            return .gainGreen
        case let r where r.contains("support"), let r where r.contains("level"):
            return .accentColor
        default:
            return .textSecondary
        }
    }
}

// MARK: - Change Badge

struct ChangeBadge: View {
    let changePct: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: changePct >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text(FormatHelper.percent(changePct))
                .font(AppFont.monoSmall())
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 3)
        .foregroundStyle(changePct >= 0 ? Color.gainGreen : Color.lossRed)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                .fill((changePct >= 0 ? Color.gainGreen : Color.lossRed).opacity(0.12))
        }
    }
}

// MARK: - Regime Badge

struct RegimeBadge: View {
    let regime: String

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Circle()
                .fill(regimeColor)
                .frame(width: 6, height: 6)
            Text(regime)
                .font(AppFont.caption())
                .fontWeight(.medium)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background {
            RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                .fill(regimeColor.opacity(0.12))
        }
        .foregroundStyle(regimeColor)
    }

    private var regimeColor: Color {
        switch regime.lowercased() {
        case "risk-on": return .gainGreen
        case "risk-off": return .lossRed
        default: return .warningAmber
        }
    }
}

#Preview("Tags") {
    VStack(spacing: Spacing.md) {
        HStack(spacing: Spacing.xs) {
            TagPill(text: "Technology", color: .infoBlue, style: .filled)
            TagPill(text: "Watchlist", color: .gainGreen, style: .outlined)
            TagPill(text: "Holding", color: .warningAmber, style: .subtle)
        }

        HStack(spacing: Spacing.xs) {
            ReasonTag(reason: "Earnings catalyst")
            ReasonTag(reason: "Sector momentum")
            ReasonTag(reason: "Volume spike")
        }

        HStack(spacing: Spacing.xs) {
            ChangeBadge(changePct: 2.34)
            ChangeBadge(changePct: -1.56)
        }

        HStack(spacing: Spacing.xs) {
            RegimeBadge(regime: "Risk-On")
            RegimeBadge(regime: "Risk-Off")
            RegimeBadge(regime: "Neutral")
        }
    }
    .padding()
}
