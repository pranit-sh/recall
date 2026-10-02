@MainActor
protocol PasteboardReading: AnyObject {
    var changeCount: Int { get }

    func readString() -> String?
}
