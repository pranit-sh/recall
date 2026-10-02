@MainActor
protocol ActiveApplicationProviding: AnyObject {
    func frontmostApplicationBundleIdentifier() -> String?
    func applicationDisplayName(for bundleIdentifier: String) -> String?
}

extension ActiveApplicationProviding {
    func applicationDisplayName(for bundleIdentifier: String) -> String? {
        nil
    }
}
