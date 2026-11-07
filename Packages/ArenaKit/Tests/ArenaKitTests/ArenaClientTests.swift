import Foundation
import Testing
@testable import ArenaKit

private func client(token: String? = "t") -> ArenaClient {
    ArenaClient(token: token, userAgent: "ArenaWallpaper/0.1.0", baseURL: URL(string: "https://api.test")!, session: StubURLProtocol.session())
}

extension Network {
    @Suite struct ArenaClientTests {
        @Test func followsPagination() async throws {
            StubURLProtocol.reset { request in
                request.url!.query!.contains("page=1")
                    ? StubURLProtocol.json(pageJSON([imageJSON(id: 1), imageJSON(id: 2)], more: true))
                    : StubURLProtocol.json(pageJSON([imageJSON(id: 3)], more: false))
            }
            let blocks = try await client().channelBlocks(slug: "mon-channel")
            #expect(blocks.map(\.id) == [1, 2, 3])
            #expect(StubURLProtocol.requests.map { $0.url!.absoluteString } == [
                "https://api.test/v3/channels/mon-channel/contents?per=100&page=1",
                "https://api.test/v3/channels/mon-channel/contents?per=100&page=2",
            ])
        }

        @Test func keepsOnlyImageBlocks() async throws {
            StubURLProtocol.reset { _ in
                StubURLProtocol.json(pageJSON([imageJSON(id: 1), #"{"id": 9, "type": "Link", "title": null}"#, #"{"id": 10, "type": "Text"}"#], more: false))
            }
            #expect(try await client().channelBlocks(slug: "c").map(\.id) == [1])
        }

        @Test func readsImageVariantsAndContentType() async throws {
            StubURLProtocol.reset { _ in
                StubURLProtocol.json(pageJSON([
                    imageJSON(id: 1, contentType: "image/gif", smallWidth: 300, mediumWidth: 640, largeWidth: 1200),
                    imageJSON(id: 2, width: nil, height: nil, fileSize: nil, smallWidth: nil, mediumWidth: nil, largeWidth: nil),
                ], more: false))
            }
            let blocks = try await client().channelBlocks(slug: "c")
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
            _ = try await client().channelBlocks(slug: "c")
            _ = try await client(token: nil).channelBlocks(slug: "c")
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
                (.init(status: 429, headers: ["Retry-After": "30"]), .rateLimited(retryAfterSeconds: 30)),
                (.init(status: 429), .rateLimited(retryAfterSeconds: 60)),
                (.init(status: 500), .network("HTTP 500")),
            ]
            for (reply, expected) in cases {
                StubURLProtocol.reset { _ in reply }
                await #expect(throws: expected) { try await client().channelBlocks(slug: "c") }
            }
        }

        @Test func emptyChannelReturnsEmpty() async throws {
            StubURLProtocol.reset { _ in StubURLProtocol.json(pageJSON([], more: false)) }
            #expect(try await client().channelBlocks(slug: "c").isEmpty)
        }

        @Test func unusableImagesAreDropped() async throws {
            StubURLProtocol.reset { _ in
                StubURLProtocol.json(pageJSON([imageJSON(id: 1, fileSize: 52_428_801), imageJSON(id: 2)], more: false))
            }
            #expect(try await client().channelBlocks(slug: "c").map(\.id) == [2])
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
