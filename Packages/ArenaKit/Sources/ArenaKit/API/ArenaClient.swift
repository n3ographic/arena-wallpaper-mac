import Foundation

public enum ArenaError: Error, Equatable {
    case unauthorized
    case notFound
    case rateLimited(retryAfterSeconds: Int)
    case network(String)
    case decoding
}

/// What one request for a channel page returns.
public enum PageResult: Equatable, Sendable {
    case notModified
    case page(blocks: [Block], hasMore: Bool, etag: String?)
}

/// `ArenaWallpaper/<version>`, followed by the optional contact: `ArenaWallpaper/<version> (+<contact>)`.
public func arenaUserAgent(version: String, contact: String) -> String {
    let contact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
    return contact.isEmpty ? "ArenaWallpaper/\(version)" : "ArenaWallpaper/\(version) (+\(contact))"
}

/// Reads channels from the Are.na API v3, one page per request.
public struct ArenaClient: Sendable {
    public static let apiBase = URL(string: "https://api.are.na")!
    public static let pageSize = 50

    private let token: String?
    private let userAgent: String
    private let gate: RequestGate
    private let baseURL: URL
    private let session: URLSession

    public init(token: String?, userAgent: String, gate: RequestGate, baseURL: URL = apiBase, session: URLSession = .shared) {
        self.token = token
        self.userAgent = userAgent
        self.gate = gate
        self.baseURL = baseURL
        self.session = session
    }

    /// One page of a channel, newest additions first. With an `etag`, an unchanged page gives `.notModified`.
    public func channelPage(slug: String, page: Int, etag: String? = nil) async throws -> PageResult {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/v3/channels/\(slug)/contents"
        components.queryItems = [
            URLQueryItem(name: "per", value: String(Self.pageSize)),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "sort", value: "created_at_desc"),
        ]
        // The URL cache would answer a 304 by itself and hide it from the app.
        var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData)
        // Are.na asks API clients to identify themselves; the image CDN never gets this header.
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        await gate.wait()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ArenaError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw ArenaError.network("no response") }
        let pause = await gate.record(http)
        switch http.statusCode {
        case 304:
            return .notModified
        case 401, 403:
            throw ArenaError.unauthorized
        case 404:
            throw ArenaError.notFound
        case 429:
            throw ArenaError.rateLimited(retryAfterSeconds: pause ?? 60)
        case let status where status >= 400:
            throw ArenaError.network("HTTP \(status)")
        default:
            break
        }
        do {
            let body = try JSONDecoder().decode(Page.self, from: data)
            return .page(
                blocks: body.data.compactMap(\.block).filter(isUsable),
                hasMore: body.meta.has_more_pages,
                etag: http.value(forHTTPHeaderField: "ETag"))
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
