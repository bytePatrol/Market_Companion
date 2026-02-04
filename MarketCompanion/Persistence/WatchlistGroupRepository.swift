// WatchlistGroupRepository.swift
// MarketCompanion
//
// CRUD operations for watchlist groups.

import Foundation
import GRDB

struct WatchlistGroupRepository {
    let db: DatabaseManager

    func all() throws -> [WatchlistGroup] {
        try db.dbQueue.read { db in
            try WatchlistGroup.order(Column("sortOrder")).fetchAll(db)
        }
    }

    func save(_ group: inout WatchlistGroup) throws {
        try db.dbQueue.write { db in
            try group.save(db, onConflict: .replace)
        }
    }

    func delete(id: Int64) throws {
        try db.dbQueue.write { db in
            // Clear groupId references before deleting
            try db.execute(sql: "UPDATE holding SET groupId = NULL WHERE groupId = ?", arguments: [id])
            try db.execute(sql: "UPDATE watchItem SET groupId = NULL WHERE groupId = ?", arguments: [id])
            _ = try WatchlistGroup.deleteOne(db, id: id)
        }
    }

    func reorder(_ groups: [WatchlistGroup]) throws {
        try db.dbQueue.write { db in
            for (index, var group) in groups.enumerated() {
                group.sortOrder = index
                try group.update(db)
            }
        }
    }
}
