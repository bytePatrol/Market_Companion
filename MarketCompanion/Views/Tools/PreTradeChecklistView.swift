// PreTradeChecklistView.swift
// MarketCompanion
//
// Interactive pre-trade checklist with grouped toggles,
// thesis field, and score indicator.

import SwiftUI

struct PreTradeChecklistView: View {
    @Binding var checklist: PreTradeChecklist
    var onProceed: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Score indicator
            HStack {
                Text("Pre-Trade Checklist")
                    .font(AppFont.subheadline())
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                scoreIndicator
            }

            // Grouped toggles
            ForEach(ChecklistCategory.allCases, id: \.self) { category in
                categorySection(category)
            }

            // Thesis
            VStack(alignment: .leading, spacing: 2) {
                Text("Trade Thesis")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.textTertiary)
                TextField("Why this trade? What's the edge?", text: $checklist.thesis)
                    .textFieldStyle(.roundedBorder)
                    .font(AppFont.body())
            }

            // Proceed button
            if let onProceed {
                HStack {
                    Spacer()
                    Button {
                        onProceed()
                    } label: {
                        Label("Proceed to Trade", systemImage: "checkmark.circle.fill")
                            .font(AppFont.subheadline())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(checklist.score < 50)
                    Spacer()
                }
            }
        }
    }

    private var scoreIndicator: some View {
        let score = checklist.score
        let color: Color = score >= 80 ? .gainGreen : score >= 50 ? .warningAmber : .lossRed

        return HStack(spacing: Spacing.xxs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(score)%")
                .font(AppFont.mono())
                .foregroundStyle(color)
        }
    }

    private func categorySection(_ category: ChecklistCategory) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(category.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.textTertiary)
                .tracking(0.5)

            ForEach($checklist.items) { $item in
                if item.category == category {
                    Toggle(isOn: $item.isChecked) {
                        Text(item.label)
                            .font(AppFont.body())
                            .foregroundStyle(item.isChecked ? Color.textPrimary : Color.textSecondary)
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
