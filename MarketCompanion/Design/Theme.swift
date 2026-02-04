// Theme.swift
// MarketCompanion
//
// Design system: colors, typography, spacing, and styling constants.

import SwiftUI

// MARK: - Spacing

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

// MARK: - App Colors

extension Color {
    // Brand
    static let accentTeal = Color("AccentTeal", bundle: nil)

    // Semantic
    static let gainGreen = Color(red: 0.18, green: 0.80, blue: 0.44)
    static let lossRed = Color(red: 0.91, green: 0.30, blue: 0.24)
    static let warningAmber = Color(red: 0.95, green: 0.77, blue: 0.06)
    static let infoBlue = Color(red: 0.20, green: 0.60, blue: 1.0)

    // Surfaces
    static let surfacePrimary = Color(nsColor: .windowBackgroundColor)
    static let surfaceSecondary = Color(nsColor: .controlBackgroundColor)
    static let surfaceElevated = Color(nsColor: .underPageBackgroundColor)

    // Text
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    // Borders
    static let borderSubtle = Color(nsColor: .separatorColor)
    static let borderStrong = Color(nsColor: .gridColor)

    // Heatmap gradient
    static func heatmapColor(for changePct: Double) -> Color {
        let clamped = max(-5, min(5, changePct))
        if clamped >= 0 {
            let intensity = clamped / 5.0
            return Color(
                red: 0.18 - 0.10 * intensity,
                green: 0.80 * (0.3 + 0.7 * intensity),
                blue: 0.44 - 0.20 * intensity
            )
        } else {
            let intensity = abs(clamped) / 5.0
            return Color(
                red: 0.91 * (0.3 + 0.7 * intensity),
                green: 0.30 - 0.20 * intensity,
                blue: 0.24 - 0.15 * intensity
            )
        }
    }

    // Change color helper
    static func forChange(_ value: Double) -> Color {
        if value > 0.001 { return .gainGreen }
        if value < -0.001 { return .lossRed }
        return .textSecondary
    }

    // Accent color from choice
    static func accentColor(for choice: AccentColorChoice) -> Color {
        choice.color
    }
}

// MARK: - Typography

enum AppFont {
    static func largeTitle() -> Font { .system(size: 26, weight: .bold, design: .default) }
    static func title() -> Font { .system(size: 20, weight: .semibold, design: .default) }
    static func headline() -> Font { .system(size: 15, weight: .semibold, design: .default) }
    static func subheadline() -> Font { .system(size: 13, weight: .medium, design: .default) }
    static func body() -> Font { .system(size: 13, weight: .regular, design: .default) }
    static func caption() -> Font { .system(size: 11, weight: .regular, design: .default) }
    static func mono() -> Font { .system(size: 13, weight: .medium, design: .monospaced) }
    static func monoSmall() -> Font { .system(size: 11, weight: .regular, design: .monospaced) }
    static func symbol() -> Font { .system(size: 14, weight: .bold, design: .rounded) }
    static func price() -> Font { .system(size: 15, weight: .semibold, design: .monospaced) }
    static func bigNumber() -> Font { .system(size: 32, weight: .bold, design: .rounded) }
}

// MARK: - Corner Radius

enum CornerRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 20
}

// MARK: - Shadow

extension View {
    func cardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    func subtleShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Format Helpers

enum FormatHelper {
    static func percent(_ value: Double, signed: Bool = true) -> String {
        let sign = signed && value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", value))%"
    }

    static func price(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "$%.2f", value)
        } else if value >= 1 {
            return String(format: "$%.2f", value)
        } else {
            return String(format: "$%.4f", value)
        }
    }

    static func volume(_ value: Int64) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.1fB", Double(value) / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    static func timeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    static func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func pnl(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)$\(String(format: "%.2f", abs(value)))"
    }
}
