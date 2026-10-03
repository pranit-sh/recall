import Foundation

struct AppRelease: Equatable, Sendable {
    let version: String
    let pageURL: URL
}

protocol AppReleaseChecking: Sendable {
    func latestRelease() async throws -> AppRelease
}