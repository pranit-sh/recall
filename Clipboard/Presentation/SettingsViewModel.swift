import Combine

struct IgnoredApplicationSetting: Identifiable, Equatable {
    let bundleIdentifier: String
    let displayName: String

    var id: String { bundleIdentifier }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    static let availableTextHistoryLimits = [50, 100, 200]
    static let availableDisplayLimits = [15, 20, 25]
    static let availableImageLimits = [5, 10, 20]
    static let availableImageStorageLimitsInMegabytes = [50, 100, 200]

    @Published private(set) var textHistoryLimit: Int
    @Published private(set) var displayLimit: Int
    @Published private(set) var imageLimit: Int
    @Published private(set) var imageStorageLimitInMegabytes: Int
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var ignoredApplications: [IgnoredApplicationSetting] = []
    @Published var errorMessage: String?

    private let monitor: ClipboardMonitor
    private let settingsPersistence: ApplicationSettingsPersisting?
    private let privacySettings: PrivacySettings
    private let applicationProvider: ActiveApplicationProviding
    private let launchAtLoginManager: LaunchAtLoginManaging
    private let displayLimitDidChange: (Int) -> Void
    private var privacySubscription: AnyCancellable?

    init(
        monitor: ClipboardMonitor,
        settingsPersistence: ApplicationSettingsPersisting? = nil,
        privacySettings: PrivacySettings,
        applicationProvider: ActiveApplicationProviding,
        launchAtLoginManager: LaunchAtLoginManaging,
        displayLimit: Int = 20,
        displayLimitDidChange: @escaping (Int) -> Void = { _ in }
    ) {
        self.monitor = monitor
        self.settingsPersistence = settingsPersistence
        self.privacySettings = privacySettings
        self.applicationProvider = applicationProvider
        self.launchAtLoginManager = launchAtLoginManager
        self.displayLimitDidChange = displayLimitDidChange
        textHistoryLimit = monitor.history.textLimit
        self.displayLimit = Self.availableDisplayLimits.contains(displayLimit) ? displayLimit : 20
        imageLimit = monitor.history.imageLimit
        imageStorageLimitInMegabytes = monitor.history.imageByteLimit / (1_024 * 1_024)
        launchAtLoginEnabled = launchAtLoginManager.isEnabled
        refreshIgnoredApplications(from: privacySettings.ignoredApplicationBundleIdentifiers)

        privacySubscription = privacySettings.$ignoredApplicationBundleIdentifiers
            .sink { [weak self] bundleIdentifiers in
                self?.refreshIgnoredApplications(from: bundleIdentifiers)
            }
    }

    func updateTextHistoryLimit(_ limit: Int) {
        guard Self.availableTextHistoryLimits.contains(limit) else { return }

        textHistoryLimit = limit
        monitor.updateTextHistoryLimit(limit)

        do {
            try settingsPersistence?.saveHistoryLimit(limit)
            errorMessage = nil
        } catch {
            errorMessage = "The text history size could not be saved."
        }
    }

    func updateDisplayLimit(_ limit: Int) {
        guard Self.availableDisplayLimits.contains(limit) else { return }

        displayLimit = limit
        displayLimitDidChange(limit)

        do {
            try settingsPersistence?.saveDisplayLimit(limit)
            errorMessage = nil
        } catch {
            errorMessage = "The displayed clips setting could not be saved."
        }
    }

    func updateImageLimit(_ limit: Int) {
        guard Self.availableImageLimits.contains(limit) else { return }

        imageLimit = limit
        applyImageLimits()

        do {
            try settingsPersistence?.saveImageLimit(limit)
            errorMessage = nil
        } catch {
            errorMessage = "The image count limit could not be saved."
        }
    }

    func updateImageStorageLimitInMegabytes(_ limit: Int) {
        guard Self.availableImageStorageLimitsInMegabytes.contains(limit) else { return }

        imageStorageLimitInMegabytes = limit
        applyImageLimits()

        do {
            try settingsPersistence?.saveImageStorageLimitInMegabytes(limit)
            errorMessage = nil
        } catch {
            errorMessage = "The image storage limit could not be saved."
        }
    }

    func updateLaunchAtLogin(_ isEnabled: Bool) {
        do {
            try launchAtLoginManager.setEnabled(isEnabled)
            launchAtLoginEnabled = launchAtLoginManager.isEnabled
            errorMessage = nil
        } catch {
            launchAtLoginEnabled = launchAtLoginManager.isEnabled
            errorMessage = "The login setting could not be updated."
        }
    }

    func allowApplication(_ application: IgnoredApplicationSetting) {
        privacySettings.allow(application.bundleIdentifier)
        if privacySettings.persistenceError != nil {
            errorMessage = "The privacy setting could not be saved."
        }
    }

    private func refreshIgnoredApplications(from bundleIdentifiers: Set<String>) {
        ignoredApplications = bundleIdentifiers
            .map { bundleIdentifier in
                IgnoredApplicationSetting(
                    bundleIdentifier: bundleIdentifier,
                    displayName: applicationProvider.applicationDisplayName(
                        for: bundleIdentifier
                    ) ?? bundleIdentifier.split(separator: ".").last.map(String.init)
                        ?? "Unknown App"
                )
            }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    private func applyImageLimits() {
        monitor.updateImageLimits(
            count: imageLimit,
            byteCount: imageStorageLimitInMegabytes * 1_024 * 1_024
        )
    }
}
