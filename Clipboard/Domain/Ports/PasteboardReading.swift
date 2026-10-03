@MainActor
protocol PasteboardReading: AnyObject {
    var changeCount: Int { get }

    func readString() -> String?
    func readImage() -> ClipboardImageData?
}

extension PasteboardReading {
    func readImage() -> ClipboardImageData? { nil }
}
