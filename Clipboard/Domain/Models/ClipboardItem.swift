import Foundation

struct ClipboardImage: Equatable, Codable {
    let storageIdentifier: String
    let contentHash: String
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int
    let format: ClipboardImageFormat

    var displayText: String {
        return "\(pixelWidth) × \(pixelHeight)"
    }
}

enum ClipboardImageFormat: String, Equatable, Codable {
    case png
    case jpeg
    case tiff

    var fileExtension: String { rawValue == "jpeg" ? "jpg" : rawValue }
    var displayName: String { rawValue.uppercased() }
}

struct ClipboardImageData: Equatable {
    let data: Data
    let contentHash: String
    let pixelWidth: Int
    let pixelHeight: Int
    let format: ClipboardImageFormat
}

enum ClipboardContent: Equatable {
    case text(String)
    case image(ClipboardImage)
}

struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let content: ClipboardContent
    let createdAt: Date
    var lastUsedAt: Date

    var text: String {
        guard case .text(let text) = content else { return "" }
        return text
    }

    var displayText: String {
        switch content {
        case .text(let text):
            return text
        case .image(let image):
            return image.displayText
        }
    }

    var image: ClipboardImage? {
        guard case .image(let image) = content else { return nil }
        return image
    }

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        content = .text(text)
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt ?? createdAt
    }

    init(
        id: UUID = UUID(),
        image: ClipboardImage,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        content = .image(image)
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt ?? createdAt
    }

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }

    func hasSameContent(as other: ClipboardContent) -> Bool {
        switch (content, other) {
        case (.text(let text), .text(let otherText)):
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
                == otherText.trimmingCharacters(in: .whitespacesAndNewlines)
        case (.image(let image), .image(let otherImage)):
            return image.contentHash == otherImage.contentHash
        default:
            return false
        }
    }

    func hasSameContent(as otherText: String) -> Bool {
        hasSameContent(as: .text(otherText))
    }
}
