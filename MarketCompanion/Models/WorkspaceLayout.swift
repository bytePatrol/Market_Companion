// WorkspaceLayout.swift
// MarketCompanion
//
// Saved workspace layout state persisted via GRDB.

import Foundation
import GRDB

struct WorkspaceLayout: Codable, Identifiable, Hashable {
    var id: Int64?
    var name: String
    var selectedPage: String
    var companionVisible: Bool
    var companionFocusMode: Bool
    var chartSymbol: String?
    var chartConfigJson: String?
    var sidebarWidth: Double?
    var createdAt: Date

    init(
        id: Int64? = nil,
        name: String,
        selectedPage: String = "Dashboard",
        companionVisible: Bool = false,
        companionFocusMode: Bool = false,
        chartSymbol: String? = nil,
        chartConfigJson: String? = nil,
        sidebarWidth: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.selectedPage = selectedPage
        self.companionVisible = companionVisible
        self.companionFocusMode = companionFocusMode
        self.chartSymbol = chartSymbol
        self.chartConfigJson = chartConfigJson
        self.sidebarWidth = sidebarWidth
        self.createdAt = createdAt
    }
}

extension WorkspaceLayout: FetchableRecord, PersistableRecord {
    static let databaseTableName = "workspaceLayout"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
