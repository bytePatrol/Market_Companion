// AppearanceSettingsView.swift
// MarketCompanion
//
// Three-way theme picker, accent color circles, and preview.

import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var appearanceManager: AppearanceManager

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "Appearance", icon: "paintbrush.fill")

            CardView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    // Theme mode
                    HStack {
                        Text("Theme")
                            .font(AppFont.subheadline())
                        Spacer()
                        Picker("", selection: $appearanceManager.themeMode) {
                            ForEach(AppThemeMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        .help("Dark forces dark mode, Light forces light mode, Auto follows your macOS system setting")
                    }

                    SubtleDivider()

                    // Accent color
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Accent Color")
                            .font(AppFont.subheadline())

                        HStack(spacing: Spacing.md) {
                            ForEach(AccentColorChoice.allCases, id: \.self) { choice in
                                Button {
                                    appearanceManager.accentChoice = choice
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(choice.color)
                                            .frame(width: 28, height: 28)

                                        if appearanceManager.accentChoice == choice {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: 2)
                                                .frame(width: 34, height: 34)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(choice.rawValue)
                            }
                        }
                    }

                    SubtleDivider()

                    // Preview
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "eye")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                        Text("Changes apply immediately across the app.")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
    }
}
