import AppKit

@MainActor
final class SystemActiveApplicationProvider: ActiveApplicationProviding {
    func frontmostApplicationBundleIdentifier() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func applicationDisplayName(for bundleIdentifier: String) -> String? {
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
           frontmostApplication.bundleIdentifier == bundleIdentifier {
            return frontmostApplication.localizedName
        }

        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            return nil
        }

        let applicationBundle = Bundle(url: applicationURL)
        return applicationBundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? applicationBundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}
