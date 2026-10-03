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

    func testImageHistoryKeepsOnlyTenMostRecentImages() {
        var history = ClipboardHistory(limit: 20)

        for index in 0..<12 {
            history.add(makeImageItem(hash: "image-\(index)"))
        }

        XCTAssertEqual(history.items.compactMap(\.image).count, 10)
        XCTAssertEqual(history.items.first?.image?.contentHash, "image-11")
        XCTAssertEqual(history.items.last?.image?.contentHash, "image-2")
    }

    func testImageHistoryRespectsTotalByteLimit() {
        var history = ClipboardHistory(limit: 10, imageByteLimit: 100)

        history.add(makeImageItem(hash: "first", byteCount: 60))
        history.add(makeImageItem(hash: "second", byteCount: 60))

        XCTAssertEqual(history.items.compactMap(\.image).map(\.contentHash), ["second"])
    }

    func testTextAndImageCountsAreLimitedIndependently() {
        var history = ClipboardHistory(limit: 1, imageLimit: 2)

        history.add(ClipboardItem(text: "First"))
        history.add(makeImageItem(hash: "first-image"))
        history.add(ClipboardItem(text: "Second"))
        history.add(makeImageItem(hash: "second-image"))

        XCTAssertEqual(history.items.filter { $0.image == nil }.map(\.text), ["Second"])
        XCTAssertEqual(history.items.compactMap(\.image).count, 2)
        XCTAssertEqual(history.items.count, 3)
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

        history.updateTextLimit(2)

        XCTAssertEqual(history.textLimit, 2)
        XCTAssertEqual(history.items, [thirdItem, secondItem])
    }

    private func makeImageItem(hash: String, byteCount: Int = 1) -> ClipboardItem {
        ClipboardItem(
            image: ClipboardImage(
                storageIdentifier: "\(hash).png",
                contentHash: hash,
                pixelWidth: 10,
                pixelHeight: 10,
                byteCount: byteCount,
                format: .png
            )
        )
    }
}
