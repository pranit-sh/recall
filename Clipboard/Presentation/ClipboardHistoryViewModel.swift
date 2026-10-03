import Combine
import Foundation

@MainActor
final class ClipboardHistoryViewModel: ObservableObject {
    @Published private(set) var items: [ClipboardItem]
    @Published private(set) var selectedItemID: ClipboardItem.ID?
    @Published private(set) var displayLimit: Int
    @Published var searchText = "" {
        didSet {
            selectedItemID = nil
        }
    }
    @Published private var contextualUsage: [ClipboardItemUsage] = []
    @Published private(set) var ignoredApplicationBundleIdentifiers: [String]

    private let monitor: ClipboardMonitor
    private let pasteboard: PasteboardWriting
    private let popoverDismisser: PopoverDismissing
    private let activeApplicationProvider: ActiveApplicationProviding?
    private let usagePersistence: ClipboardUsagePersisting?
    private let privacySettings: PrivacySettings?
    private let ranker: ContextualClipboardRanker
    private let now: () -> Date
    private var historySubscription: AnyCancellable?
    private var activeApplicationBundleIdentifier: String?
    private var activeApplicationDisplayName: String?

    private(set) var contextualRankingError: Error?

    init(
        monitor: ClipboardMonitor,
        pasteboard: PasteboardWriting,
        popoverDismisser: PopoverDismissing,
        activeApplicationProvider: ActiveApplicationProviding? = nil,
        usagePersistence: ClipboardUsagePersisting? = nil,
        privacySettings: PrivacySettings? = nil,
        displayLimit: Int = 20,
        ranker: ContextualClipboardRanker = ContextualClipboardRanker(),
        now: @escaping () -> Date = Date.init
    ) {
        let initialItems = monitor.history.items
        items = initialItems
        selectedItemID = nil
        self.displayLimit = max(1, displayLimit)
        ignoredApplicationBundleIdentifiers = privacySettings?
            .ignoredApplicationBundleIdentifiers.sorted() ?? []
        self.monitor = monitor
        self.pasteboard = pasteboard
        self.popoverDismisser = popoverDismisser
        self.activeApplicationProvider = activeApplicationProvider
        self.usagePersistence = usagePersistence
        self.privacySettings = privacySettings
        self.ranker = ranker
        self.now = now

        historySubscription = monitor.$history.sink { [weak self] history in
            self?.items = history.items
            self?.ensureValidSelection()
        }
    }

    var filteredItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchingItems = query.isEmpty
            ? items
            : items.filter { $0.text.localizedCaseInsensitiveContains(query) }

        return ranker.rank(
            matchingItems,
            usage: contextualUsage,
            for: activeApplicationBundleIdentifier,
            now: now()
        )
    }

    var selectedItem: ClipboardItem? {
        displayedItems.first { $0.id == selectedItemID }
    }

    var displayedItems: [ClipboardItem] {
        Array(filteredItems.prefix(displayLimit))
    }

    var searchPrompt: String {
        "Search \(items.count) \(items.count == 1 ? "item" : "items")"
    }

    var canIgnoreCurrentApplication: Bool {
        guard let activeApplicationBundleIdentifier else { return false }
        return privacySettings?.isIgnored(activeApplicationBundleIdentifier) == false
    }

    var canConfigureCurrentApplication: Bool {
        activeApplicationBundleIdentifier != nil && privacySettings != nil
    }

    var isCurrentApplicationIgnored: Bool {
        guard let activeApplicationBundleIdentifier else { return false }
        return privacySettings?.isIgnored(activeApplicationBundleIdentifier) == true
    }

    var currentApplicationPrivacyActionTitle: String {
        let application = activeApplicationDisplayName
            ?? activeApplicationBundleIdentifier
            ?? "Current Application"
        return "Ignore \(application)"
    }

    func prepareForPresentation() {
        activeApplicationBundleIdentifier = activeApplicationProvider?
            .frontmostApplicationBundleIdentifier()
        activeApplicationDisplayName = activeApplicationBundleIdentifier.flatMap {
            activeApplicationProvider?.applicationDisplayName(for: $0)
        }
        refreshIgnoredApplications()
        loadContextualUsage()
        searchText = ""
        selectedItemID = nil
    }

    func moveSelection(by offset: Int) {
        guard !displayedItems.isEmpty else {
            selectedItemID = nil
            return
        }

        guard let selectedItemID,
              let currentIndex = displayedItems.firstIndex(where: { $0.id == selectedItemID }) else {
            self.selectedItemID = offset < 0 ? displayedItems.last?.id : displayedItems.first?.id
            return
        }

        let nextIndex = min(max(currentIndex + offset, 0), displayedItems.count - 1)
        self.selectedItemID = displayedItems[nextIndex].id
    }

    func updateDisplayLimit(_ limit: Int) {
        displayLimit = max(1, limit)
        ensureValidSelection()
    }

    func clearSelection() {
        selectedItemID = nil
    }

    func selectCurrentItem() {
        guard let selectedItem else { return }
        select(selectedItem)
    }

    func select(_ item: ClipboardItem) {
        recordSelection(of: item)
        pasteboard.writeString(item.text)
        popoverDismisser.dismissPopover()
    }

    func ignoreCurrentApplication() {
        guard let activeApplicationBundleIdentifier else { return }
        privacySettings?.ignore(activeApplicationBundleIdentifier)
        refreshIgnoredApplications()
        popoverDismisser.dismissPopover()
    }

    func toggleCurrentApplicationPrivacy() {
        guard let activeApplicationBundleIdentifier else { return }

        if privacySettings?.isIgnored(activeApplicationBundleIdentifier) == true {
            privacySettings?.allow(activeApplicationBundleIdentifier)
        } else {
            privacySettings?.ignore(activeApplicationBundleIdentifier)
        }

        refreshIgnoredApplications()
        popoverDismisser.dismissPopover()
    }

    func allowApplication(_ applicationBundleIdentifier: String) {
        privacySettings?.allow(applicationBundleIdentifier)
        refreshIgnoredApplications()
    }

    func clearHistory() {
        monitor.clearHistory()
    }

    func dismissPopover() {
        popoverDismisser.dismissPopover()
    }

    private func loadContextualUsage() {
        guard let activeApplicationBundleIdentifier, let usagePersistence else {
            contextualUsage = []
            return
        }

        do {
            contextualUsage = try usagePersistence.loadUsage(
                for: activeApplicationBundleIdentifier
            )
            contextualRankingError = nil
        } catch {
            contextualUsage = []
            contextualRankingError = error
        }
    }

    private func recordSelection(of item: ClipboardItem) {
        guard let activeApplicationBundleIdentifier, let usagePersistence else { return }
        guard privacySettings?.isIgnored(activeApplicationBundleIdentifier) != true else { return }

        do {
            try usagePersistence.recordSelection(
                of: item.id,
                for: activeApplicationBundleIdentifier,
                at: now()
            )
            contextualRankingError = nil
        } catch {
            contextualRankingError = error
        }
    }

    private func refreshIgnoredApplications() {
        ignoredApplicationBundleIdentifiers = privacySettings?
            .ignoredApplicationBundleIdentifiers.sorted() ?? []
    }

    private func ensureValidSelection() {
        guard let selectedItemID else { return }
        guard displayedItems.contains(where: { $0.id == selectedItemID }) else {
            self.selectedItemID = nil
            return
        }
    }
}
