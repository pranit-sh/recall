import Foundation
import XCTest
@testable import Clipboard

@MainActor
final class SQLiteClipboardHistoryStoreTests: XCTestCase {
    func testSavedItemsCanBeLoadedFromAReopenedDatabase() throws {
        let databaseURL = makeDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let olderItem = ClipboardItem(
            id: UUID(),
            text: "Older",
            createdAt: Date(timeIntervalSince1970: 100),
            lastUsedAt: Date(timeIntervalSince1970: 200)
        )
        let newerItem = ClipboardItem(
            id: UUID(),
            text: "Newer",
            createdAt: Date(timeIntervalSince1970: 300),
            lastUsedAt: Date(timeIntervalSince1970: 400)
        )

        try SQLiteClipboardHistoryStore(databaseURL: databaseURL).save([newerItem, olderItem])
        let loadedItems = try SQLiteClipboardHistoryStore(databaseURL: databaseURL).load()

        XCTAssertEqual(loadedItems, [newerItem, olderItem])
        XCTAssertEqual(loadedItems.map(\.text), ["Newer", "Older"])
        XCTAssertEqual(loadedItems.map(\.createdAt), [newerItem.createdAt, olderItem.createdAt])
        XCTAssertEqual(loadedItems.map(\.lastUsedAt), [newerItem.lastUsedAt, olderItem.lastUsedAt])
    }

    func testSavingASecondSnapshotRemovesItemsMissingFromIt() throws {
        let databaseURL = makeDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let removedItem = ClipboardItem(text: "Removed")
        let retainedItem = ClipboardItem(text: "Retained")
        let store = try SQLiteClipboardHistoryStore(databaseURL: databaseURL)

        try store.save([removedItem, retainedItem])
        try store.save([retainedItem])

        XCTAssertEqual(try store.load(), [retainedItem])
    }

    func testCorruptDatabaseFailsWithoutCrashing() throws {
        let databaseURL = makeDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not a sqlite database".utf8).write(to: databaseURL)

        XCTAssertThrowsError(try SQLiteClipboardHistoryStore(databaseURL: databaseURL))
    }

    func testUsageIsAccumulatedSeparatelyForEachApplication() throws {
        let databaseURL = makeDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let item = ClipboardItem(text: "Shared")
        let store = try SQLiteClipboardHistoryStore(databaseURL: databaseURL)
        try store.save([item])

        try store.recordSelection(
            of: item.id,
            for: "com.example.editor",
            at: Date(timeIntervalSince1970: 100)
        )
        try store.recordSelection(
            of: item.id,
            for: "com.example.editor",
            at: Date(timeIntervalSince1970: 200)
        )
        try store.recordSelection(
            of: item.id,
            for: "com.example.browser",
            at: Date(timeIntervalSince1970: 300)
        )

        let editorUsage = try store.loadUsage(for: "com.example.editor")
        let browserUsage = try store.loadUsage(for: "com.example.browser")

        XCTAssertEqual(editorUsage, [
            ClipboardItemUsage(
                itemID: item.id,
                applicationBundleIdentifier: "com.example.editor",
                selectionCount: 2,
                lastSelectedAt: Date(timeIntervalSince1970: 200)
            )
        ])
        XCTAssertEqual(browserUsage.first?.selectionCount, 1)
    }

    func testRemovingAnItemAlsoRemovesItsUsage() throws {
        let databaseURL = makeDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let removedItem = ClipboardItem(text: "Removed")
        let retainedItem = ClipboardItem(text: "Retained")
        let store = try SQLiteClipboardHistoryStore(databaseURL: databaseURL)
        try store.save([removedItem, retainedItem])
        try store.recordSelection(
            of: removedItem.id,
            for: "com.example.editor",
            at: Date()
        )

        try store.save([retainedItem])

        XCTAssertTrue(try store.loadUsage(for: "com.example.editor").isEmpty)
    }

    func testIgnoredApplicationsPersistAcrossDatabaseInstances() throws {
        let databaseURL = makeDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let ignoredApplications: Set<String> = [
            "com.example.private",
            "com.example.passwords"
        ]

        try SQLiteClipboardHistoryStore(databaseURL: databaseURL)
            .saveIgnoredApplicationBundleIdentifiers(ignoredApplications)
        let restoredApplications = try SQLiteClipboardHistoryStore(databaseURL: databaseURL)
            .loadIgnoredApplicationBundleIdentifiers()

        XCTAssertEqual(restoredApplications, ignoredApplications)
    }

    func testSavingIgnoredApplicationsRemovesAllowedApplications() throws {
        let databaseURL = makeDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }
        let store = try SQLiteClipboardHistoryStore(databaseURL: databaseURL)
        try store.saveIgnoredApplicationBundleIdentifiers([
            "com.example.private",
            "com.example.allowed"
        ])

        try store.saveIgnoredApplicationBundleIdentifiers(["com.example.private"])

        XCTAssertEqual(
            try store.loadIgnoredApplicationBundleIdentifiers(),
            ["com.example.private"]
        )
    }

    func testHistoryLimitPersistsAcrossDatabaseInstances() throws {
        let databaseURL = makeDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }

        try SQLiteClipboardHistoryStore(databaseURL: databaseURL).saveHistoryLimit(250)
        let restoredLimit = try SQLiteClipboardHistoryStore(databaseURL: databaseURL)
            .loadHistoryLimit()

        XCTAssertEqual(restoredLimit, 250)
    }

    func testMissingHistoryLimitReturnsNil() throws {
        let databaseURL = makeDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }

        let store = try SQLiteClipboardHistoryStore(databaseURL: databaseURL)

        XCTAssertNil(try store.loadHistoryLimit())
    }

    func testDisplayLimitPersistsAcrossDatabaseInstances() throws {
        let databaseURL = makeDatabaseURL()
        defer { try? FileManager.default.removeItem(at: databaseURL.deletingLastPathComponent()) }

        try SQLiteClipboardHistoryStore(databaseURL: databaseURL).saveDisplayLimit(20)
        let restoredLimit = try SQLiteClipboardHistoryStore(databaseURL: databaseURL)
            .loadDisplayLimit()

        XCTAssertEqual(restoredLimit, 20)
    }

    private func makeDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("history.sqlite3")
    }
}
