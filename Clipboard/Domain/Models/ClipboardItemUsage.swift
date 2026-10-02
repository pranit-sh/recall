import Foundation

struct ClipboardItemUsage: Equatable {
    let itemID: ClipboardItem.ID
    let applicationBundleIdentifier: String
    let selectionCount: Int
    let lastSelectedAt: Date
}
