// DatabaseManager.swift
// MarketCompanion
//
// SQLite persistence via GRDB. Manages schema migrations and provides
// typed access to all repositories.

import Foundation
import GRDB

final class DatabaseManager: @unchecked Sendable {
    static let shared = DatabaseManager()

    let dbQueue: DatabaseQueue

    private init() {
        do {
            let fileManager = FileManager.default
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dbDir = appSupport.appendingPathComponent("MarketCompanion", isDirectory: true)

            try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true)

            let dbPath = dbDir.appendingPathComponent("market_companion.sqlite").path
            dbQueue = try DatabaseQueue(path: dbPath)

            try migrate()
            print("[DB] Database ready at: \(dbPath)")
        } catch {
            fatalError("Database initialization failed: \(error)")
        }
    }

    /// For unit tests: create an in-memory database
    init(inMemory: Bool) throws {
        if inMemory {
            dbQueue = try DatabaseQueue()
        } else {
            dbQueue = try DatabaseQueue(path: ":memory:")
        }
        try migrate()
    }

    // MARK: - Migrations

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        // Always recreate in development
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_initial") { db in
            // Holdings
            try db.create(table: "holding", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("symbol", .text).notNull().indexed()
                t.column("shares", .double)
                t.column("costBasis", .double)
                t.column("tags", .text).notNull().defaults(to: "")
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.uniqueKey(["symbol"])
            }

            // Watch Items
            try db.create(table: "watchItem", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("symbol", .text).notNull().indexed()
                t.column("reasonTag", .text).notNull()
                t.column("note", .text)
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("source", .text)
            }

            // Quotes (latest snapshot)
            try db.create(table: "quote", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("symbol", .text).notNull().indexed()
                t.column("last", .double).notNull()
                t.column("changePct", .double).notNull()
                t.column("volume", .integer).notNull()
                t.column("avgVolume", .integer).notNull()
                t.column("dayHigh", .double).notNull()
                t.column("dayLow", .double).notNull()
                t.column("updatedAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.uniqueKey(["symbol"])
            }

            // Daily Bars
            try db.create(table: "dailyBar", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("symbol", .text).notNull()
                t.column("date", .date).notNull()
                t.column("open", .double).notNull()
                t.column("high", .double).notNull()
                t.column("low", .double).notNull()
                t.column("close", .double).notNull()
                t.column("volume", .integer).notNull()
                t.uniqueKey(["symbol", "date"])
            }

            // Reports
            try db.create(table: "report", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("type", .text).notNull()
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("jsonPayload", .text).notNull().defaults(to: "{}")
                t.column("renderedMarkdown", .text).notNull().defaults(to: "")
            }

            // Alert Rules
            try db.create(table: "alertRule", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("symbol", .text)
                t.column("sector", .text)
                t.column("type", .text).notNull()
                t.column("thresholdValue", .double).notNull().defaults(to: 2.0)
                t.column("enabled", .boolean).notNull().defaults(to: true)
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }

            // Alert Events
            try db.create(table: "alertEvent", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("ruleId", .integer).notNull()
                    .references("alertRule", onDelete: .cascade)
                t.column("triggeredAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("summary", .text).notNull()
                t.column("details", .text).notNull().defaults(to: "")
            }

            // Trades
            try db.create(table: "trade", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("symbol", .text).notNull().indexed()
                t.column("side", .text).notNull()
                t.column("qty", .double).notNull()
                t.column("entryPrice", .double).notNull()
                t.column("exitPrice", .double)
                t.column("entryTime", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("exitTime", .datetime)
                t.column("notes", .text).notNull().defaults(to: "")
                t.column("tags", .text).notNull().defaults(to: "")
            }

            // Trade Context
            try db.create(table: "tradeContext", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("tradeId", .integer).notNull()
                    .references("trade", onDelete: .cascade)
                t.column("vixProxy", .double)
                t.column("marketBreadthProxy", .double)
                t.column("sectorStrengthSnapshot", .text).notNull().defaults(to: "{}")
                t.column("volatilityRegime", .text).notNull().defaults(to: "normal")
                t.column("timeOfDay", .text).notNull().defaults(to: "")
                t.column("additionalNotes", .text).notNull().defaults(to: "")
            }
        }

        migrator.registerMigration("v2_checklist") { db in
            try db.alter(table: "tradeContext") { t in
                t.add(column: "checklistJson", .text).notNull().defaults(to: "")
            }
        }

        // Feature #1: News & Calendar
        migrator.registerMigration("v3_news_calendar") { db in
            try db.create(table: "newsItem", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("headline", .text).notNull()
                t.column("summary", .text).notNull().defaults(to: "")
                t.column("source", .text).notNull()
                t.column("url", .text).notNull()
                t.column("publishedAt", .datetime).notNull()
                t.column("relatedSymbols", .text).notNull().defaults(to: "[]")
                t.column("sentiment", .text)
            }

            try db.create(table: "calendarEvent", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("symbol", .text).notNull().indexed()
                t.column("eventType", .text).notNull()
                t.column("date", .datetime).notNull()
                t.column("eventDescription", .text).notNull().defaults(to: "")
                t.column("estimatedEPS", .double)
                t.column("actualEPS", .double)
            }
        }

        // Feature #3: Chart Drawings
        migrator.registerMigration("v4_chart_drawings") { db in
            try db.create(table: "chartDrawing", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("symbol", .text).notNull().indexed()
                t.column("type", .text).notNull()
                t.column("startPrice", .double).notNull()
                t.column("startTime", .datetime).notNull()
                t.column("endPrice", .double)
                t.column("endTime", .datetime)
                t.column("color", .text).notNull().defaults(to: "#FFFFFF")
                t.column("label", .text)
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
        }

        // Feature #7: Composite Alerts
        migrator.registerMigration("v5_composite_alerts") { db in
            try db.alter(table: "alertRule") { t in
                t.add(column: "compositeConditions", .text)
            }
        }

        // Feature #1: Treemap — Add marketCap to quote
        migrator.registerMigration("v6_quote_market_cap") { db in
            try db.alter(table: "quote") { t in
                t.add(column: "marketCap", .double)
            }
        }

        // Feature #7: Trade Plan — Add plan prices to trade
        migrator.registerMigration("v7_trade_plan_prices") { db in
            try db.alter(table: "trade") { t in
                t.add(column: "planEntryPrice", .double)
                t.add(column: "planStopPrice", .double)
                t.add(column: "planTargetPrice", .double)
            }
        }

        // Feature #8: Workspaces
        migrator.registerMigration("v8_workspaces") { db in
            try db.create(table: "workspaceLayout", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("selectedPage", .text).notNull()
                t.column("companionVisible", .boolean).notNull().defaults(to: false)
                t.column("companionFocusMode", .boolean).notNull().defaults(to: false)
                t.column("chartSymbol", .text)
                t.column("chartConfigJson", .text)
                t.column("sidebarWidth", .double)
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
        }

        // Feature #10: Watchlist Groups
        migrator.registerMigration("v9_watchlist_groups") { db in
            try db.create(table: "watchlistGroup", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("colorHex", .text).notNull().defaults(to: "#00BFBF")
                t.column("isExpanded", .boolean).notNull().defaults(to: true)
                t.column("createdAt", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }

            try db.alter(table: "watchItem") { t in
                t.add(column: "groupId", .integer)
                    .references("watchlistGroup")
            }

            try db.alter(table: "holding") { t in
                t.add(column: "groupId", .integer)
                    .references("watchlistGroup")
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Database Path (for Settings display)

    var databasePath: String {
        dbQueue.path ?? "In-Memory"
    }

    // MARK: - Delete All Data

    func deleteAllData() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM workspaceLayout")
            try db.execute(sql: "DELETE FROM chartDrawing")
            try db.execute(sql: "DELETE FROM calendarEvent")
            try db.execute(sql: "DELETE FROM newsItem")
            try db.execute(sql: "DELETE FROM tradeContext")
            try db.execute(sql: "DELETE FROM trade")
            try db.execute(sql: "DELETE FROM alertEvent")
            try db.execute(sql: "DELETE FROM alertRule")
            try db.execute(sql: "DELETE FROM report")
            try db.execute(sql: "DELETE FROM dailyBar")
            try db.execute(sql: "DELETE FROM quote")
            try db.execute(sql: "DELETE FROM watchItem")
            try db.execute(sql: "DELETE FROM watchlistGroup")
            try db.execute(sql: "DELETE FROM holding")
        }
    }
}
