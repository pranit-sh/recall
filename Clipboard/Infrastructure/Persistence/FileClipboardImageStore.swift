import Foundation

@MainActor
final class FileClipboardImageStore: ClipboardImageStoring {
    private let directoryURL: URL
    private let fileManager: FileManager

    init(directoryURL: URL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
    }

    static func applicationSupportStore() throws -> FileClipboardImageStore {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw FileClipboardImageStoreError.applicationSupportDirectoryUnavailable
        }

        return FileClipboardImageStore(
            directoryURL: applicationSupportURL
                .appendingPathComponent("Clipboard", isDirectory: true)
                .appendingPathComponent("Images", isDirectory: true)
        )
    }

    func store(_ image: ClipboardImageData) throws -> ClipboardImage {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let storageIdentifier = "\(image.contentHash).\(image.format.fileExtension)"
        let fileURL = directoryURL.appendingPathComponent(storageIdentifier)

        if !fileManager.fileExists(atPath: fileURL.path) {
            try image.data.write(to: fileURL, options: .atomic)
        }

        return ClipboardImage(
            storageIdentifier: storageIdentifier,
            contentHash: image.contentHash,
            pixelWidth: image.pixelWidth,
            pixelHeight: image.pixelHeight,
            byteCount: image.data.count,
            format: image.format
        )
    }

    func load(_ image: ClipboardImage) throws -> Data {
        try Data(contentsOf: fileURL(for: image))
    }

    func remove(_ image: ClipboardImage) throws {
        let fileURL = try fileURL(for: image)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    private func fileURL(for image: ClipboardImage) throws -> URL {
        guard image.storageIdentifier == (image.storageIdentifier as NSString).lastPathComponent else {
            throw FileClipboardImageStoreError.invalidStorageIdentifier
        }
        return directoryURL.appendingPathComponent(image.storageIdentifier)
    }
}

enum FileClipboardImageStoreError: Error {
    case applicationSupportDirectoryUnavailable
    case invalidStorageIdentifier
}