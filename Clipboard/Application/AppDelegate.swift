import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let clipboardMonitor: ClipboardMonitor
    let historyViewModel: ClipboardHistoryViewModel
    let settingsViewModel: SettingsViewModel

    override init() {
        let pasteboard = SystemPasteboard()
        let persistence = try? SQLiteClipboardHistoryStore.applicationSupportStore()
        let restoredItems = persistence.flatMap { try? $0.load() } ?? []
        let historyLimit = persistence.flatMap { try? $0.loadHistoryLimit() } ?? 100
        let storedDisplayLimit = persistence.flatMap { try? $0.loadDisplayLimit() } ?? 20
        let displayLimit = SettingsViewModel.availableDisplayLimits.contains(storedDisplayLimit)
            ? storedDisplayLimit
            : 20
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
            history: ClipboardHistory(limit: historyLimit, items: restoredItems),
            persistence: persistence,
            activeApplicationProvider: activeApplicationProvider,
            privacySettings: privacySettings
        )

        clipboardMonitor = monitor
        let historyViewModel = ClipboardHistoryViewModel(
            monitor: monitor,
            pasteboard: pasteboard,
            popoverDismisser: KeyWindowPopoverDismisser(),
            activeApplicationProvider: activeApplicationProvider,
            usagePersistence: persistence,
            privacySettings: privacySettings,
            displayLimit: displayLimit
        )
        self.historyViewModel = historyViewModel
        settingsViewModel = SettingsViewModel(
            monitor: monitor,
            settingsPersistence: persistence,
            privacySettings: privacySettings,
            applicationProvider: activeApplicationProvider,
            launchAtLoginManager: SystemLaunchAtLoginManager(),
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
