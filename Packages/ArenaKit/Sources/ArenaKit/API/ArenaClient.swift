import Foundation

public enum ArenaError: Error, Equatable {
    case unauthorized
    case notFound
    case rateLimited(retryAfterSeconds: Int)
    case network(String)
    case decoding
}

/// Reads channels from the Are.na API v3.
public struct ArenaClient: Sendable {
    public static let apiBase = URL(string: "https://api.are.na")!

    private let token: String?
    private let userAgent: String
    private let baseURL: URL
    private let session: URLSession

    public init(token: String?, userAgent: String, baseURL: URL = apiBase, session: URLSession = .shared) {
        self.token = token
        self.userAgent = userAgent
        self.baseURL = baseURL
        self.session = session
    }

    /// Every usable image of a channel, following all pages.
    public func channelBlocks(slug: String) async throws -> [Block] {
        var blocks: [Block] = []
        var page = 1
        while true {
            let body: Page = try await get("/v3/channels/\(slug)/contents", query: [("per", "100"), ("page", String(page))])
            blocks += body.data.compactMap(\.block).filter(isUsable)
            guard body.meta.has_more_pages else { return blocks }
            page += 1
        }
    }

    private func get<T: Decodable>(_ path: String, query: [(String, String)]) async throws -> T {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        var request = URLRequest(url: components.url!)
        // Are.na asks API clients to identify themselves; the image CDN never gets this header.
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ArenaError.network(error.localizedDescription)
        }
        let http = response as? HTTPURLResponse
        switch http?.statusCode ?? 0 {
        case 401, 403:
            throw ArenaError.unauthorized
        case 404:
            throw ArenaError.notFound
        case 429:
            let retry = http?.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init) ?? 60
            throw ArenaError.rateLimited(retryAfterSeconds: retry)
        case let status where status >= 400:
            throw ArenaError.network("HTTP \(status)")
        default:
            break
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ArenaError.decoding
        }
    }
}

// MARK: - v3 payload

private struct Page: Decodable {
    let data: [RawBlock]
    let meta: Meta
    struct Meta: Decodable { let has_more_pages: Bool }
}

private struct RawBlock: Decodable {
    let id: Int
    let type: String
    let title: String?
    let image: RawImage?

    var block: Block? {
        guard type == "Image", let image else { return nil }
        return Block(
            id: id, title: title, fullURL: image.src,
            thumbURL: image.thumbnail, previewURL: image.preview,
            width: image.width, height: image.height, fileSize: image.file_size, contentType: image.content_type
        )
    }
}

private struct RawImage: Decodable {
    let src: URL
    let content_type: String?
    let width: Int?
    let height: Int?
    let file_size: Int?
    let small: Version?
    let medium: Version?
    let large: Version?

    struct Version: Decodable {
        let src: URL
        let width: Int?
    }

    /// The smallest version at least 400 px wide, so the grid stays light; medium otherwise.
    var thumbnail: URL {
        [small, medium, large].compactMap { $0 }.first { ($0.width ?? 0) >= 400 }?.src
            ?? medium?.src ?? large?.src ?? small?.src ?? src
    }

    var preview: URL { large?.src ?? medium?.src ?? src }
}
