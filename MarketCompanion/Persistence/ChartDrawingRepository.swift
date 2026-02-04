// ChartDrawingRepository.swift
// MarketCompanion
//
// Repository for persisting chart drawing annotations.

import Foundation
import GRDB

struct ChartDrawingRepository {
    let db: DatabaseManager

    func forSymbol(_ symbol: String) -> [ChartDrawing] {
        (try? db.dbQueue.read { db in
            try ChartDrawing
                .filter(Column("symbol") == symbol)
                .order(Column("createdAt"))
                .fetchAll(db)
        }) ?? []
    }

    func save(_ drawing: inout ChartDrawing) throws {
        try db.dbQueue.write { db in
            try drawing.save(db)
        }
    }

    func delete(id: Int64) throws {
        try db.dbQueue.write { db in
            _ = try ChartDrawing.deleteOne(db, id: id)
        }
    }

    func deleteAll(symbol: String) throws {
        try db.dbQueue.write { db in
            _ = try ChartDrawing
                .filter(Column("symbol") == symbol)
                .deleteAll(db)
        }
    }
}
