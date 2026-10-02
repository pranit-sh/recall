import XCTest
@testable import Clipboard

final class ClipboardHistoryTests: XCTestCase {
    func testAddingItemsPlacesTheMostRecentItemFirst() {
        var history = ClipboardHistory(limit: 3)
        let firstItem = ClipboardItem(text: "First")
        let secondItem = ClipboardItem(text: "Second")

        history.add(firstItem)
        history.add(secondItem)

        XCTAssertEqual(history.items, [secondItem, firstItem])
    }

    func testAddingDuplicateContentMovesExistingItemToTheFront() {
        var history = ClipboardHistory(limit: 3)
        let originalDate = Date(timeIntervalSince1970: 1_000)
        let repeatedDate = Date(timeIntervalSince1970: 2_000)
        let originalItem = ClipboardItem(text: "First", createdAt: originalDate)
        let secondItem = ClipboardItem(text: "Second")
        let repeatedItem = ClipboardItem(text: " First ", createdAt: repeatedDate)

        history.add(originalItem)
        history.add(secondItem)
        history.add(repeatedItem)

        XCTAssertEqual(history.items.count, 2)
        XCTAssertEqual(history.items.map(\.id), [originalItem.id, secondItem.id])
        XCTAssertEqual(history.items.first?.text, "First")
        XCTAssertEqual(history.items.first?.lastUsedAt, repeatedDate)
    }

    func testAddingBeyondTheLimitRemovesTheLeastRecentItem() {
        var history = ClipboardHistory(limit: 2)
        let firstItem = ClipboardItem(text: "First")
        let secondItem = ClipboardItem(text: "Second")
        let thirdItem = ClipboardItem(text: "Third")

        history.add(firstItem)
        history.add(secondItem)
        history.add(thirdItem)

        XCTAssertEqual(history.items, [thirdItem, secondItem])
    }

    func testZeroLimitDoesNotRetainItems() {
        var history = ClipboardHistory(limit: 0)

        history.add(ClipboardItem(text: "Item"))

        XCTAssertTrue(history.items.isEmpty)
    }

    func testRestoredItemsAreSortedAndLimited() {
        let oldestItem = ClipboardItem(
            text: "Oldest",
            createdAt: Date(timeIntervalSince1970: 1),
            lastUsedAt: Date(timeIntervalSince1970: 1)
        )
        let middleItem = ClipboardItem(
            text: "Middle",
            createdAt: Date(timeIntervalSince1970: 2),
            lastUsedAt: Date(timeIntervalSince1970: 2)
        )
        let newestItem = ClipboardItem(
            text: "Newest",
            createdAt: Date(timeIntervalSince1970: 3),
            lastUsedAt: Date(timeIntervalSince1970: 3)
        )

        let history = ClipboardHistory(
            limit: 2,
            items: [oldestItem, newestItem, middleItem]
        )

        XCTAssertEqual(history.items, [newestItem, middleItem])
    }

    func testUpdatingLimitImmediatelyTrimsOldestItems() {
        var history = ClipboardHistory(limit: 3)
        let firstItem = ClipboardItem(text: "First")
        let secondItem = ClipboardItem(text: "Second")
        let thirdItem = ClipboardItem(text: "Third")
        history.add(firstItem)
        history.add(secondItem)
        history.add(thirdItem)

        history.updateLimit(2)

        XCTAssertEqual(history.limit, 2)
        XCTAssertEqual(history.items, [thirdItem, secondItem])
    }
}
