import Foundation

struct GitHubReleaseChecker: AppReleaseChecking {
    private let releasesURL: URL

    init(
        releasesURL: URL = URL(
            string: "https://api.github.com/repos/pranit-sh/recall/releases/latest"
        )!
    ) {
        self.releasesURL = releasesURL
    }

    func latestRelease() async throws -> AppRelease {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw GitHubReleaseCheckerError.unsuccessfulResponse
        }

        let release = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
        let version = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        guard !version.isEmpty else {
            throw GitHubReleaseCheckerError.missingVersion
        }

        return AppRelease(version: version, pageURL: release.pageURL)
    }
}

private struct GitHubReleaseResponse: Decodable {
    let tagName: String
    let pageURL: URL

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case pageURL = "html_url"
    }
}

private enum GitHubReleaseCheckerError: Error {
    case unsuccessfulResponse
    case missingVersion
}