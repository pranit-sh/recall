import AppKit
import ImageIO
import SwiftUI

@MainActor
protocol ClipboardImagePreviewProviding: AnyObject {
    func preview(for image: ClipboardImage) -> NSImage?
}

@MainActor
final class ClipboardImagePreviewProvider: ClipboardImagePreviewProviding {
    private let imageStore: ClipboardImageStoring?
    private let cache = NSCache<NSString, NSImage>()

    init(imageStore: ClipboardImageStoring?) {
        self.imageStore = imageStore
        cache.countLimit = 10
    }

    func preview(for image: ClipboardImage) -> NSImage? {
        let key = image.storageIdentifier as NSString
        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }

        guard let data = try? imageStore?.load(image),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                  source,
                  0,
                  [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                      kCGImageSourceThumbnailMaxPixelSize: 640
                  ] as CFDictionary
              ) else {
            return nil
        }

        let preview = NSImage(cgImage: thumbnail, size: .zero)
        cache.setObject(preview, forKey: key)
        return preview
    }
}

@MainActor
protocol ClipboardImagePreviewPresenting: AnyObject {
    func presentPreview(for image: ClipboardImage)
    func dismissPreview()
}

@MainActor
final class ClipboardImagePreviewController: ClipboardImagePreviewPresenting {
    private let previewProvider: ClipboardImagePreviewProviding
    private var panel: NSPanel?

    init(previewProvider: ClipboardImagePreviewProviding) {
        self.previewProvider = previewProvider
    }

    func presentPreview(for image: ClipboardImage) {
        guard let previewImage = previewProvider.preview(for: image) else { return }

        let previewSize = fittedSize(for: previewImage)
        let contentView = NSHostingView(
            rootView: Image(nsImage: previewImage)
                .resizable()
                .scaledToFit()
                .frame(width: previewSize.width, height: previewSize.height)
                .padding(6)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        )
        let panelSize = CGSize(width: previewSize.width + 12, height: previewSize.height + 12)
        let panel = panel ?? makePanel()
        panel.contentView = contentView
        panel.setContentSize(panelSize)
        panel.setFrameOrigin(origin(for: panelSize))
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func dismissPreview() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.ignoresMouseEvents = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .ignoresCycle]
        return panel
    }

    private func fittedSize(for image: NSImage) -> CGSize {
        let maximumSize = CGSize(width: 320, height: 240)
        guard image.size.width > 0, image.size.height > 0 else { return maximumSize }
        let scale = min(
            maximumSize.width / image.size.width,
            maximumSize.height / image.size.height,
            1
        )
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }

    private func origin(for panelSize: CGSize) -> CGPoint {
        let mouseLocation = NSEvent.mouseLocation
        let visibleFrame = NSScreen.screens
            .first(where: { $0.frame.contains(mouseLocation) })?
            .visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let sourceFrame = NSApp.windows.first {
            $0 !== panel && $0.isVisible && $0.frame.contains(mouseLocation)
        }?.frame ?? CGRect(origin: mouseLocation, size: .zero)

        return Self.previewOrigin(
            panelSize: panelSize,
            sourceFrame: sourceFrame,
            visibleFrame: visibleFrame,
            mouseLocation: mouseLocation
        )
    }

    static func previewOrigin(
        panelSize: CGSize,
        sourceFrame: CGRect,
        visibleFrame: CGRect,
        mouseLocation: CGPoint
    ) -> CGPoint {
        let spacing: CGFloat = 8
        let rightX = sourceFrame.maxX + spacing
        let leftX = sourceFrame.minX - panelSize.width - spacing
        let x = rightX + panelSize.width <= visibleFrame.maxX
            ? rightX
            : max(leftX, visibleFrame.minX)
        let maximumY = max(visibleFrame.minY, visibleFrame.maxY - panelSize.height)
        let y = min(
            max(mouseLocation.y - panelSize.height / 2, visibleFrame.minY),
            maximumY
        )
        return CGPoint(x: x, y: y)
    }
}