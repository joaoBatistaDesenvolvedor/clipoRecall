import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// ── Model ─────────────────────────────────────────────────────────────────────

struct ClipboardItem: Identifiable, Sendable {
    let id: Int
    var content: String
    var contentType: String
    var createdAt: String
    var pinned: Bool
}

// ── Store ─────────────────────────────────────────────────────────────────────

actor HistoryStore {
    static let shared = HistoryStore()

    private var db: OpaquePointer?

    private init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cliprecall")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("history.db").path
        sqlite3_open(path, &db)
        sqlite3_exec(db, """
            CREATE TABLE IF NOT EXISTS items (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                content     TEXT    NOT NULL,
                content_type TEXT   NOT NULL DEFAULT 'text',
                created_at  TEXT    NOT NULL,
                pinned      INTEGER NOT NULL DEFAULT 0
            );
        """, nil, nil, nil)
    }

    // ── Write ─────────────────────────────────────────────────────────────────

    func addItem(content: String, contentType: String = "text") {
        // Dedup: ignora se igual ao item mais recente
        var check: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT content FROM items ORDER BY id DESC LIMIT 1;",
                              -1, &check, nil) == SQLITE_OK {
            if sqlite3_step(check) == SQLITE_ROW,
               let ptr = sqlite3_column_text(check, 0),
               String(cString: ptr) == content {
                sqlite3_finalize(check)
                return
            }
            sqlite3_finalize(check)
        }

        let now = ISO8601DateFormatter().string(from: Date())
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db,
            "INSERT INTO items (content, content_type, created_at) VALUES (?, ?, ?);",
            -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, content,     -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, contentType, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, now,         -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    func deleteItem(id: Int) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "DELETE FROM items WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    func togglePin(id: Int) -> ClipboardItem? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "UPDATE items SET pinned = NOT pinned WHERE id = ?;",
                              -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        return fetchOne(id: id)
    }

    func clearHistory() {
        sqlite3_exec(db, "DELETE FROM items WHERE pinned = 0;", nil, nil, nil)
    }

    // ── Read ──────────────────────────────────────────────────────────────────

    func fetchHistory() -> [ClipboardItem] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, """
            SELECT id, content, content_type, created_at, pinned
            FROM items
            ORDER BY pinned DESC, id DESC
            LIMIT 300;
        """, -1, &stmt, nil) == SQLITE_OK else { return [] }
        return rows(from: stmt)
    }

    private func fetchOne(id: Int) -> ClipboardItem? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db,
            "SELECT id, content, content_type, created_at, pinned FROM items WHERE id = ?;",
            -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_int(stmt, 1, Int32(id))
        return rows(from: stmt).first
    }

    private func rows(from stmt: OpaquePointer?) -> [ClipboardItem] {
        var result: [ClipboardItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id          = Int(sqlite3_column_int(stmt, 0))
            let content     = String(cString: sqlite3_column_text(stmt, 1))
            let contentType = String(cString: sqlite3_column_text(stmt, 2))
            let createdAt   = String(cString: sqlite3_column_text(stmt, 3))
            let pinned      = sqlite3_column_int(stmt, 4) != 0
            result.append(ClipboardItem(id: id, content: content,
                                        contentType: contentType,
                                        createdAt: createdAt, pinned: pinned))
        }
        sqlite3_finalize(stmt)
        return result
    }
}
