// WatchlistGroup.swift
// MarketCompanion
//
// Watchlist group model for organizing holdings and watch items.

import Foundation
import GRDB

struct WatchlistGroup: Codable, Identifiable, Hashable {
    var id: Int64?
    var name: String
    var sortOrder: Int
    var colorHex: String
    var isExpanded: Bool
    var createdAt: Date

    init(
        id: Int64? = nil,
        name: String,
        sortOrder: Int = 0,
        colorHex: String = "#00BFBF",
        isExpanded: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.colorHex = colorHex
        self.isExpanded = isExpanded
        self.createdAt = createdAt
    }

    var color: Color {
        Color(hex: colorHex) ?? .teal
    }
}

import SwiftUI

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6,
              let hexInt = UInt64(hexSanitized, radix: 16) else { return nil }

        let r = Double((hexInt >> 16) & 0xFF) / 255.0
        let g = Double((hexInt >> 8) & 0xFF) / 255.0
        let b = Double(hexInt & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

extension WatchlistGroup: FetchableRecord, PersistableRecord {
    static let databaseTableName = "watchlistGroup"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
