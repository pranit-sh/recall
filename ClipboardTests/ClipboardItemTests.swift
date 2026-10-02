import XCTest
@testable import Clipboard

final class ClipboardItemTests: XCTestCase {
    func testCreationPreservesTextAndUsesCreationDateAsInitialLastUsedDate() {
        let creationDate = Date(timeIntervalSince1970: 1_000)

        let item = ClipboardItem(text: "Hello", createdAt: creationDate)

        XCTAssertEqual(item.text, "Hello")
        XCTAssertEqual(item.createdAt, creationDate)
        XCTAssertEqual(item.lastUsedAt, creationDate)
    }

    func testItemsWithTheSameIdentifierAreEqual() {
        let identifier = UUID()
        let firstItem = ClipboardItem(id: identifier, text: "First")
        let secondItem = ClipboardItem(id: identifier, text: "Second")

        XCTAssertEqual(firstItem, secondItem)
    }

    func testItemsWithDifferentIdentifiersAreNotEqual() {
        let firstItem = ClipboardItem(text: "Same text")
        let secondItem = ClipboardItem(text: "Same text")

        XCTAssertNotEqual(firstItem, secondItem)
    }

    func testContentComparisonIgnoresSurroundingWhitespace() {
        let item = ClipboardItem(text: "Hello")

        XCTAssertTrue(item.hasSameContent(as: "Hello"))
        XCTAssertTrue(item.hasSameContent(as: " Hello "))
        XCTAssertTrue(item.hasSameContent(as: "\nHello\t"))
    }

    func testContentComparisonRemainsCaseSensitive() {
        let item = ClipboardItem(text: "Hello")

        XCTAssertFalse(item.hasSameContent(as: "hello"))
    }
}
