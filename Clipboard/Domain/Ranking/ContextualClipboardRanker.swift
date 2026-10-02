import Foundation

struct ContextualClipboardRanker {
    let guaranteedRecentItemCount: Int
    let contextualItemCount: Int
    let decayInterval: TimeInterval

    init(
        guaranteedRecentItemCount: Int = 3,
        contextualItemCount: Int = 2,
        decayInterval: TimeInterval = 30 * 24 * 60 * 60
    ) {
        self.guaranteedRecentItemCount = max(0, guaranteedRecentItemCount)
        self.contextualItemCount = max(0, contextualItemCount)
        self.decayInterval = max(1, decayInterval)
    }

    func rank(
        _ items: [ClipboardItem],
        usage: [ClipboardItemUsage],
        for applicationBundleIdentifier: String?,
        now: Date = Date()
    ) -> [ClipboardItem] {
        guard let applicationBundleIdentifier, !applicationBundleIdentifier.isEmpty else {
            return items
        }

        let recentCount = min(guaranteedRecentItemCount, items.count)
        let recentItems = Array(items.prefix(recentCount))
        let remainingItems = Array(items.dropFirst(recentCount))
        let originalIndexes = Dictionary(
            uniqueKeysWithValues: items.enumerated().map { ($0.element.id, $0.offset) }
        )
        let relevantUsage = Dictionary(
            uniqueKeysWithValues: usage
                .filter { $0.applicationBundleIdentifier == applicationBundleIdentifier }
                .map { ($0.itemID, $0) }
        )

        let contextualItems = remainingItems
            .filter { relevantUsage[$0.id] != nil }
            .sorted { first, second in
                let firstScore = relevanceScore(for: relevantUsage[first.id]!, now: now)
                let secondScore = relevanceScore(for: relevantUsage[second.id]!, now: now)

                if firstScore != secondScore {
                    return firstScore > secondScore
                }

                return originalIndexes[first.id]! < originalIndexes[second.id]!
            }
            .prefix(contextualItemCount)

        let contextualIDs = Set(contextualItems.map(\.id))
        let remainingMRUItems = remainingItems.filter { !contextualIDs.contains($0.id) }

        return recentItems + contextualItems + remainingMRUItems
    }

    private func relevanceScore(for usage: ClipboardItemUsage, now: Date) -> Double {
        let age = max(0, now.timeIntervalSince(usage.lastSelectedAt))
        let recencyMultiplier = exp(-age / decayInterval)
        return log1p(Double(max(0, usage.selectionCount))) * recencyMultiplier
    }
}
