import XCTest
@testable import Clipboard

@MainActor
final class PrivacySettingsTests: XCTestCase {
    func testIgnoringApplicationUpdatesAndPersistsSet() {
        let persistence = IgnoredApplicationsPersistenceStub()
        let settings = PrivacySettings(persistence: persistence)

        settings.ignore("com.example.private")
        settings.ignore("com.example.private")

        XCTAssertTrue(settings.isIgnored("com.example.private"))
        XCTAssertEqual(settings.ignoredApplicationBundleIdentifiers.count, 1)
        XCTAssertEqual(persistence.savedBundleIdentifiers, ["com.example.private"])
    }

    func testAllowingApplicationUpdatesAndPersistsSet() {
        let persistence = IgnoredApplicationsPersistenceStub()
        let settings = PrivacySettings(
            ignoredApplicationBundleIdentifiers: ["com.example.private"],
            persistence: persistence
        )

        settings.allow("com.example.private")

        XCTAssertFalse(settings.isIgnored("com.example.private"))
        XCTAssertTrue(persistence.savedBundleIdentifiers.isEmpty)
    }

    func testPersistenceFailureDoesNotDiscardInMemorySetting() {
        let persistence = IgnoredApplicationsPersistenceStub(error: PrivacyTestError.saveFailed)
        let settings = PrivacySettings(persistence: persistence)

        settings.ignore("com.example.private")

        XCTAssertTrue(settings.isIgnored("com.example.private"))
        XCTAssertNotNil(settings.persistenceError)
    }
}

@MainActor
private final class IgnoredApplicationsPersistenceStub: IgnoredApplicationsPersisting {
    private let error: Error?
    private(set) var savedBundleIdentifiers: Set<String> = []

    init(error: Error? = nil) {
        self.error = error
    }

    func loadIgnoredApplicationBundleIdentifiers() throws -> Set<String> {
        []
    }

    func saveIgnoredApplicationBundleIdentifiers(_ bundleIdentifiers: Set<String>) throws {
        if let error {
            throw error
        }
        savedBundleIdentifiers = bundleIdentifiers
    }
}

private enum PrivacyTestError: Error {
    case saveFailed
}
