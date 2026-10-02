@MainActor
protocol IgnoredApplicationsPersisting: AnyObject {
    func loadIgnoredApplicationBundleIdentifiers() throws -> Set<String>
    func saveIgnoredApplicationBundleIdentifiers(_ bundleIdentifiers: Set<String>) throws
}
