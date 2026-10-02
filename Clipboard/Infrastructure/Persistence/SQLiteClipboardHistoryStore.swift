import Foundation
import SQLite3

@MainActor
final class SQLiteClipboardHistoryStore: ClipboardHistoryPersisting, ClipboardUsagePersisting,
    IgnoredApplicationsPersisting, ApplicationSettingsPersisting {
    nonisolated(unsafe) private var database: OpaquePointer?

    init(databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let openResult = sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard openResult == SQLITE_OK else {
            let message = errorMessage
            sqlite3_close(database)
            database = nil
            throw SQLiteStoreError.couldNotOpen(message)
        }

        do {
            try migrate()
        } catch {
            sqlite3_close(database)
            database = nil
            throw error
        }
    }

    deinit {
        sqlite3_close(database)
    }

    static func applicationSupportStore() throws -> SQLiteClipboardHistoryStore {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw SQLiteStoreError.applicationSupportDirectoryUnavailable
        }

        let databaseURL = applicationSupportURL
            .appendingPathComponent("Clipboard", isDirectory: true)
            .appendingPathComponent("history.sqlite3")

        return try SQLiteClipboardHistoryStore(databaseURL: databaseURL)
    }

    func load() throws -> [ClipboardItem] {
        let sql = """
            SELECT id, text, created_at, last_used_at
            FROM clipboard_items
            ORDER BY last_used_at DESC, created_at DESC, id ASC;
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }

        var items: [ClipboardItem] = []

        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                guard
                    let identifierText = sqlite3_column_text(statement, 0),
                    let identifier = UUID(uuidString: String(cString: identifierText)),
                    let textValue = sqlite3_column_text(statement, 1)
                else {
                    throw SQLiteStoreError.invalidStoredItem
                }

                let createdAtValue = sqlite3_column_double(statement, 2)
                let lastUsedAtValue = sqlite3_column_double(statement, 3)
                guard createdAtValue.isFinite, lastUsedAtValue.isFinite else {
                    throw SQLiteStoreError.invalidStoredItem
                }

                items.append(
                    ClipboardItem(
                        id: identifier,
                        text: String(cString: textValue),
                        createdAt: Date(timeIntervalSince1970: createdAtValue),
                        lastUsedAt: Date(timeIntervalSince1970: lastUsedAtValue)
                    )
                )
            case SQLITE_DONE:
                return items
            default:
                throw SQLiteStoreError.statementFailed(errorMessage)
            }
        }
    }

    func save(_ items: [ClipboardItem]) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")

        do {
            let statement = try prepare(
                """
                INSERT INTO clipboard_items (id, text, created_at, last_used_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    text = excluded.text,
                    created_at = excluded.created_at,
                    last_used_at = excluded.last_used_at;
                """
            )
            defer { sqlite3_finalize(statement) }

            for item in items {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)

                try bind(item.id.uuidString, to: 1, in: statement)
                try bind(item.text, to: 2, in: statement)
                sqlite3_bind_double(statement, 3, item.createdAt.timeIntervalSince1970)
                sqlite3_bind_double(statement, 4, item.lastUsedAt.timeIntervalSince1970)

                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw SQLiteStoreError.statementFailed(errorMessage)
                }
            }

            try removeItemsMissing(from: items)
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func loadUsage(for applicationBundleIdentifier: String) throws -> [ClipboardItemUsage] {
        let statement = try prepare(
            """
            SELECT item_id, selection_count, last_selected_at
            FROM item_app_usage
            WHERE application_bundle_id = ?;
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(applicationBundleIdentifier, to: 1, in: statement)

        var usage: [ClipboardItemUsage] = []

        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                guard
                    let identifierText = sqlite3_column_text(statement, 0),
                    let identifier = UUID(uuidString: String(cString: identifierText))
                else {
                    throw SQLiteStoreError.invalidStoredItem
                }

                let lastSelectedAtValue = sqlite3_column_double(statement, 2)
                guard lastSelectedAtValue.isFinite else {
                    throw SQLiteStoreError.invalidStoredItem
                }

                usage.append(
                    ClipboardItemUsage(
                        itemID: identifier,
                        applicationBundleIdentifier: applicationBundleIdentifier,
                        selectionCount: Int(sqlite3_column_int64(statement, 1)),
                        lastSelectedAt: Date(timeIntervalSince1970: lastSelectedAtValue)
                    )
                )
            case SQLITE_DONE:
                return usage
            default:
                throw SQLiteStoreError.statementFailed(errorMessage)
            }
        }
    }

    func recordSelection(
        of itemID: ClipboardItem.ID,
        for applicationBundleIdentifier: String,
        at date: Date
    ) throws {
        let statement = try prepare(
            """
            INSERT INTO item_app_usage (
                item_id,
                application_bundle_id,
                selection_count,
                last_selected_at
            ) VALUES (?, ?, 1, ?)
            ON CONFLICT(item_id, application_bundle_id) DO UPDATE SET
                selection_count = selection_count + 1,
                last_selected_at = excluded.last_selected_at;
            """
        )
        defer { sqlite3_finalize(statement) }

        try bind(itemID.uuidString, to: 1, in: statement)
        try bind(applicationBundleIdentifier, to: 2, in: statement)
        sqlite3_bind_double(statement, 3, date.timeIntervalSince1970)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.statementFailed(errorMessage)
        }
    }

    func loadIgnoredApplicationBundleIdentifiers() throws -> Set<String> {
        let statement = try prepare(
            "SELECT application_bundle_id FROM ignored_applications;"
        )
        defer { sqlite3_finalize(statement) }

        var bundleIdentifiers: Set<String> = []

        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                guard let value = sqlite3_column_text(statement, 0) else {
                    throw SQLiteStoreError.invalidStoredItem
                }
                bundleIdentifiers.insert(String(cString: value))
            case SQLITE_DONE:
                return bundleIdentifiers
            default:
                throw SQLiteStoreError.statementFailed(errorMessage)
            }
        }
    }

    func saveIgnoredApplicationBundleIdentifiers(_ bundleIdentifiers: Set<String>) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")

        do {
            try execute("DELETE FROM ignored_applications;")
            let statement = try prepare(
                "INSERT INTO ignored_applications (application_bundle_id) VALUES (?);"
            )
            defer { sqlite3_finalize(statement) }

            for bundleIdentifier in bundleIdentifiers.sorted() {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                try bind(bundleIdentifier, to: 1, in: statement)

                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw SQLiteStoreError.statementFailed(errorMessage)
                }
            }

            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func loadHistoryLimit() throws -> Int? {
        let statement = try prepare(
            "SELECT value FROM app_settings WHERE key = 'history_limit';"
        )
        defer { sqlite3_finalize(statement) }

        switch sqlite3_step(statement) {
        case SQLITE_ROW:
            guard let value = sqlite3_column_text(statement, 0),
                  let limit = Int(String(cString: value)),
                  limit > 0 else {
                throw SQLiteStoreError.invalidStoredItem
            }
            return limit
        case SQLITE_DONE:
            return nil
        default:
            throw SQLiteStoreError.statementFailed(errorMessage)
        }
    }

    func saveHistoryLimit(_ limit: Int) throws {
        guard limit > 0 else {
            throw SQLiteStoreError.invalidSetting
        }

        let statement = try prepare(
            """
            INSERT INTO app_settings (key, value)
            VALUES ('history_limit', ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(String(limit), to: 1, in: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.statementFailed(errorMessage)
        }
    }

    func loadDisplayLimit() throws -> Int? {
        let statement = try prepare(
            "SELECT value FROM app_settings WHERE key = 'display_limit';"
        )
        defer { sqlite3_finalize(statement) }

        switch sqlite3_step(statement) {
        case SQLITE_ROW:
            guard let value = sqlite3_column_text(statement, 0),
                  let limit = Int(String(cString: value)),
                  limit > 0 else {
                throw SQLiteStoreError.invalidStoredItem
            }
            return limit
        case SQLITE_DONE:
            return nil
        default:
            throw SQLiteStoreError.statementFailed(errorMessage)
        }
    }

    func saveDisplayLimit(_ limit: Int) throws {
        guard limit > 0 else {
            throw SQLiteStoreError.invalidSetting
        }

        let statement = try prepare(
            """
            INSERT INTO app_settings (key, value)
            VALUES ('display_limit', ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
            """
        )
        defer { sqlite3_finalize(statement) }
        try bind(String(limit), to: 1, in: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.statementFailed(errorMessage)
        }
    }

    private func migrate() throws {
        try execute("PRAGMA foreign_keys = ON;")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS clipboard_items (
                id TEXT PRIMARY KEY NOT NULL,
                text TEXT NOT NULL,
                created_at REAL NOT NULL,
                last_used_at REAL NOT NULL
            );
            """
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS clipboard_items_last_used_at
            ON clipboard_items(last_used_at DESC);
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS item_app_usage (
                item_id TEXT NOT NULL REFERENCES clipboard_items(id) ON DELETE CASCADE,
                application_bundle_id TEXT NOT NULL,
                selection_count INTEGER NOT NULL CHECK(selection_count > 0),
                last_selected_at REAL NOT NULL,
                PRIMARY KEY (item_id, application_bundle_id)
            );
            """
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS item_app_usage_application
            ON item_app_usage(application_bundle_id);
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS ignored_applications (
                application_bundle_id TEXT PRIMARY KEY NOT NULL
            );
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS app_settings (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL
            );
            """
        )
        try execute("PRAGMA user_version = 4;")
    }

    private func removeItemsMissing(from items: [ClipboardItem]) throws {
        guard !items.isEmpty else {
            try execute("DELETE FROM clipboard_items;")
            return
        }

        let placeholders = Array(repeating: "?", count: items.count).joined(separator: ", ")
        let statement = try prepare(
            "DELETE FROM clipboard_items WHERE id NOT IN (\(placeholders));"
        )
        defer { sqlite3_finalize(statement) }

        for (offset, item) in items.enumerated() {
            try bind(item.id.uuidString, to: Int32(offset + 1), in: statement)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.statementFailed(errorMessage)
        }
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteStoreError.statementFailed(errorMessage)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw SQLiteStoreError.statementFailed(errorMessage)
        }

        return statement
    }

    private func bind(_ value: String, to index: Int32, in statement: OpaquePointer) throws {
        let result = value.withCString { pointer in
            sqlite3_bind_text(statement, index, pointer, -1, sqliteTransient)
        }

        guard result == SQLITE_OK else {
            throw SQLiteStoreError.statementFailed(errorMessage)
        }
    }

    private var errorMessage: String {
        guard let database, let message = sqlite3_errmsg(database) else {
            return "Unknown SQLite error"
        }

        return String(cString: message)
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteStoreError: Error {
    case applicationSupportDirectoryUnavailable
    case couldNotOpen(String)
    case invalidStoredItem
    case invalidSetting
    case statementFailed(String)
}
