import XCTest
@testable import Clipboard

final class ClipboardTests: XCTestCase {
    @MainActor
    func testMenuBarRootViewCanBeCreated() {
        let pasteboard = RootViewPasteboardStub()
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            history: ClipboardHistory(limit: 10)
        )
        let viewModel = ClipboardHistoryViewModel(
            monitor: monitor,
            pasteboard: pasteboard,
            popoverDismisser: RootViewPopoverDismisserStub()
        )

        XCTAssertNotNil(MenuBarRootView(viewModel: viewModel))
    }
}

@MainActor
private final class RootViewPasteboardStub: PasteboardReading, PasteboardWriting {
    let changeCount = 0

    func readString() -> String? {
        nil
    }

    func writeString(_ text: String) {}
}

@MainActor
private final class RootViewPopoverDismisserStub: PopoverDismissing {
    func dismissPopover() {}
}
