import XCTest
@testable import Clipboard

final class ContextualClipboardRankerTests: XCTestCase {
    private let applicationID = "com.example.editor"
    private let now = Date(timeIntervalSince1970: 10_000)

    func testThreeMostRecentItemsRemainFirst() {
        let items = makeItems(count: 5)
        let usage = makeUsage(for: items[4], count: 100)

        let rankedItems = ContextualClipboardRanker().rank(
            items,
            usage: [usage],
            for: applicationID,
            now: now
        )

        XCTAssertEqual(Array(rankedItems.prefix(3)), Array(items.prefix(3)))
        XCTAssertEqual(rankedItems[3], items[4])
    }

    func testAtMostTwoContextualItemsArePromoted() {
        let items = makeItems(count: 7)
        let usage = [
            makeUsage(for: items[4], count: 20),
            makeUsage(for: items[5], count: 10),
            makeUsage(for: items[6], count: 5)
        ]

        let rankedItems = ContextualClipboardRanker().rank(
            items,
            usage: usage,
            for: applicationID,
            now: now
        )

        XCTAssertEqual(rankedItems.map(\.id), [
            items[0].id, items[1].id, items[2].id,
            items[4].id, items[5].id,
            items[3].id, items[6].id
        ])
    }

    func testRecentFrequentUsageRanksAboveStaleUsage() {
        let items = makeItems(count: 5)
        let staleUsage = ClipboardItemUsage(
            itemID: items[3].id,
            applicationBundleIdentifier: applicationID,
            selectionCount: 100,
            lastSelectedAt: now.addingTimeInterval(-180 * 24 * 60 * 60)
        )
        let recentUsage = makeUsage(for: items[4], count: 3)

        let rankedItems = ContextualClipboardRanker().rank(
            items,
            usage: [staleUsage, recentUsage],
            for: applicationID,
            now: now
        )

        XCTAssertEqual(Array(rankedItems.dropFirst(3).prefix(2)), [items[4], items[3]])
    }

    func testUsageFromAnotherApplicationDoesNotChangeOrder() {
        let items = makeItems(count: 5)
        let usage = ClipboardItemUsage(
            itemID: items[4].id,
            applicationBundleIdentifier: "com.example.browser",
            selectionCount: 100,
            lastSelectedAt: now
        )

        let rankedItems = ContextualClipboardRanker().rank(
            items,
            usage: [usage],
            for: applicationID,
            now: now
        )

        XCTAssertEqual(rankedItems, items)
    }

    func testEqualScoresPreserveMRUOrder() {
        let items = makeItems(count: 5)
        let usage = [
            makeUsage(for: items[3], count: 2),
            makeUsage(for: items[4], count: 2)
        ]

        let rankedItems = ContextualClipboardRanker().rank(
            items,
            usage: usage,
            for: applicationID,
            now: now
        )

        XCTAssertEqual(rankedItems, items)
    }

    private func makeItems(count: Int) -> [ClipboardItem] {
        (0..<count).map { ClipboardItem(text: "Item \($0)") }
    }

    private func makeUsage(for item: ClipboardItem, count: Int) -> ClipboardItemUsage {
        ClipboardItemUsage(
            itemID: item.id,
            applicationBundleIdentifier: applicationID,
            selectionCount: count,
            lastSelectedAt: now
        )
    }
}
