import Combine
import Foundation

@MainActor
final class ClipboardMonitor: ObservableObject {
    private let pasteboard: PasteboardReading
    private let persistence: ClipboardHistoryPersisting?
    private let activeApplicationProvider: ActiveApplicationProviding?
    private let privacySettings: PrivacySettings?
    private let pollInterval: TimeInterval
    private var lastObservedChangeCount: Int
    private var timer: Timer?

    @Published private(set) var history: ClipboardHistory
    private(set) var persistenceError: Error?

    init(
        pasteboard: PasteboardReading,
        history: ClipboardHistory,
        persistence: ClipboardHistoryPersisting? = nil,
        activeApplicationProvider: ActiveApplicationProviding? = nil,
        privacySettings: PrivacySettings? = nil,
        pollInterval: TimeInterval = 0.5
    ) {
        self.pasteboard = pasteboard
        self.history = history
        self.persistence = persistence
        self.activeApplicationProvider = activeApplicationProvider
        self.privacySettings = privacySettings
        self.pollInterval = pollInterval
        lastObservedChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func checkForChanges() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastObservedChangeCount else { return }

        lastObservedChangeCount = currentChangeCount

        if let applicationBundleIdentifier = activeApplicationProvider?
            .frontmostApplicationBundleIdentifier(),
           privacySettings?.isIgnored(applicationBundleIdentifier) == true {
            return
        }

        guard let text = pasteboard.readString() else { return }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        history.add(ClipboardItem(text: trimmedText))

        do {
            try persistence?.save(history.items)
            persistenceError = nil
        } catch {
            persistenceError = error
        }
    }

    func clearHistory() {
        history.removeAll()

        persistHistory()
    }

    func updateHistoryLimit(_ limit: Int) {
        history.updateLimit(limit)

        persistHistory()
    }

    private func persistHistory() {

        do {
            try persistence?.save(history.items)
            persistenceError = nil
        } catch {
            persistenceError = error
        }
    }
}
