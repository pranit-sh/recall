import Foundation

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
    var lastUsedAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt ?? createdAt
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    func hasSameContent(as otherText: String) -> Bool {
        normalizedContent == otherText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedContent: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
