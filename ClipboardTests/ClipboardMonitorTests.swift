import XCTest
@testable import Clipboard

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    func testExistingPasteboardContentIsNotAddedAtInitialization() {
        let pasteboard = PasteboardStub(changeCount: 1, text: "Existing")
        let monitor = makeMonitor(pasteboard: pasteboard)

        monitor.checkForChanges()

        XCTAssertTrue(monitor.history.items.isEmpty)
    }

    func testChangedPasteboardAddsTrimmedTextToHistory() {
        let pasteboard = PasteboardStub()
        let monitor = makeMonitor(pasteboard: pasteboard)
        pasteboard.simulateChange(to: " \nNew text\t ")

        monitor.checkForChanges()

        XCTAssertEqual(monitor.history.items.map(\.text), ["New text"])
    }

    func testStartPollsForPasteboardChanges() async throws {
        let pasteboard = PasteboardStub()
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            history: ClipboardHistory(limit: 10),
            pollInterval: 0.01
        )
        defer { monitor.stop() }

        monitor.start()
        pasteboard.simulateChange(to: "Polled text")
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(monitor.history.items.map(\.text), ["Polled text"])
    }

    func testPasteboardChangeIsProcessedOnlyOnce() {
        let pasteboard = PasteboardStub()
        let monitor = makeMonitor(pasteboard: pasteboard)
        pasteboard.simulateChange(to: "New text")

        monitor.checkForChanges()
        monitor.checkForChanges()

        XCTAssertEqual(monitor.history.items.count, 1)
    }

    func testNonTextPasteboardChangeIsIgnored() {
        let pasteboard = PasteboardStub()
        let monitor = makeMonitor(pasteboard: pasteboard)
        pasteboard.simulateChange(to: nil)

        monitor.checkForChanges()

        XCTAssertTrue(monitor.history.items.isEmpty)
    }

    func testWhitespaceOnlyPasteboardChangeIsIgnored() {
        let pasteboard = PasteboardStub()
        let monitor = makeMonitor(pasteboard: pasteboard)
        pasteboard.simulateChange(to: " \n\t ")

        monitor.checkForChanges()

        XCTAssertTrue(monitor.history.items.isEmpty)
    }

    func testWhitespaceEquivalentChangesUseHistoryDeduplication() {
        let pasteboard = PasteboardStub()
        let monitor = makeMonitor(pasteboard: pasteboard)

        pasteboard.simulateChange(to: "Text")
        monitor.checkForChanges()
        pasteboard.simulateChange(to: " Text ")
        monitor.checkForChanges()

        XCTAssertEqual(monitor.history.items.count, 1)
        XCTAssertEqual(monitor.history.items.first?.text, "Text")
    }

    func testChangedPasteboardPersistsUpdatedHistory() {
        let pasteboard = PasteboardStub()
        let persistence = HistoryPersistenceStub()
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            history: ClipboardHistory(limit: 10),
            persistence: persistence
        )
        pasteboard.simulateChange(to: "Persisted")

        monitor.checkForChanges()

        XCTAssertEqual(persistence.savedItems.map(\.text), ["Persisted"])
    }

    func testPersistenceFailureDoesNotDiscardCapturedItem() {
        let pasteboard = PasteboardStub()
        let persistence = HistoryPersistenceStub(saveError: TestError.saveFailed)
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            history: ClipboardHistory(limit: 10),
            persistence: persistence
        )
        pasteboard.simulateChange(to: "Still captured")

        monitor.checkForChanges()

        XCTAssertEqual(monitor.history.items.map(\.text), ["Still captured"])
        XCTAssertNotNil(monitor.persistenceError)
    }

    func testIgnoredApplicationContentIsNeverAddedAfterSwitchingApps() {
        let pasteboard = PasteboardStub()
        let applicationProvider = MonitorApplicationProviderStub(
            bundleIdentifier: "com.example.private"
        )
        let privacySettings = PrivacySettings(
            ignoredApplicationBundleIdentifiers: ["com.example.private"]
        )
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            history: ClipboardHistory(limit: 10),
            activeApplicationProvider: applicationProvider,
            privacySettings: privacySettings
        )
        pasteboard.simulateChange(to: "Secret")

        monitor.checkForChanges()
        applicationProvider.bundleIdentifier = "com.example.allowed"
        monitor.checkForChanges()

        XCTAssertTrue(monitor.history.items.isEmpty)
    }

    func testClearHistoryAlsoPersistsEmptySnapshot() {
        let pasteboard = PasteboardStub()
        let persistence = HistoryPersistenceStub()
        var history = ClipboardHistory(limit: 10)
        history.add(ClipboardItem(text: "Item"))
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            history: history,
            persistence: persistence
        )

        monitor.clearHistory()

        XCTAssertTrue(monitor.history.items.isEmpty)
        XCTAssertTrue(persistence.savedItems.isEmpty)
    }

    func testUpdatingHistoryLimitTrimsAndPersistsImmediately() {
        let pasteboard = PasteboardStub()
        let persistence = HistoryPersistenceStub()
        var history = ClipboardHistory(limit: 3)
        history.add(ClipboardItem(text: "First"))
        history.add(ClipboardItem(text: "Second"))
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            history: history,
            persistence: persistence
        )

        monitor.updateHistoryLimit(1)

        XCTAssertEqual(monitor.history.limit, 1)
        XCTAssertEqual(monitor.history.items.map(\.text), ["Second"])
        XCTAssertEqual(persistence.savedItems.map(\.text), ["Second"])
    }

    private func makeMonitor(pasteboard: PasteboardStub) -> ClipboardMonitor {
        ClipboardMonitor(
            pasteboard: pasteboard,
            history: ClipboardHistory(limit: 10)
        )
    }
}

@MainActor
private final class HistoryPersistenceStub: ClipboardHistoryPersisting {
    private let saveError: Error?
    private(set) var savedItems: [ClipboardItem] = []

    init(saveError: Error? = nil) {
        self.saveError = saveError
    }

    func load() throws -> [ClipboardItem] {
        []
    }

    func save(_ items: [ClipboardItem]) throws {
        if let saveError {
            throw saveError
        }

        savedItems = items
    }
}

private enum TestError: Error {
    case saveFailed
}

@MainActor
private final class MonitorApplicationProviderStub: ActiveApplicationProviding {
    var bundleIdentifier: String?

    init(bundleIdentifier: String?) {
        self.bundleIdentifier = bundleIdentifier
    }

    func frontmostApplicationBundleIdentifier() -> String? {
        bundleIdentifier
    }
}

@MainActor
private final class PasteboardStub: PasteboardReading {
    private(set) var changeCount: Int
    private var text: String?

    init(changeCount: Int = 0, text: String? = nil) {
        self.changeCount = changeCount
        self.text = text
    }

    func readString() -> String? {
        text
    }

    func simulateChange(to text: String?) {
        changeCount += 1
        self.text = text
    }
}
