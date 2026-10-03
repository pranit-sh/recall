import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let clipboardMonitor: ClipboardMonitor
    let historyViewModel: ClipboardHistoryViewModel
    let imagePreviewPresenter: ClipboardImagePreviewPresenting
    let settingsViewModel: SettingsViewModel

    override init() {
        let pasteboard = SystemPasteboard()
        let persistence = try? SQLiteClipboardHistoryStore.applicationSupportStore()
        let imageStore = try? FileClipboardImageStore.applicationSupportStore()
        let restoredItems = persistence.flatMap { try? $0.load() } ?? []
        let historyLimit = persistence.flatMap { try? $0.loadHistoryLimit() } ?? 100
        let storedDisplayLimit = persistence.flatMap { try? $0.loadDisplayLimit() } ?? 20
        let displayLimit = SettingsViewModel.availableDisplayLimits.contains(storedDisplayLimit)
            ? storedDisplayLimit
            : 20
        let storedImageLimit = persistence.flatMap { try? $0.loadImageLimit() } ?? 10
        let imageLimit = SettingsViewModel.availableImageLimits.contains(storedImageLimit)
            ? storedImageLimit
            : 10
        let storedImageStorageLimit = persistence.flatMap {
            try? $0.loadImageStorageLimitInMegabytes()
        } ?? 100
        let imageStorageLimit = SettingsViewModel.availableImageStorageLimitsInMegabytes
            .contains(storedImageStorageLimit) ? storedImageStorageLimit : 100
        let ignoredApplications = persistence.flatMap {
            try? $0.loadIgnoredApplicationBundleIdentifiers()
        } ?? []
        let privacySettings = PrivacySettings(
            ignoredApplicationBundleIdentifiers: ignoredApplications,
            persistence: persistence
        )
        let activeApplicationProvider = SystemActiveApplicationProvider()
        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            history: ClipboardHistory(
                limit: historyLimit,
                imageLimit: imageLimit,
                imageByteLimit: imageStorageLimit * 1_024 * 1_024,
                items: restoredItems
            ),
            persistence: persistence,
            imageStore: imageStore,
            activeApplicationProvider: activeApplicationProvider,
            privacySettings: privacySettings
        )

        clipboardMonitor = monitor
        let historyViewModel = ClipboardHistoryViewModel(
            monitor: monitor,
            pasteboard: pasteboard,
            imageStore: imageStore,
            popoverDismisser: KeyWindowPopoverDismisser(),
            activeApplicationProvider: activeApplicationProvider,
            usagePersistence: persistence,
            privacySettings: privacySettings,
            displayLimit: displayLimit
        )
        self.historyViewModel = historyViewModel
        imagePreviewPresenter = ClipboardImagePreviewController(
            previewProvider: ClipboardImagePreviewProvider(imageStore: imageStore)
        )
        settingsViewModel = SettingsViewModel(
            monitor: monitor,
            settingsPersistence: persistence,
            privacySettings: privacySettings,
            applicationProvider: activeApplicationProvider,
            launchAtLoginManager: SystemLaunchAtLoginManager(),
            releaseChecker: GitHubReleaseChecker(),
            displayLimit: displayLimit,
            displayLimitDidChange: historyViewModel.updateDisplayLimit
        )

        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        clipboardMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
    }
}
