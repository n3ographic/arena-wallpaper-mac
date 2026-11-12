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
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        let (data, http) = try await send(request)
        if http.statusCode == 304 { return .notModified }
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

extension ArenaClient {
    /// The signed-in user (`GET /v3/me`); needs a token.
    public func me() async throws -> ArenaProfile {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/v3/me"
        let (data, _) = try await send(URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData))
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(RawMe.self, from: data).profile
        } catch {
            throw ArenaError.decoding
        }
    }

    /// The channels a user follows (`GET /v3/users/{slug}/following?type=Channel`), at most 300.
    public func followedChannels(userSlug: String) async throws -> [ChannelSuggestion] {
        var result: [ChannelSuggestion] = []
        for page in 1...3 {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
            components.path = "/v3/users/\(userSlug)/following"
            components.queryItems = [
                URLQueryItem(name: "type", value: "Channel"),
                URLQueryItem(name: "per", value: "100"),
                URLQueryItem(name: "page", value: String(page)),
            ]
            let (data, _) = try await send(URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData))
            let body: RawFollowing
            do { body = try JSONDecoder().decode(RawFollowing.self, from: data) } catch { throw ArenaError.decoding }
            result += body.data.filter { $0.type == "Channel" }.compactMap { item in
                item.slug.map { ChannelSuggestion(slug: $0, title: item.title ?? $0, blocks: item.counts?.blocks, owner: item.owner?.name) }
            }
            if !body.meta.has_more_pages { break }
        }
        return result
    }

    /// Channels matching `query` (`GET /v3/search?type=Channel`). Are.na answers 403 (so
    /// `.unauthorized`) without a Premium account.
    public func searchChannels(query: String) async throws -> [ChannelSuggestion] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/v3/search"
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "type", value: "Channel"),
            URLQueryItem(name: "per", value: "25"),
        ]
        let (data, _) = try await send(URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData))
        do { return try JSONDecoder().decode(RawFollowing.self, from: data).suggestions } catch { throw ArenaError.decoding }
    }

    /// Identifies the app, adds the token, waits for the gate, and turns error statuses into errors.
    /// A 304 comes back as a response: only the caller knows what it means.
    fileprivate func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var request = request
        // Are.na asks API clients to identify themselves; the image CDN never gets this header.
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
        case 401, 403:
            throw ArenaError.unauthorized
        case 404:
            throw ArenaError.notFound
        case 429:
            throw ArenaError.rateLimited(retryAfterSeconds: pause ?? 60)
        case let status where status >= 400:
            throw ArenaError.network("HTTP \(status)")
        default:
            return (data, http)
        }
    }
}

/// The signed-in Are.na user, as shown on the account page.
public struct ArenaProfile: Equatable, Sendable {
    public let name: String
    public let slug: String
    public let avatar: URL?
    public let initials: String
    public let channels: Int
    public let followers: Int
    public let following: Int
    public let memberSince: Date?

    public init(name: String, slug: String, avatar: URL?, initials: String, channels: Int, followers: Int, following: Int, memberSince: Date?) {
        self.name = name
        self.slug = slug
        self.avatar = avatar
        self.initials = initials
        self.channels = channels
        self.followers = followers
        self.following = following
        self.memberSince = memberSince
    }

    /// Built without parsing, so an unexpected character in the slug cannot crash the app.
    public var profileURL: URL { URL(string: "https://www.are.na")!.appendingPathComponent(slug) }
}

private struct RawMe: Decodable {
    let name: String
    let slug: String
    let avatar: URL?
    let initials: String
    let created_at: Date?
    let counts: Counts
    struct Counts: Decodable { let channels: Int; let followers: Int; let following: Int }

    var profile: ArenaProfile {
        ArenaProfile(name: name, slug: slug, avatar: avatar, initials: initials, channels: counts.channels,
                     followers: counts.followers, following: counts.following, memberSince: created_at)
    }
}

/// A channel offered as a suggestion (followed or found by search).
public struct ChannelSuggestion: Equatable, Sendable, Identifiable {
    public let slug: String
    public let title: String
    public let blocks: Int?
    public let owner: String?
    public var id: String { slug }

    public init(slug: String, title: String, blocks: Int?, owner: String?) {
        self.slug = slug
        self.title = title
        self.blocks = blocks
        self.owner = owner
    }
}

// MARK: - v3 payload

private struct RawFollowing: Decodable {
    let data: [Item]
    let meta: Page.Meta

    var suggestions: [ChannelSuggestion] {
        data.filter { $0.type == "Channel" }.compactMap { item in
            item.slug.map { ChannelSuggestion(slug: $0, title: item.title ?? $0, blocks: item.counts?.blocks, owner: item.owner?.name) }
        }
    }
    struct Item: Decodable {
        let type: String
        let slug: String?
        let title: String?
        let counts: Counts?
        let owner: Owner?
        struct Counts: Decodable { let blocks: Int? }
        struct Owner: Decodable { let name: String? }
    }
}

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
