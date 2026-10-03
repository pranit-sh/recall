import Foundation

@MainActor
protocol PasteboardWriting: AnyObject {
    func writeString(_ text: String)
    func writeImage(_ data: Data, format: ClipboardImageFormat)
}

extension PasteboardWriting {
    func writeImage(_ data: Data, format: ClipboardImageFormat) {}
}
