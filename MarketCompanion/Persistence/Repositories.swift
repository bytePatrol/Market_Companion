// Repositories.swift
// MarketCompanion
//
// Type-safe repository layer over GRDB for all models.

import Foundation
import GRDB

// MARK: - GRDB Conformances

extension Holding: FetchableRecord, PersistableRecord {
    static let databaseTableName = "holding"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension WatchItem: FetchableRecord, PersistableRecord {
    static let databaseTableName = "watchItem"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Quote: FetchableRecord, PersistableRecord {
    static let databaseTableName = "quote"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension DailyBar: FetchableRecord, PersistableRecord {
    static let databaseTableName = "dailyBar"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Report: FetchableRecord, PersistableRecord {
    static let databaseTableName = "report"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension AlertRule: FetchableRecord, PersistableRecord {
    static let databaseTableName = "alertRule"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension AlertEvent: FetchableRecord, PersistableRecord {
    static let databaseTableName = "alertEvent"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Trade: FetchableRecord, PersistableRecord {
    static let databaseTableName = "trade"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension TradeContext: FetchableRecord, PersistableRecord {
    static let databaseTableName = "tradeContext"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - NewsItem DB Model (local persistence for provider NewsItem)

struct NewsItemRecord: Codable, Identifiable, Hashable {
    var id: Int64?
    var headline: String
    var summary: String
    var source: String
    var url: String
    var publishedAt: Date
    var relatedSymbols: String  // JSON array
    var sentiment: String?

    init(from newsItem: NewsItem) {
        self.id = nil
        self.headline = newsItem.headline
        self.summary = newsItem.summary
        self.source = newsItem.source
        self.url = newsItem.url
        self.publishedAt = newsItem.publishedAt
        self.relatedSymbols = (try? String(data: JSONEncoder().encode(newsItem.relatedSymbols), encoding: .utf8)) ?? "[]"
        self.sentiment = newsItem.sentiment
    }

    var symbolList: [String] {
        guard let data = relatedSymbols.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    func toNewsItem() -> NewsItem {
        NewsItem(
            headline: headline,
            summary: summary,
            source: source,
            url: url,
            publishedAt: publishedAt,
            relatedSymbols: symbolList,
            sentiment: sentiment
        )
    }
}

extension NewsItemRecord: FetchableRecord, PersistableRecord {
    static let databaseTableName = "newsItem"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - CalendarEvent DB Model

struct CalendarEventRecord: Codable, Identifiable, Hashable {
    var id: Int64?
    var symbol: String
    var eventType: String
    var date: Date
    var eventDescription: String
    var estimatedEPS: Double?
    var actualEPS: Double?

    init(from event: CalendarEvent) {
        self.id = nil
        self.symbol = event.symbol
        self.eventType = event.eventType
        self.date = event.date
        self.eventDescription = event.description
        self.estimatedEPS = event.estimatedEPS
        self.actualEPS = event.actualEPS
    }

    func toCalendarEvent() -> CalendarEvent {
        CalendarEvent(
            symbol: symbol,
            eventType: eventType,
            date: date,
            description: eventDescription,
            estimatedEPS: estimatedEPS,
            actualEPS: actualEPS
        )
    }
}

extension CalendarEventRecord: FetchableRecord, PersistableRecord {
    static let databaseTableName = "calendarEvent"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Holding Repository

struct HoldingRepository {
    let db: DatabaseManager

    func all() throws -> [Holding] {
        try db.dbQueue.read { db in
            try Holding.order(Column("symbol")).fetchAll(db)
        }
    }

    func save(_ holding: inout Holding) throws {
        try db.dbQueue.write { db in
            try holding.save(db, onConflict: .replace)
        }
    }

    func delete(id: Int64) throws {
        try db.dbQueue.write { db in
            _ = try Holding.deleteOne(db, id: id)
        }
    }

    func find(symbol: String) throws -> Holding? {
        try db.dbQueue.read { db in
            try Holding.filter(Column("symbol") == symbol).fetchOne(db)
        }
    }

    func symbols() throws -> [String] {
        try all().map(\.symbol)
    }

    func forGroup(_ groupId: Int64) throws -> [Holding] {
        try db.dbQueue.read { db in
            try Holding
                .filter(Column("groupId") == groupId)
                .order(Column("symbol"))
                .fetchAll(db)
        }
    }

    func ungrouped() throws -> [Holding] {
        try db.dbQueue.read { db in
            try Holding
                .filter(Column("groupId") == nil)
                .order(Column("symbol"))
                .fetchAll(db)
        }
    }

    func seedIfEmpty() throws {
        let count = try db.dbQueue.read { db in
            try Holding.fetchCount(db)
        }
        if count == 0 {
            try db.dbQueue.write { db in
                for var holding in MockDataProvider.seedHoldings {
                    try holding.insert(db)
                }
            }
        }
    }
}

// MARK: - WatchItem Repository

struct WatchItemRepository {
    let db: DatabaseManager

    func all() throws -> [WatchItem] {
        try db.dbQueue.read { db in
            try WatchItem.order(Column("createdAt").desc).fetchAll(db)
        }
    }

    func save(_ item: inout WatchItem) throws {
        try db.dbQueue.write { db in
            try item.save(db)
        }
    }

    func delete(id: Int64) throws {
        try db.dbQueue.write { db in
            _ = try WatchItem.deleteOne(db, id: id)
        }
    }

    func symbols() throws -> [String] {
        try all().map(\.symbol)
    }

    func forGroup(_ groupId: Int64) throws -> [WatchItem] {
        try db.dbQueue.read { db in
            try WatchItem
                .filter(Column("groupId") == groupId)
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func ungrouped() throws -> [WatchItem] {
        try db.dbQueue.read { db in
            try WatchItem
                .filter(Column("groupId") == nil)
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    func seedIfEmpty() throws {
        let count = try db.dbQueue.read { db in
            try WatchItem.fetchCount(db)
        }
        if count == 0 {
            try db.dbQueue.write { db in
                for var item in MockDataProvider.seedWatchItems {
                    try item.insert(db)
                }
            }
        }
    }
}

// MARK: - Quote Repository

struct QuoteRepository {
    let db: DatabaseManager

    func all() throws -> [Quote] {
        try db.dbQueue.read { db in
            try Quote.fetchAll(db)
        }
    }

    func forSymbols(_ symbols: [String]) throws -> [Quote] {
        try db.dbQueue.read { db in
            try Quote.filter(symbols.contains(Column("symbol"))).fetchAll(db)
        }
    }

    func upsert(_ quotes: [Quote]) throws {
        try db.dbQueue.write { db in
            for var quote in quotes {
                try quote.save(db, onConflict: .replace)
            }
        }
    }

    func forSymbol(_ symbol: String) throws -> Quote? {
        try db.dbQueue.read { db in
            try Quote.filter(Column("symbol") == symbol).fetchOne(db)
        }
    }
}

// MARK: - DailyBar Repository

struct DailyBarRepository {
    let db: DatabaseManager

    func forSymbol(_ symbol: String, limit: Int = 30) throws -> [DailyBar] {
        try db.dbQueue.read { db in
            try DailyBar
                .filter(Column("symbol") == symbol)
                .order(Column("date").desc)
                .limit(limit)
                .fetchAll(db)
                .reversed()
        }
    }

    func save(_ bars: [DailyBar]) throws {
        try db.dbQueue.write { db in
            for var bar in bars {
                try bar.save(db, onConflict: .replace)
            }
        }
    }

    func latestDate(for symbol: String) throws -> Date? {
        try db.dbQueue.read { db in
            try DailyBar
                .filter(Column("symbol") == symbol)
                .order(Column("date").desc)
                .limit(1)
                .fetchOne(db)?
                .date
        }
    }
}

// MARK: - Report Repository

struct ReportRepository {
    let db: DatabaseManager

    func all(type: ReportType? = nil) throws -> [Report] {
        try db.dbQueue.read { db in
            var request = Report.order(Column("createdAt").desc)
            if let type {
                request = request.filter(Column("type") == type.rawValue)
            }
            return try request.fetchAll(db)
        }
    }

    func latest(type: ReportType) throws -> Report? {
        try db.dbQueue.read { db in
            try Report
                .filter(Column("type") == type.rawValue)
                .order(Column("createdAt").desc)
                .limit(1)
                .fetchOne(db)
        }
    }

    func save(_ report: inout Report) throws {
        try db.dbQueue.write { db in
            try report.save(db)
        }
    }

    func forDate(_ date: Date) throws -> [Report] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return try db.dbQueue.read { db in
            try Report
                .filter(Column("createdAt") >= start && Column("createdAt") < end)
                .order(Column("createdAt"))
                .fetchAll(db)
        }
    }
}

// MARK: - AlertRule Repository

struct AlertRuleRepository {
    let db: DatabaseManager

    func all() throws -> [AlertRule] {
        try db.dbQueue.read { db in
            try AlertRule.order(Column("createdAt").desc).fetchAll(db)
        }
    }

    func enabled() throws -> [AlertRule] {
        try db.dbQueue.read { db in
            try AlertRule
                .filter(Column("enabled") == true)
                .fetchAll(db)
        }
    }

    func save(_ rule: inout AlertRule) throws {
        try db.dbQueue.write { db in
            try rule.save(db)
        }
    }

    func delete(id: Int64) throws {
        try db.dbQueue.write { db in
            _ = try AlertRule.deleteOne(db, id: id)
        }
    }

    func toggleEnabled(id: Int64) throws {
        try db.dbQueue.write { db in
            if var rule = try AlertRule.fetchOne(db, id: id) {
                rule.enabled.toggle()
                try rule.update(db)
            }
        }
    }
}

// MARK: - AlertEvent Repository

struct AlertEventRepository {
    let db: DatabaseManager

    func all(limit: Int = 50) throws -> [AlertEvent] {
        try db.dbQueue.read { db in
            try AlertEvent
                .order(Column("triggeredAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func save(_ event: inout AlertEvent) throws {
        try db.dbQueue.write { db in
            try event.save(db)
        }
    }

    func forRule(_ ruleId: Int64) throws -> [AlertEvent] {
        try db.dbQueue.read { db in
            try AlertEvent
                .filter(Column("ruleId") == ruleId)
                .order(Column("triggeredAt").desc)
                .fetchAll(db)
        }
    }

    func recent(hours: Int = 24) throws -> [AlertEvent] {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -hours, to: Date())!
        return try db.dbQueue.read { db in
            try AlertEvent
                .filter(Column("triggeredAt") >= cutoff)
                .order(Column("triggeredAt").desc)
                .fetchAll(db)
        }
    }
}

// MARK: - Trade Repository

struct TradeRepository {
    let db: DatabaseManager

    func all() throws -> [Trade] {
        try db.dbQueue.read { db in
            try Trade.order(Column("entryTime").desc).fetchAll(db)
        }
    }

    func open() throws -> [Trade] {
        try db.dbQueue.read { db in
            try Trade
                .filter(Column("exitPrice") == nil)
                .order(Column("entryTime").desc)
                .fetchAll(db)
        }
    }

    func closed() throws -> [Trade] {
        try db.dbQueue.read { db in
            try Trade
                .filter(Column("exitPrice") != nil)
                .order(Column("exitTime").desc)
                .fetchAll(db)
        }
    }

    func save(_ trade: inout Trade) throws {
        try db.dbQueue.write { db in
            try trade.save(db)
        }
    }

    func delete(id: Int64) throws {
        try db.dbQueue.write { db in
            _ = try Trade.deleteOne(db, id: id)
        }
    }

    func forSymbol(_ symbol: String) throws -> [Trade] {
        try db.dbQueue.read { db in
            try Trade
                .filter(Column("symbol") == symbol)
                .order(Column("entryTime").desc)
                .fetchAll(db)
        }
    }
}

// MARK: - TradeContext Repository

struct TradeContextRepository {
    let db: DatabaseManager

    func forTrade(_ tradeId: Int64) throws -> TradeContext? {
        try db.dbQueue.read { db in
            try TradeContext
                .filter(Column("tradeId") == tradeId)
                .fetchOne(db)
        }
    }

    func save(_ context: inout TradeContext) throws {
        try db.dbQueue.write { db in
            try context.save(db)
        }
    }
}

// MARK: - News Repository

struct NewsRepository {
    let db: DatabaseManager

    func save(_ items: [NewsItem]) throws {
        try db.dbQueue.write { db in
            for item in items {
                let record = NewsItemRecord(from: item)
                try record.insert(db)
            }
        }
    }

    func forSymbol(_ symbol: String, limit: Int = 50) throws -> [NewsItem] {
        try db.dbQueue.read { db in
            try NewsItemRecord
                .filter(Column("relatedSymbols").like("%\(symbol)%"))
                .order(Column("publishedAt").desc)
                .limit(limit)
                .fetchAll(db)
        }.map { $0.toNewsItem() }
    }

    func recent(days: Int = 7) throws -> [NewsItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return try db.dbQueue.read { db in
            try NewsItemRecord
                .filter(Column("publishedAt") >= cutoff)
                .order(Column("publishedAt").desc)
                .fetchAll(db)
        }.map { $0.toNewsItem() }
    }

    func all(limit: Int = 100) throws -> [NewsItem] {
        try db.dbQueue.read { db in
            try NewsItemRecord
                .order(Column("publishedAt").desc)
                .limit(limit)
                .fetchAll(db)
        }.map { $0.toNewsItem() }
    }
}

// MARK: - CalendarEvent Repository

struct CalendarEventRepository {
    let db: DatabaseManager

    func save(_ events: [CalendarEvent]) throws {
        try db.dbQueue.write { db in
            for event in events {
                let record = CalendarEventRecord(from: event)
                try record.insert(db)
            }
        }
    }

    func upcoming(days: Int = 30) throws -> [CalendarEvent] {
        let now = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: days, to: now)!
        return try db.dbQueue.read { db in
            try CalendarEventRecord
                .filter(Column("date") >= now && Column("date") <= end)
                .order(Column("date"))
                .fetchAll(db)
        }.map { $0.toCalendarEvent() }
    }

    func forSymbol(_ symbol: String) throws -> [CalendarEvent] {
        try db.dbQueue.read { db in
            try CalendarEventRecord
                .filter(Column("symbol") == symbol)
                .order(Column("date"))
                .fetchAll(db)
        }.map { $0.toCalendarEvent() }
    }
}
