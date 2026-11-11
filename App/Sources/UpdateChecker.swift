import Foundation

/// Asks GitHub for the latest release: once when the General section opens, and on demand.
/// Not Sparkle: no key, no appcast, no signing. The user downloads the new zip by hand.
@MainActor
final class UpdateChecker: ObservableObject {
    enum Status: Equatable {
        case idle, checking, upToDate, failed
        case newer(version: String, page: URL)
    }

    @Published private(set) var status = Status.idle

    static let repository = URL(string: "https://github.com/n3ographic/arena-wallpaper-mac")!
    // ponytail: repo name is fixed; change it here if the repository moves.
    private let api = URL(string: "https://api.github.com/repos/n3ographic/arena-wallpaper-mac/releases/latest")!

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    func check() async {
        guard status != .checking else { return }
        status = .checking
        var request = URLRequest(url: api)
        request.setValue("ArenaWallpaper", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let release = try? JSONDecoder().decode(Release.self, from: data),
              let page = URL(string: release.html_url),
              // Only a page of this repository is offered as a download link.
              page.scheme == "https", page.host == "github.com",
              page.path.hasPrefix(Self.repository.path + "/") else {
            status = .failed
            return
        }
        let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        status = latest.compare(Self.currentVersion, options: .numeric) == .orderedDescending
            ? .newer(version: latest, page: page)
            : .upToDate
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
    }
}
