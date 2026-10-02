import Foundation

@MainActor
protocol ClipboardUsagePersisting: AnyObject {
    func loadUsage(for applicationBundleIdentifier: String) throws -> [ClipboardItemUsage]

    func recordSelection(
        of itemID: ClipboardItem.ID,
        for applicationBundleIdentifier: String,
        at date: Date
    ) throws
}
