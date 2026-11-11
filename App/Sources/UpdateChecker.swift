import Foundation

/// Asks GitHub for the latest release, once per launch of the General tab.
/// Not Sparkle: no key, no appcast, no signing. The user downloads the new zip by hand.
@MainActor
final class UpdateChecker: ObservableObject {
    /// Page of the newer release, nil when up to date or when the check failed.
    @Published private(set) var newerRelease: URL?
    @Published private(set) var newerVersion = ""

    // ponytail: repo name is fixed; change it here if the repository moves.
    private let api = URL(string: "https://api.github.com/repos/n3ographic/arena-wallpaper-mac/releases/latest")!

    func check() async {
        var request = URLRequest(url: api)
        request.setValue("ArenaWallpaper", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let release = try? JSONDecoder().decode(Release.self, from: data),
              let page = URL(string: release.html_url) else { return }
        let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        if latest.compare(current, options: .numeric) == .orderedDescending {
            newerVersion = latest
            newerRelease = page
        }
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
    }
}
