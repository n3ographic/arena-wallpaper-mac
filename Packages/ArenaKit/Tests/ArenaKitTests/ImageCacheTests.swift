import Foundation
import Testing
@testable import ArenaKit

func testBlock(_ id: Int, url: String = "https://img/x.png") -> Block {
    Block(id: id, title: "t\(id)", fullURL: URL(string: url)!, thumbURL: URL(string: url)!, previewURL: URL(string: url)!)
}

extension Network {
    @Suite struct ImageCacheTests {
        @Test func downloadsOnceThenServesFromCache() async throws {
            StubURLProtocol.reset { _ in .init(status: 200, body: pngData(width: 100, height: 100)) }
            let dir = makeTempDirectory()
            let cache = ImageCache(directory: dir, session: StubURLProtocol.session())
            let first = try await cache.original(for: testBlock(1))
            let second = try await cache.original(for: testBlock(1))
            #expect(first == second)
            #expect(first.lastPathComponent == "1")
            #expect(FileManager.default.fileExists(atPath: first.path))
            #expect(StubURLProtocol.requests.count == 1)
            #expect(await cache.cachedURL(for: 1) == first)
            #expect(await cache.cachedURL(for: 2) == nil)
        }

        @Test func unreadableDownloadIsDeleted() async throws {
            StubURLProtocol.reset { _ in .init(status: 200, body: Data("pas une image".utf8)) }
            let dir = makeTempDirectory()
            let cache = ImageCache(directory: dir, session: StubURLProtocol.session())
            await #expect(throws: ImageCacheError.unreadable) { try await cache.original(for: testBlock(1)) }
            #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
        }

        @Test func oversizedDownloadIsRejected() async throws {
            StubURLProtocol.reset { _ in .init(status: 200, body: pngData(width: 100, height: 100)) }
            let dir = makeTempDirectory()
            let byPixels = ImageCache(directory: dir, session: StubURLProtocol.session(), maxPixels: 9_999)
            await #expect(throws: ImageCacheError.tooLarge) { try await byPixels.original(for: testBlock(1)) }
            let byBytes = ImageCache(directory: dir, session: StubURLProtocol.session(), maxBytes: 10)
            await #expect(throws: ImageCacheError.tooLarge) { try await byBytes.original(for: testBlock(1)) }
            #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
        }

        @Test func failedDownloadIsReported() async {
            StubURLProtocol.reset { _ in .init(status: 503) }
            let cache = ImageCache(directory: makeTempDirectory(), session: StubURLProtocol.session())
            await #expect(throws: ImageCacheError.download("HTTP 503")) { try await cache.original(for: testBlock(1)) }
        }
    }
}

@Test func downloadRefusesNonHTTPS() async throws {
    await #expect(throws: ImageCacheError.download("not https")) {
        try await downloadImage(URL(string: "http://img/x.png")!)
    }
    await #expect(throws: ImageCacheError.download("not https")) {
        try await downloadImage(URL(fileURLWithPath: "/etc/hosts"))
    }
}
