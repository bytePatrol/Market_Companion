// PreTradeChecklist.swift
// MarketCompanion
//
// Pre-trade checklist model with default items across 4 categories.

import Foundation

// MARK: - Checklist Category

enum ChecklistCategory: String, CaseIterable, Codable {
    case marketContext = "Market Context"
    case setupQuality = "Setup Quality"
    case riskManagement = "Risk Management"
    case executionPlan = "Execution Plan"
}

// MARK: - Checklist Item

struct ChecklistItem: Identifiable, Codable, Hashable {
    var id: UUID
    var label: String
    var isChecked: Bool
    var category: ChecklistCategory

    init(id: UUID = UUID(), label: String, isChecked: Bool = false, category: ChecklistCategory) {
        self.id = id
        self.label = label
        self.isChecked = isChecked
        self.category = category
    }
}

// MARK: - Pre-Trade Checklist

struct PreTradeChecklist: Codable {
    var symbol: String
    var side: String
    var items: [ChecklistItem]
    var thesis: String
    var createdAt: Date
    var score: Int {
        let checked = items.filter(\.isChecked).count
        return items.isEmpty ? 0 : Int(Double(checked) / Double(items.count) * 100)
    }

    init(symbol: String = "", side: String = "long", thesis: String = "", createdAt: Date = Date()) {
        self.symbol = symbol
        self.side = side
        self.thesis = thesis
        self.createdAt = createdAt
        self.items = Self.defaultItems
    }

    static let defaultItems: [ChecklistItem] = [
        // Market Context
        ChecklistItem(label: "Market regime aligns with trade direction", category: .marketContext),
        ChecklistItem(label: "No major economic events/FOMC today", category: .marketContext),
        ChecklistItem(label: "Sector showing relative strength/weakness", category: .marketContext),

        // Setup Quality
        ChecklistItem(label: "Clear technical pattern identified", category: .setupQuality),
        ChecklistItem(label: "Volume confirms the setup", category: .setupQuality),
        ChecklistItem(label: "Multiple timeframe alignment", category: .setupQuality),

        // Risk Management
        ChecklistItem(label: "Stop loss identified before entry", category: .riskManagement),
        ChecklistItem(label: "Risk:reward >= 2:1", category: .riskManagement),
        ChecklistItem(label: "Position size within risk limits", category: .riskManagement),

        // Execution Plan
        ChecklistItem(label: "Entry trigger is specific and objective", category: .executionPlan),
        ChecklistItem(label: "Profit target(s) defined", category: .executionPlan),
        ChecklistItem(label: "Exit plan for adverse move is clear", category: .executionPlan),
    ]

    var json: String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func from(json: String) -> PreTradeChecklist? {
        guard let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PreTradeChecklist.self, from: data)
    }
}
