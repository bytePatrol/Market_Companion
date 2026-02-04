// ChartDrawing.swift
// MarketCompanion
//
// Persistent chart drawing annotations (trend lines, horizontals, Fibonacci, text).

import Foundation
import GRDB

// MARK: - Drawing Type

enum DrawingType: String, Codable, CaseIterable {
    case trendLine = "trendLine"
    case horizontalLine = "horizontalLine"
    case fibonacciRetracement = "fibonacci"
    case textAnnotation = "textAnnotation"
}

// MARK: - Chart Drawing

struct ChartDrawing: Codable, Identifiable, Hashable {
    var id: Int64?
    var symbol: String
    var type: DrawingType
    var startPrice: Double
    var startTime: Date
    var endPrice: Double?
    var endTime: Date?
    var color: String  // hex
    var label: String?
    var createdAt: Date

    init(
        id: Int64? = nil,
        symbol: String,
        type: DrawingType,
        startPrice: Double,
        startTime: Date,
        endPrice: Double? = nil,
        endTime: Date? = nil,
        color: String = "#FFFFFF",
        label: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.symbol = symbol
        self.type = type
        self.startPrice = startPrice
        self.startTime = startTime
        self.endPrice = endPrice
        self.endTime = endTime
        self.color = color
        self.label = label
        self.createdAt = createdAt
    }
}

// MARK: - GRDB Conformance

extension ChartDrawing: FetchableRecord, PersistableRecord {
    static let databaseTableName = "chartDrawing"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
