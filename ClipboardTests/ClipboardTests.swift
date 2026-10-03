import AppKit
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

    @MainActor
    func testSystemPasteboardWritesAndReadsPNGImage() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        let systemPasteboard = SystemPasteboard(pasteboard: pasteboard)
        let bitmap = try XCTUnwrap(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 1,
                pixelsHigh: 1,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        bitmap.setColor(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 1), atX: 0, y: 0)
        let imageData = try XCTUnwrap(
            bitmap.representation(using: .png, properties: [:])
        )

        systemPasteboard.writeImage(imageData, format: .png)

        XCTAssertEqual(pasteboard.data(forType: .png), imageData)
        XCTAssertEqual(systemPasteboard.readImage()?.data, imageData)
        XCTAssertNotNil(NSImage(pasteboard: pasteboard))
    }

    @MainActor
    func testImagePreviewAppearsToRightOfPopoverWhenSpaceIsAvailable() {
        let sourceFrame = CGRect(x: 100, y: 100, width: 320, height: 400)

        let origin = ClipboardImagePreviewController.previewOrigin(
            panelSize: CGSize(width: 200, height: 150),
            sourceFrame: sourceFrame,
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            mouseLocation: CGPoint(x: 200, y: 300)
        )

        XCTAssertEqual(origin.x, sourceFrame.maxX + 8)
    }

    @MainActor
    func testImagePreviewMovesToLeftOfPopoverNearRightScreenEdge() {
        let sourceFrame = CGRect(x: 680, y: 100, width: 320, height: 400)

        let origin = ClipboardImagePreviewController.previewOrigin(
            panelSize: CGSize(width: 200, height: 150),
            sourceFrame: sourceFrame,
            visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            mouseLocation: CGPoint(x: 800, y: 300)
        )

        XCTAssertEqual(origin.x, sourceFrame.minX - 208)
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
