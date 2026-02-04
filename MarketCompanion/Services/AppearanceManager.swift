// AppearanceManager.swift
// MarketCompanion
//
// Observable class managing theme mode and accent color preferences.

import SwiftUI

enum AppThemeMode: String, CaseIterable {
    case dark = "Dark"
    case light = "Light"
    case auto = "Auto"
}

enum AccentColorChoice: String, CaseIterable {
    case teal = "Teal"
    case blue = "Blue"
    case green = "Green"
    case purple = "Purple"
    case orange = "Orange"

    var color: Color {
        switch self {
        case .teal: return Color(red: 0.0, green: 0.75, blue: 0.75)
        case .blue: return .blue
        case .green: return Color(red: 0.18, green: 0.80, blue: 0.44)
        case .purple: return .purple
        case .orange: return .orange
        }
    }

    var nsColor: NSColor {
        switch self {
        case .teal: return NSColor(red: 0.0, green: 0.75, blue: 0.75, alpha: 1)
        case .blue: return .systemBlue
        case .green: return NSColor(red: 0.18, green: 0.80, blue: 0.44, alpha: 1)
        case .purple: return .systemPurple
        case .orange: return .systemOrange
        }
    }
}

@MainActor
final class AppearanceManager: ObservableObject {
    @Published var themeMode: AppThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: "appearance_themeMode") }
    }
    @Published var accentChoice: AccentColorChoice {
        didSet {
            UserDefaults.standard.set(accentChoice.rawValue, forKey: "appearance_accentChoice")
            applyAccentColor()
        }
    }

    var resolvedColorScheme: ColorScheme? {
        switch themeMode {
        case .dark: return .dark
        case .light: return .light
        case .auto: return nil
        }
    }

    init() {
        let savedTheme = UserDefaults.standard.string(forKey: "appearance_themeMode") ?? "auto"
        self.themeMode = AppThemeMode(rawValue: savedTheme) ?? .auto

        let savedAccent = UserDefaults.standard.string(forKey: "appearance_accentChoice") ?? "teal"
        self.accentChoice = AccentColorChoice(rawValue: savedAccent) ?? .teal

        applyAccentColor()
    }

    private func applyAccentColor() {
        // Accent color is applied via SwiftUI's .tint() modifier
        // and via the accentChoice property read by views.
        objectWillChange.send()
    }
}
