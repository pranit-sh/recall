@MainActor
protocol PasteboardWriting: AnyObject {
    func writeString(_ text: String)
}
