struct ClipboardHistory {
    private(set) var items: [ClipboardItem] = []

    private(set) var textLimit: Int
    private(set) var imageLimit: Int
    private(set) var imageByteLimit: Int

    init(
        limit: Int,
        imageLimit: Int = 10,
        imageByteLimit: Int = 100 * 1_024 * 1_024,
        items: [ClipboardItem] = []
    ) {
        textLimit = max(0, limit)
        self.imageLimit = max(0, imageLimit)
        self.imageByteLimit = max(0, imageByteLimit)
        self.items = Self.limitedItems(
            from: items.sorted(by: Self.isMoreRecent),
            textLimit: textLimit,
            imageLimit: self.imageLimit,
            imageByteLimit: self.imageByteLimit
        )
    }

    @discardableResult
    mutating func add(_ item: ClipboardItem) -> [ClipboardItem] {
        let previousItems = items

        if let existingIndex = items.firstIndex(where: { $0.hasSameContent(as: item.content) }) {
            var existingItem = items.remove(at: existingIndex)
            existingItem.lastUsedAt = item.lastUsedAt
            items.insert(existingItem, at: 0)
        } else {
            items.insert(item, at: 0)
        }

        items = Self.limitedItems(
            from: items,
            textLimit: textLimit,
            imageLimit: imageLimit,
            imageByteLimit: imageByteLimit
        )
        return previousItems.filter { previous in
            !items.contains(where: { $0.id == previous.id })
        }
    }

    mutating func removeAll() {
        items.removeAll()
    }

    @discardableResult
    mutating func updateTextLimit(_ newLimit: Int) -> [ClipboardItem] {
        let previousItems = items
        textLimit = max(0, newLimit)
        items = Self.limitedItems(
            from: items,
            textLimit: textLimit,
            imageLimit: imageLimit,
            imageByteLimit: imageByteLimit
        )
        return previousItems.filter { previous in
            !items.contains(where: { $0.id == previous.id })
        }
    }

    @discardableResult
    mutating func updateImageLimits(count: Int, byteCount: Int) -> [ClipboardItem] {
        let previousItems = items
        imageLimit = max(0, count)
        imageByteLimit = max(0, byteCount)
        items = Self.limitedItems(
            from: items,
            textLimit: textLimit,
            imageLimit: imageLimit,
            imageByteLimit: imageByteLimit
        )
        return previousItems.filter { previous in
            !items.contains(where: { $0.id == previous.id })
        }
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

    private static func limitedItems(
        from items: [ClipboardItem],
        textLimit: Int,
        imageLimit: Int,
        imageByteLimit: Int
    ) -> [ClipboardItem] {
        var retainedImageCount = 0
        var retainedImageBytes = 0
        var retainedTextCount = 0

        return items.filter { item in
            guard let image = item.image else {
                guard retainedTextCount < textLimit else { return false }
                retainedTextCount += 1
                return true
            }
            guard retainedImageCount < imageLimit,
                  retainedImageBytes + image.byteCount <= imageByteLimit else { return false }
            retainedImageCount += 1
            retainedImageBytes += image.byteCount
            return true
        }
    }
}
