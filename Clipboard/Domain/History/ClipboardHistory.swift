struct ClipboardHistory {
    private(set) var items: [ClipboardItem] = []

    private(set) var limit: Int

    init(limit: Int, items: [ClipboardItem] = []) {
        self.limit = max(0, limit)
        self.items = Array(
            items.sorted(by: Self.isMoreRecent).prefix(self.limit)
        )
    }

    mutating func add(_ item: ClipboardItem) {
        if let existingIndex = items.firstIndex(where: { $0.hasSameContent(as: item.text) }) {
            var existingItem = items.remove(at: existingIndex)
            existingItem.lastUsedAt = item.lastUsedAt
            items.insert(existingItem, at: 0)
        } else {
            items.insert(item, at: 0)
        }

        items = Array(items.prefix(limit))
    }

    mutating func removeAll() {
        items.removeAll()
    }

    mutating func updateLimit(_ newLimit: Int) {
        limit = max(0, newLimit)
        items = Array(items.prefix(limit))
    }

    private static func isMoreRecent(_ first: ClipboardItem, than second: ClipboardItem) -> Bool {
        if first.lastUsedAt != second.lastUsedAt {
            return first.lastUsedAt > second.lastUsedAt
        }

        if first.createdAt != second.createdAt {
            return first.createdAt > second.createdAt
        }

        return first.id.uuidString < second.id.uuidString
    }
}
