import Foundation
import Testing
@testable import ArenaKit

private func client(token: String? = "t") -> ArenaClient {
    ArenaClient(token: token, userAgent: "ArenaWallpaper/0.1.0", gate: RequestGate(minInterval: 0), baseURL: URL(string: "https://api.test")!, session: StubURLProtocol.session())
}

extension Network {
    @Suite struct ArenaClientTests {
        /// Blocks of a 200 result, failing the test on anything else.
        private func pageBlocks(_ result: PageResult) -> [Block] {
            if case .page(let blocks, _, _) = result { return blocks }
            Issue.record("expected a page")
            return []
        }

        @Test func readsOnePage() async throws {
            StubURLProtocol.reset { _ in
                StubURLProtocol.Reply(
                    status: 200, headers: ["Content-Type": "application/json", "ETag": #"W/"abc""#],
                    body: Data(pageJSON([imageJSON(id: 1), imageJSON(id: 2)], more: true).utf8))
            }
            let result = try await client().channelPage(slug: "mon-channel", page: 2)
            guard case .page(let blocks, let hasMore, let etag) = result else { Issue.record("expected a page"); return }
            #expect(blocks.map(\.id) == [1, 2])
            #expect(hasMore)
            #expect(etag == #"W/"abc""#)
            #expect(StubURLProtocol.requests.map { $0.url!.absoluteString } == [
                "https://api.test/v3/channels/mon-channel/contents?per=50&page=2&sort=created_at_desc",
            ])
        }

        @Test func sendsIfNoneMatchAndReadsNotModified() async throws {
            StubURLProtocol.reset { _ in .init(status: 304) }
            let result = try await client().channelPage(slug: "c", page: 1, etag: #"W/"abc""#)
            #expect(result == .notModified)
            #expect(StubURLProtocol.requests[0].value(forHTTPHeaderField: "If-None-Match") == #"W/"abc""#)
        }

        @Test func bypassesTheURLCache() async throws {
            StubURLProtocol.reset { _ in StubURLProtocol.json(pageJSON([], more: false)) }
            _ = try await client().channelPage(slug: "c", page: 1)
            #expect(StubURLProtocol.requests[0].cachePolicy == .reloadIgnoringLocalCacheData)
        }

        @Test func rateLimitedIsNotRetried() async {
            StubURLProtocol.reset { _ in .init(status: 429, headers: ["Retry-After": "30"]) }
            await #expect(throws: ArenaError.rateLimited(retryAfterSeconds: 60)) { try await client().channelPage(slug: "c", page: 1) }
            #expect(StubURLProtocol.requests.count == 1)
        }

        @Test func keepsOnlyImageBlocks() async throws {
            StubURLProtocol.reset { _ in
                StubURLProtocol.json(pageJSON([imageJSON(id: 1), #"{"id": 9, "type": "Link", "title": null}"#, #"{"id": 10, "type": "Text"}"#], more: false))
            }
            #expect(pageBlocks(try await client().channelPage(slug: "c", page: 1)).map(\.id) == [1])
        }

        @Test func readsImageVariantsAndContentType() async throws {
            StubURLProtocol.reset { _ in
                StubURLProtocol.json(pageJSON([
                    imageJSON(id: 1, contentType: "image/gif", smallWidth: 300, mediumWidth: 640, largeWidth: 1200),
                    imageJSON(id: 2, width: nil, height: nil, fileSize: nil, smallWidth: nil, mediumWidth: nil, largeWidth: nil),
                ], more: false))
            }
            let blocks = pageBlocks(try await client().channelPage(slug: "c", page: 1))
            #expect(blocks[0].thumbURL.absoluteString == "https://img/1-medium.jpg")
            #expect(blocks[0].previewURL.absoluteString == "https://img/1-large.jpg")
            #expect(blocks[0].fullURL.absoluteString == "https://img/1.jpg")
            #expect(blocks[0].isGIF)
            #expect(blocks[0].width == 2000 && blocks[0].height == 1200 && blocks[0].fileSize == 5000)
            #expect(blocks[1].thumbURL.absoluteString == "https://img/2-medium.jpg")
            #expect(blocks[1].width == nil)
        }

        @Test func sendsUserAgentAndBearer() async throws {
            StubURLProtocol.reset { _ in StubURLProtocol.json(pageJSON([], more: false)) }
            _ = try await client().channelPage(slug: "c", page: 1)
            _ = try await client(token: nil).channelPage(slug: "c", page: 1)
            let withToken = StubURLProtocol.requests[0]
            #expect(withToken.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("ArenaWallpaper/") == true)
            #expect(withToken.value(forHTTPHeaderField: "Authorization") == "Bearer t")
            #expect(StubURLProtocol.requests[1].value(forHTTPHeaderField: "Authorization") == nil)
        }

        @Test func statusCodesMapToErrors() async {
            let cases: [(StubURLProtocol.Reply, ArenaError)] = [
                (.init(status: 401), .unauthorized),
                (.init(status: 403), .unauthorized),
                (.init(status: 404), .notFound),
                (.init(status: 429, headers: ["Retry-After": "90"]), .rateLimited(retryAfterSeconds: 90)),
                (.init(status: 429), .rateLimited(retryAfterSeconds: 60)),
                (.init(status: 500), .network("HTTP 500")),
            ]
            for (reply, expected) in cases {
                StubURLProtocol.reset { _ in reply }
                await #expect(throws: expected) { try await client().channelPage(slug: "c", page: 1) }
            }
        }

        @Test func emptyChannelReturnsEmpty() async throws {
            StubURLProtocol.reset { _ in StubURLProtocol.json(pageJSON([], more: false)) }
            #expect(pageBlocks(try await client().channelPage(slug: "c", page: 1)).isEmpty)
        }

        @Test func unusableImagesAreDropped() async throws {
            StubURLProtocol.reset { _ in
                StubURLProtocol.json(pageJSON([imageJSON(id: 1, fileSize: 52_428_801), imageJSON(id: 2)], more: false))
            }
            #expect(pageBlocks(try await client().channelPage(slug: "c", page: 1)).map(\.id) == [2])
        }

        @Test func readsTheSignedInProfile() async throws {
            StubURLProtocol.reset { _ in
                StubURLProtocol.json(#"""
                {"id": 7, "type": "User", "name": "Néo A", "slug": "neo-a", "username": "neo-a",
                 "avatar": "https://img.test/a.jpg", "initials": "NA", "email": "x@y.z",
                 "created_at": "2023-01-15T10:30:00Z", "updated_at": "2023-06-20T14:45:00Z",
                 "bio": null, "badge": null, "tier": "free", "_links": {},
                 "counts": {"channels": 24, "followers": 156, "following": 89, "notifications": 3}}
                """#)
            }
            let profile = try await client().me()
            #expect(profile == ArenaProfile(
                name: "Néo A", slug: "neo-a", avatar: URL(string: "https://img.test/a.jpg"), initials: "NA",
                channels: 24, followers: 156, following: 89,
                memberSince: ISO8601DateFormatter().date(from: "2023-01-15T10:30:00Z")))
            #expect(profile.profileURL == URL(string: "https://www.are.na/neo-a"))
            let request = StubURLProtocol.requests[0]
            #expect(request.url?.absoluteString == "https://api.test/v3/me")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer t")
            #expect(request.value(forHTTPHeaderField: "User-Agent") == "ArenaWallpaper/0.1.0")
        }

        @Test func listsFollowedChannelsOnly() async throws {
            StubURLProtocol.reset { _ in
                StubURLProtocol.json(#"""
                {"data": [
                  {"type": "Channel", "slug": "ceramics", "title": "Ceramics", "counts": {"blocks": 42}, "owner": {"name": "Ana"}},
                  {"type": "User", "slug": "bob", "title": null},
                  {"type": "Channel", "slug": "no-owner", "title": null}],
                 "meta": {"has_more_pages": false}}
                """#)
            }
            let list = try await client().followedChannels(userSlug: "neo-a")
            #expect(list == [
                ChannelSuggestion(slug: "ceramics", title: "Ceramics", blocks: 42, owner: "Ana"),
                ChannelSuggestion(slug: "no-owner", title: "no-owner", blocks: nil, owner: nil)])
            #expect(StubURLProtocol.requests[0].url?.path == "/v3/users/neo-a/following")
            #expect(StubURLProtocol.requests[0].url?.query?.contains("type=Channel") == true)
        }

        @Test func searchesChannels() async throws {
            StubURLProtocol.reset { _ in
                StubURLProtocol.json(#"""
                {"data": [{"type": "Channel", "slug": "clay", "title": "Clay", "counts": {"blocks": 9}, "owner": {"name": "Zoe"}},
                          {"type": "Image", "id": 1}],
                 "meta": {"has_more_pages": false}}
                """#)
            }
            let list = try await client().searchChannels(query: "clay pots")
            #expect(list == [ChannelSuggestion(slug: "clay", title: "Clay", blocks: 9, owner: "Zoe")])
            let url = StubURLProtocol.requests[0].url!
            #expect(url.path == "/v3/search")
            #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(URLQueryItem(name: "query", value: "clay pots")) == true)
        }

        @Test func searchWithoutPremiumIsUnauthorized() async throws {
            StubURLProtocol.reset { _ in StubURLProtocol.json("{}", status: 403) }
            await #expect(throws: ArenaError.unauthorized) { try await client().searchChannels(query: "x") }
        }

        @Test func profileWithoutTokenIsUnauthorized() async throws {
            StubURLProtocol.reset { _ in .init(status: 401) }
            await #expect(throws: ArenaError.unauthorized) { try await client(token: nil).me() }
        }
    }
}

@Test func slugsFromInputs() {
    #expect(parseChannelSlug("https://www.are.na/jean/mon-channel") == "mon-channel")
    #expect(parseChannelSlug("are.na/jean/mon-channel/") == "mon-channel")
    #expect(parseChannelSlug("https://www.are.na/jean/mon-channel?tab=1#x") == "mon-channel")
    #expect(parseChannelSlug("  mon-channel ") == "mon-channel")
    #expect(parseChannelSlug("") == nil)
    #expect(parseChannelSlug("deux mots") == nil)
}

@Test func usableRules() {
    func block(_ w: Int?, _ h: Int?, size: Int? = nil) -> Block {
        Block(id: 1, title: nil, fullURL: URL(string: "https://x")!, thumbURL: URL(string: "https://x")!, previewURL: URL(string: "https://x")!, width: w, height: h, fileSize: size)
    }
    #expect(isUsable(block(250, 188)))
    #expect(!isUsable(block(1920, 1080, size: 52_428_801)))
    #expect(isUsable(block(1920, 1080, size: 52_428_800)))
    #expect(!isUsable(block(12000, 10000)))
    #expect(isUsable(block(nil, nil)))
}

@Test func userAgentWithAndWithoutContact() {
    #expect(arenaUserAgent(version: "1.0", contact: "") == "ArenaWallpaper/1.0")
    #expect(arenaUserAgent(version: "1.0", contact: "  ") == "ArenaWallpaper/1.0")
    #expect(arenaUserAgent(version: "1.0", contact: "a@b.c") == "ArenaWallpaper/1.0 (+a@b.c)")
}
