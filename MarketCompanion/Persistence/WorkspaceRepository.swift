// WorkspaceRepository.swift
// MarketCompanion
//
// CRUD operations for saved workspace layouts.

import Foundation
import GRDB

struct WorkspaceRepository {
    let db: DatabaseManager

    func all() throws -> [WorkspaceLayout] {
        try db.dbQueue.read { db in
            try WorkspaceLayout.order(Column("name")).fetchAll(db)
        }
    }

    func save(_ layout: inout WorkspaceLayout) throws {
        try db.dbQueue.write { db in
            try layout.save(db, onConflict: .replace)
        }
    }

    func delete(id: Int64) throws {
        try db.dbQueue.write { db in
            _ = try WorkspaceLayout.deleteOne(db, id: id)
        }
    }

    func rename(id: Int64, to newName: String) throws {
        try db.dbQueue.write { db in
            if var layout = try WorkspaceLayout.fetchOne(db, id: id) {
                layout.name = newName
                try layout.update(db)
            }
        }
    }
}
