import XCTest
@testable import Clipboard

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testUpdatingHistoryLimitAppliesAndPersistsImmediately() {
        let pasteboard = SettingsPasteboardStub()
        var history = ClipboardHistory(limit: 100)
        (0..<60).forEach { history.add(ClipboardItem(text: "Item \($0)")) }
        let monitor = ClipboardMonitor(pasteboard: pasteboard, history: history)
        let persistence = ApplicationSettingsPersistenceStub()
        let viewModel = makeViewModel(
            monitor: monitor,
            settingsPersistence: persistence
        )

        viewModel.updateHistoryLimit(50)

        XCTAssertEqual(viewModel.historyLimit, 50)
        XCTAssertEqual(monitor.history.limit, 50)
        XCTAssertEqual(monitor.history.items.count, 50)
        XCTAssertEqual(persistence.savedHistoryLimit, 50)
    }

    func testUpdatingDisplayLimitAppliesAndPersistsImmediately() {
        let persistence = ApplicationSettingsPersistenceStub()
        var appliedDisplayLimit: Int?
        let viewModel = makeViewModel(
            settingsPersistence: persistence,
            displayLimitDidChange: { appliedDisplayLimit = $0 }
        )

        viewModel.updateDisplayLimit(10)

        XCTAssertEqual(viewModel.displayLimit, 10)
        XCTAssertEqual(appliedDisplayLimit, 10)
        XCTAssertEqual(persistence.savedDisplayLimit, 10)
    }

    func testLaunchAtLoginUpdateUsesSystemState() {
        let manager = LaunchAtLoginManagerStub()
        let viewModel = makeViewModel(launchAtLoginManager: manager)

        viewModel.updateLaunchAtLogin(true)

        XCTAssertTrue(viewModel.launchAtLoginEnabled)
        XCTAssertEqual(manager.requestedValue, true)
    }

    func testLaunchAtLoginFailureRestoresPreviousValue() {
        let manager = LaunchAtLoginManagerStub(error: SettingsTestError.updateFailed)
        let viewModel = makeViewModel(launchAtLoginManager: manager)

        viewModel.updateLaunchAtLogin(true)

        XCTAssertFalse(viewModel.launchAtLoginEnabled)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testIgnoredApplicationsUseDisplayNamesAndCanBeAllowed() {
        let privacySettings = PrivacySettings(
            ignoredApplicationBundleIdentifiers: ["com.example.private"]
        )
        let viewModel = makeViewModel(
            privacySettings: privacySettings,
            applicationProvider: SettingsApplicationProviderStub()
        )

        XCTAssertEqual(
            viewModel.ignoredApplications,
            [
                IgnoredApplicationSetting(
                    bundleIdentifier: "com.example.private",
                    displayName: "Private App"
                )
            ]
        )

        viewModel.allowApplication(viewModel.ignoredApplications[0])

        XCTAssertTrue(viewModel.ignoredApplications.isEmpty)
    }

    func testSettingsViewCanBeCreated() {
        XCTAssertNotNil(SettingsView(viewModel: makeViewModel()))
    }

    private func makeViewModel(
        monitor: ClipboardMonitor? = nil,
        settingsPersistence: ApplicationSettingsPersisting? = nil,
        privacySettings: PrivacySettings = PrivacySettings(),
        applicationProvider: ActiveApplicationProviding = SettingsApplicationProviderStub(),
        launchAtLoginManager: LaunchAtLoginManaging = LaunchAtLoginManagerStub(),
        displayLimitDidChange: @escaping (Int) -> Void = { _ in }
    ) -> SettingsViewModel {
        let pasteboard = SettingsPasteboardStub()
        return SettingsViewModel(
            monitor: monitor ?? ClipboardMonitor(
                pasteboard: pasteboard,
                history: ClipboardHistory(limit: 100)
            ),
            settingsPersistence: settingsPersistence,
            privacySettings: privacySettings,
            applicationProvider: applicationProvider,
            launchAtLoginManager: launchAtLoginManager,
            displayLimitDidChange: displayLimitDidChange
        )
    }
}

@MainActor
private final class ApplicationSettingsPersistenceStub: ApplicationSettingsPersisting {
    private(set) var savedHistoryLimit: Int?
    private(set) var savedDisplayLimit: Int?

    func loadHistoryLimit() throws -> Int? {
        nil
    }

    func saveHistoryLimit(_ limit: Int) throws {
        savedHistoryLimit = limit
    }

    func loadDisplayLimit() throws -> Int? {
        nil
    }

    func saveDisplayLimit(_ limit: Int) throws {
        savedDisplayLimit = limit
    }
}

@MainActor
private final class LaunchAtLoginManagerStub: LaunchAtLoginManaging {
    private(set) var isEnabled = false
    private(set) var requestedValue: Bool?
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func setEnabled(_ isEnabled: Bool) throws {
        requestedValue = isEnabled
        if let error {
            throw error
        }
        self.isEnabled = isEnabled
    }
}

@MainActor
private final class SettingsApplicationProviderStub: ActiveApplicationProviding {
    func frontmostApplicationBundleIdentifier() -> String? {
        nil
    }

    func applicationDisplayName(for bundleIdentifier: String) -> String? {
        bundleIdentifier == "com.example.private" ? "Private App" : nil
    }
}

@MainActor
private final class SettingsPasteboardStub: PasteboardReading {
    let changeCount = 0

    func readString() -> String? {
        nil
    }
}

private enum SettingsTestError: Error {
    case updateFailed
}