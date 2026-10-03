import AppKit
import CryptoKit

@MainActor
final class SystemPasteboard: PasteboardReading, PasteboardWriting {
    private static let maximumImageByteCount = 20 * 1_024 * 1_024
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    func readString() -> String? {
        pasteboard.string(forType: .string)
    }

    func readImage() -> ClipboardImageData? {
        let availableImage = [
            (NSPasteboard.PasteboardType.png, ClipboardImageFormat.png),
            (NSPasteboard.PasteboardType("public.jpeg"), ClipboardImageFormat.jpeg),
            (.tiff, ClipboardImageFormat.tiff)
        ]
        .compactMap { type, format -> (Data, ClipboardImageFormat)? in
            pasteboard.data(forType: type).map { ($0, format) }
        }
        .first

        guard let (data, format) = availableImage,
              !data.isEmpty,
              data.count <= Self.maximumImageByteCount,
              let representation = NSBitmapImageRep(data: data) else {
            return nil
        }

        return ClipboardImageData(
            data: data,
            contentHash: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            pixelWidth: representation.pixelsWide,
            pixelHeight: representation.pixelsHigh,
            format: format
        )
    }

    func writeString(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func writeImage(_ data: Data, format: ClipboardImageFormat) {
        guard let image = NSImage(data: data) else { return }
        let pasteboardType: NSPasteboard.PasteboardType = switch format {
        case .png: .png
        case .jpeg: NSPasteboard.PasteboardType("public.jpeg")
        case .tiff: .tiff
        }

        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        pasteboard.setData(data, forType: pasteboardType)
    }

}
