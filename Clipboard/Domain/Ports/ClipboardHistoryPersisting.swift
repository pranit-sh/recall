@MainActor
protocol ClipboardHistoryPersisting: AnyObject {
    func load() throws -> [ClipboardItem]
    func save(_ items: [ClipboardItem]) throws
}
