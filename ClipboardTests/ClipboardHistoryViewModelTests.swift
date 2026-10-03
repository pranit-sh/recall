import XCTest
@testable import Clipboard

@MainActor
final class ClipboardHistoryViewModelTests: XCTestCase {
    func testItemsUpdateWhenMonitorReceivesClipboardText() {
        let pasteboard = ViewModelPasteboardStub()
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            history: ClipboardHistory(limit: 10)
        )
        let viewModel = ClipboardHistoryViewModel(
            monitor: monitor,
            pasteboard: pasteboard,
            popoverDismisser: ViewModelPopoverDismisserStub()
        )

        pasteboard.simulateChange(to: "New text")
        monitor.checkForChanges()

        XCTAssertEqual(viewModel.items.map(\.text), ["New text"])
        XCTAssertNil(viewModel.selectedItemID)
    }

    func testSelectingItemWritesOriginalTextToPasteboard() {
        let pasteboard = ViewModelPasteboardStub()
        let popoverDismisser = ViewModelPopoverDismisserStub()
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            history: ClipboardHistory(limit: 10)
        )
        let viewModel = ClipboardHistoryViewModel(
            monitor: monitor,
            pasteboard: pasteboard,
            popoverDismisser: popoverDismisser
        )
        let item = ClipboardItem(text: " Original text ")

        viewModel.select(item)

        XCTAssertEqual(pasteboard.writtenText, " Original text ")
        XCTAssertEqual(popoverDismisser.dismissCallCount, 1)
    }

    func testSelectingImageWritesStoredDataToPasteboard() {
        let pasteboard = ViewModelPasteboardStub()
        let popoverDismisser = ViewModelPopoverDismisserStub()
        let imageStore = ViewModelImageStoreStub(data: Data([1, 2, 3]))
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            history: ClipboardHistory(limit: 10)
        )
        let viewModel = ClipboardHistoryViewModel(
            monitor: monitor,
            pasteboard: pasteboard,
            imageStore: imageStore,
            popoverDismisser: popoverDismisser
        )
        let item = ClipboardItem(image: makeViewModelImage())

        viewModel.select(item)

        XCTAssertEqual(pasteboard.writtenImageData, Data([1, 2, 3]))
        XCTAssertEqual(pasteboard.writtenImageFormat, .png)
        XCTAssertEqual(popoverDismisser.dismissCallCount, 1)
    }

    func testSearchFiltersCaseInsensitivelyAndPreservesMRUOrder() {
        let pasteboard = ViewModelPasteboardStub()
        var history = ClipboardHistory(limit: 10)
        let olderMatch = ClipboardItem(text: "First MATCH")
        let nonMatch = ClipboardItem(text: "Other")
        let newerMatch = ClipboardItem(text: "Latest match")
        history.add(olderMatch)
        history.add(nonMatch)
        history.add(newerMatch)
        let viewModel = makeViewModel(history: history, pasteboard: pasteboard)

        viewModel.searchText = " match "

        XCTAssertEqual(viewModel.filteredItems, [newerMatch, olderMatch])
        XCTAssertNil(viewModel.selectedItemID)
    }

    func testSearchMatchesImageDisplayLabel() {
        let pasteboard = ViewModelPasteboardStub()
        let imageItem = ClipboardItem(image: makeViewModelImage())
        let viewModel = makeViewModel(
            history: ClipboardHistory(limit: 10, items: [imageItem]),
            pasteboard: pasteboard
        )

        viewModel.searchText = "640"

        XCTAssertEqual(viewModel.filteredItems, [imageItem])
    }

    func testDisplayLimitCapsResultsWithoutHidingSearchMatches() {
        let pasteboard = ViewModelPasteboardStub()
        var history = ClipboardHistory(limit: 10)
        (0..<8).forEach { history.add(ClipboardItem(text: "Item \($0)")) }
        let viewModel = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(pasteboard: pasteboard, history: history),
            pasteboard: pasteboard,
            popoverDismisser: ViewModelPopoverDismisserStub(),
            displayLimit: 5
        )

        XCTAssertEqual(viewModel.displayedItems.map(\.text), [
            "Item 7", "Item 6", "Item 5", "Item 4", "Item 3"
        ])

        viewModel.searchText = "Item 0"

        XCTAssertEqual(viewModel.displayedItems.map(\.text), ["Item 0"])
    }

    func testKeyboardSelectionStaysWithinDisplayedItems() {
        let pasteboard = ViewModelPasteboardStub()
        var history = ClipboardHistory(limit: 10)
        (0..<8).forEach { history.add(ClipboardItem(text: "Item \($0)")) }
        let viewModel = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(pasteboard: pasteboard, history: history),
            pasteboard: pasteboard,
            popoverDismisser: ViewModelPopoverDismisserStub(),
            displayLimit: 5
        )

        (0..<8).forEach { _ in viewModel.moveSelection(by: 1) }

        XCTAssertEqual(viewModel.selectedItem?.text, "Item 3")
    }

    func testMovingSelectionStaysWithinFilteredResults() {
        let pasteboard = ViewModelPasteboardStub()
        var history = ClipboardHistory(limit: 10)
        let firstItem = ClipboardItem(text: "First")
        let secondItem = ClipboardItem(text: "Second")
        history.add(firstItem)
        history.add(secondItem)
        let viewModel = makeViewModel(history: history, pasteboard: pasteboard)

        XCTAssertNil(viewModel.selectedItemID)

        viewModel.moveSelection(by: 1)
        XCTAssertEqual(viewModel.selectedItemID, secondItem.id)

        viewModel.moveSelection(by: 1)
        XCTAssertEqual(viewModel.selectedItemID, firstItem.id)

        viewModel.moveSelection(by: 1)
        XCTAssertEqual(viewModel.selectedItemID, firstItem.id)

        viewModel.moveSelection(by: -1)
        XCTAssertEqual(viewModel.selectedItemID, secondItem.id)
    }

    func testClearingSelectionRemovesKeyboardFocus() {
        let pasteboard = ViewModelPasteboardStub()
        var history = ClipboardHistory(limit: 10)
        history.add(ClipboardItem(text: "Item"))
        let viewModel = makeViewModel(history: history, pasteboard: pasteboard)
        viewModel.moveSelection(by: 1)

        viewModel.clearSelection()

        XCTAssertNil(viewModel.selectedItemID)
    }

    func testSelectingCurrentItemCopiesAndDismisses() {
        let pasteboard = ViewModelPasteboardStub()
        let popoverDismisser = ViewModelPopoverDismisserStub()
        var history = ClipboardHistory(limit: 10)
        let item = ClipboardItem(text: "Selected")
        history.add(item)
        let monitor = ClipboardMonitor(pasteboard: pasteboard, history: history)
        let viewModel = ClipboardHistoryViewModel(
            monitor: monitor,
            pasteboard: pasteboard,
            popoverDismisser: popoverDismisser
        )

        viewModel.moveSelection(by: 1)
        viewModel.selectCurrentItem()

        XCTAssertEqual(pasteboard.writtenText, "Selected")
        XCTAssertEqual(popoverDismisser.dismissCallCount, 1)
    }

    func testPreparingForPresentationRanksForTheActiveApplication() {
        let pasteboard = ViewModelPasteboardStub()
        let applicationProvider = ActiveApplicationProviderStub(
            bundleIdentifier: "com.example.editor"
        )
        let usagePersistence = UsagePersistenceStub()
        var history = ClipboardHistory(limit: 10)
        let items = (0..<5).map { ClipboardItem(text: "Item \($0)") }
        items.reversed().forEach { history.add($0) }
        usagePersistence.usage = [
            ClipboardItemUsage(
                itemID: items[4].id,
                applicationBundleIdentifier: "com.example.editor",
                selectionCount: 10,
                lastSelectedAt: Date()
            )
        ]
        let viewModel = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(pasteboard: pasteboard, history: history),
            pasteboard: pasteboard,
            popoverDismisser: ViewModelPopoverDismisserStub(),
            activeApplicationProvider: applicationProvider,
            usagePersistence: usagePersistence
        )

        viewModel.prepareForPresentation()

        XCTAssertEqual(viewModel.filteredItems.map(\.id), [
            items[0].id, items[1].id, items[2].id, items[4].id, items[3].id
        ])
        XCTAssertEqual(usagePersistence.loadedApplicationID, "com.example.editor")
    }

    func testSelectionRecordsUsageForTheActiveApplication() {
        let pasteboard = ViewModelPasteboardStub()
        let usagePersistence = UsagePersistenceStub()
        let selectionDate = Date(timeIntervalSince1970: 500)
        let item = ClipboardItem(text: "Selected")
        var history = ClipboardHistory(limit: 10)
        history.add(item)
        let viewModel = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(pasteboard: pasteboard, history: history),
            pasteboard: pasteboard,
            popoverDismisser: ViewModelPopoverDismisserStub(),
            activeApplicationProvider: ActiveApplicationProviderStub(
                bundleIdentifier: "com.example.editor"
            ),
            usagePersistence: usagePersistence,
            now: { selectionDate }
        )
        viewModel.prepareForPresentation()

        viewModel.select(item)

        XCTAssertEqual(usagePersistence.recordedItemID, item.id)
        XCTAssertEqual(usagePersistence.recordedApplicationID, "com.example.editor")
        XCTAssertEqual(usagePersistence.recordedDate, selectionDate)
    }

    func testUsageLoadFailureFallsBackToMRUOrder() {
        let pasteboard = ViewModelPasteboardStub()
        let usagePersistence = UsagePersistenceStub(loadError: ViewModelTestError.loadFailed)
        var history = ClipboardHistory(limit: 10)
        let firstItem = ClipboardItem(text: "First")
        let secondItem = ClipboardItem(text: "Second")
        history.add(firstItem)
        history.add(secondItem)
        let viewModel = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(pasteboard: pasteboard, history: history),
            pasteboard: pasteboard,
            popoverDismisser: ViewModelPopoverDismisserStub(),
            activeApplicationProvider: ActiveApplicationProviderStub(
                bundleIdentifier: "com.example.editor"
            ),
            usagePersistence: usagePersistence
        )

        viewModel.prepareForPresentation()

        XCTAssertEqual(viewModel.filteredItems, [secondItem, firstItem])
        XCTAssertNotNil(viewModel.contextualRankingError)
    }

    func testIgnoringAndAllowingCurrentApplicationUpdatesPrivacyState() {
        let pasteboard = ViewModelPasteboardStub()
        let privacySettings = PrivacySettings()
        let popoverDismisser = ViewModelPopoverDismisserStub()
        let viewModel = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(
                pasteboard: pasteboard,
                history: ClipboardHistory(limit: 10)
            ),
            pasteboard: pasteboard,
            popoverDismisser: popoverDismisser,
            activeApplicationProvider: ActiveApplicationProviderStub(
                bundleIdentifier: "com.example.private"
            ),
            privacySettings: privacySettings
        )
        viewModel.prepareForPresentation()

        viewModel.ignoreCurrentApplication()

        XCTAssertEqual(viewModel.ignoredApplicationBundleIdentifiers, ["com.example.private"])
        XCTAssertEqual(popoverDismisser.dismissCallCount, 1)

        viewModel.allowApplication("com.example.private")

        XCTAssertTrue(viewModel.ignoredApplicationBundleIdentifiers.isEmpty)
    }

    func testPrivacyToggleReflectsCurrentApplicationState() {
        let pasteboard = ViewModelPasteboardStub()
        let privacySettings = PrivacySettings()
        let popoverDismisser = ViewModelPopoverDismisserStub()
        let viewModel = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(
                pasteboard: pasteboard,
                history: ClipboardHistory(limit: 10)
            ),
            pasteboard: pasteboard,
            popoverDismisser: popoverDismisser,
            activeApplicationProvider: ActiveApplicationProviderStub(
                bundleIdentifier: "com.example.private",
                displayName: "Private App"
            ),
            privacySettings: privacySettings
        )
        viewModel.prepareForPresentation()

        XCTAssertFalse(viewModel.isCurrentApplicationIgnored)
        XCTAssertEqual(viewModel.currentApplicationPrivacyActionTitle, "Ignore Private App")

        viewModel.toggleCurrentApplicationPrivacy()
        XCTAssertTrue(viewModel.isCurrentApplicationIgnored)
        XCTAssertEqual(viewModel.currentApplicationPrivacyActionTitle, "Ignore Private App")

        viewModel.toggleCurrentApplicationPrivacy()
        XCTAssertFalse(viewModel.isCurrentApplicationIgnored)
        XCTAssertEqual(popoverDismisser.dismissCallCount, 2)
    }

    func testPrivacyActionTitleFallsBackToBundleIdentifier() {
        let pasteboard = ViewModelPasteboardStub()
        let viewModel = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(
                pasteboard: pasteboard,
                history: ClipboardHistory(limit: 10)
            ),
            pasteboard: pasteboard,
            popoverDismisser: ViewModelPopoverDismisserStub(),
            activeApplicationProvider: ActiveApplicationProviderStub(
                bundleIdentifier: "com.example.unknown"
            ),
            privacySettings: PrivacySettings()
        )

        viewModel.prepareForPresentation()

        XCTAssertEqual(
            viewModel.currentApplicationPrivacyActionTitle,
            "Ignore com.example.unknown"
        )
    }

    func testSearchPromptDescribesSearchableHistorySize() {
        let pasteboard = ViewModelPasteboardStub()
        let items = (1...3).map { ClipboardItem(text: "Item \($0)") }
        let viewModel = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(
                pasteboard: pasteboard,
                history: ClipboardHistory(limit: 10, items: items)
            ),
            pasteboard: pasteboard,
            popoverDismisser: ViewModelPopoverDismisserStub(),
            displayLimit: 2
        )

        XCTAssertEqual(viewModel.searchPrompt, "Search 3 items")
    }

    func testSelectionInIgnoredApplicationDoesNotRecordUsage() {
        let pasteboard = ViewModelPasteboardStub()
        let usagePersistence = UsagePersistenceStub()
        let privacySettings = PrivacySettings(
            ignoredApplicationBundleIdentifiers: ["com.example.private"]
        )
        let item = ClipboardItem(text: "Selected")
        let viewModel = ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(
                pasteboard: pasteboard,
                history: ClipboardHistory(limit: 10, items: [item])
            ),
            pasteboard: pasteboard,
            popoverDismisser: ViewModelPopoverDismisserStub(),
            activeApplicationProvider: ActiveApplicationProviderStub(
                bundleIdentifier: "com.example.private"
            ),
            usagePersistence: usagePersistence,
            privacySettings: privacySettings
        )
        viewModel.prepareForPresentation()

        viewModel.select(item)

        XCTAssertNil(usagePersistence.recordedItemID)
        XCTAssertEqual(pasteboard.writtenText, "Selected")
    }

    private func makeViewModel(
        history: ClipboardHistory,
        pasteboard: ViewModelPasteboardStub
    ) -> ClipboardHistoryViewModel {
        ClipboardHistoryViewModel(
            monitor: ClipboardMonitor(pasteboard: pasteboard, history: history),
            pasteboard: pasteboard,
            popoverDismisser: ViewModelPopoverDismisserStub()
        )
    }
}

private func makeViewModelImage() -> ClipboardImage {
    ClipboardImage(
        storageIdentifier: "image.png",
        contentHash: "image-hash",
        pixelWidth: 640,
        pixelHeight: 480,
        byteCount: 3,
        format: .png
    )
}

@MainActor
private final class ViewModelPasteboardStub: PasteboardReading, PasteboardWriting {
    private(set) var changeCount = 0
    private(set) var writtenText: String?
    private(set) var writtenImageData: Data?
    private(set) var writtenImageFormat: ClipboardImageFormat?
    private var text: String?

    func readString() -> String? {
        text
    }

    func writeString(_ text: String) {
        writtenText = text
    }

    func writeImage(_ data: Data, format: ClipboardImageFormat) {
        writtenImageData = data
        writtenImageFormat = format
    }

    func simulateChange(to text: String) {
        changeCount += 1
        self.text = text
    }
}

@MainActor
private final class ViewModelImageStoreStub: ClipboardImageStoring {
    private let data: Data

    init(data: Data) {
        self.data = data
    }

    func store(_ image: ClipboardImageData) throws -> ClipboardImage {
        makeViewModelImage()
    }

    func load(_ image: ClipboardImage) throws -> Data { data }
    func remove(_ image: ClipboardImage) throws {}
}

@MainActor
private final class ViewModelPopoverDismisserStub: PopoverDismissing {
    private(set) var dismissCallCount = 0

    func dismissPopover() {
        dismissCallCount += 1
    }
}

@MainActor
private final class ActiveApplicationProviderStub: ActiveApplicationProviding {
    private let bundleIdentifier: String?
    private let displayName: String?

    init(bundleIdentifier: String?, displayName: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }

    func frontmostApplicationBundleIdentifier() -> String? {
        bundleIdentifier
    }

    func applicationDisplayName(for bundleIdentifier: String) -> String? {
        displayName
    }
}

@MainActor
private final class UsagePersistenceStub: ClipboardUsagePersisting {
    var usage: [ClipboardItemUsage] = []
    private let loadError: Error?
    private(set) var loadedApplicationID: String?
    private(set) var recordedItemID: ClipboardItem.ID?
    private(set) var recordedApplicationID: String?
    private(set) var recordedDate: Date?

    init(loadError: Error? = nil) {
        self.loadError = loadError
    }

    func loadUsage(for applicationBundleIdentifier: String) throws -> [ClipboardItemUsage] {
        loadedApplicationID = applicationBundleIdentifier
        if let loadError {
            throw loadError
        }
        return usage
    }

    func recordSelection(
        of itemID: ClipboardItem.ID,
        for applicationBundleIdentifier: String,
        at date: Date
    ) throws {
        recordedItemID = itemID
        recordedApplicationID = applicationBundleIdentifier
        recordedDate = date
    }
}

private enum ViewModelTestError: Error {
    case loadFailed
}
