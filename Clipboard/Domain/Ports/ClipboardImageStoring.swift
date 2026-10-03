import Foundation

@MainActor
protocol ClipboardImageStoring: AnyObject {
    func store(_ image: ClipboardImageData) throws -> ClipboardImage
    func load(_ image: ClipboardImage) throws -> Data
    func remove(_ image: ClipboardImage) throws
}