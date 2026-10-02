import Combine

@MainActor
final class PrivacySettings: ObservableObject {
    @Published private(set) var ignoredApplicationBundleIdentifiers: Set<String>

    private let persistence: IgnoredApplicationsPersisting?
    private(set) var persistenceError: Error?

    init(
        ignoredApplicationBundleIdentifiers: Set<String> = [],
        persistence: IgnoredApplicationsPersisting? = nil
    ) {
        self.ignoredApplicationBundleIdentifiers = ignoredApplicationBundleIdentifiers
        self.persistence = persistence
    }

    func isIgnored(_ applicationBundleIdentifier: String) -> Bool {
        ignoredApplicationBundleIdentifiers.contains(applicationBundleIdentifier)
    }

    func ignore(_ applicationBundleIdentifier: String) {
        guard !applicationBundleIdentifier.isEmpty else { return }
        ignoredApplicationBundleIdentifiers.insert(applicationBundleIdentifier)
        persist()
    }

    func allow(_ applicationBundleIdentifier: String) {
        ignoredApplicationBundleIdentifiers.remove(applicationBundleIdentifier)
        persist()
    }

    private func persist() {
        do {
            try persistence?.saveIgnoredApplicationBundleIdentifiers(
                ignoredApplicationBundleIdentifiers
            )
            persistenceError = nil
        } catch {
            persistenceError = error
        }
    }
}
