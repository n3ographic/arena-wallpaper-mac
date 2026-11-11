import Foundation
import Testing
@testable import ArenaKit

private let fixedNow = Date(timeIntervalSince1970: 2_000_000)

private func library(_ repository: ConfigRepository) -> LibraryService {
    LibraryService(repository: repository, now: { fixedNow }) {
        ArenaClient(token: "t", userAgent: "ArenaWallpaper/0.1.0", gate: RequestGate(minInterval: 0), baseURL: URL(string: "https://api.test")!, session: StubURLProtocol.session())
    }
}

private func repositoryWith(_ channels: [Channel]) async throws -> ConfigRepository {
    let repository = ConfigRepository(store: ConfigStore(directory: makeTempDirectory()))
    try await repository.update { $0.channels = channels }
    return repository
}

private func pageReply(_ ids: [Int], more: Bool, etag: String? = nil, titled: String? = nil) -> StubURLProtocol.Reply {
    var headers = ["Content-Type": "application/json"]
    if let etag { headers["ETag"] = etag }
    let items = ids.map { id in
        titled.map { imageJSON(id: id).replacingOccurrences(of: "\"t\(id)\"", with: "\"\($0)\"") } ?? imageJSON(id: id)
    }
    return StubURLProtocol.Reply(status: 200, headers: headers, body: Data(pageJSON(items, more: more).utf8))
}

private func pageNumber(_ request: URLRequest) -> Int {
    URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "page" }.flatMap { Int($0.value!) }!
}

extension Network {
    @Suite struct LibraryServiceTests {
        @Test func addChannelLoadsOnePage() async throws {
            StubURLProtocol.reset { _ in pageReply([1, 2], more: true, etag: #"W/"e1""#) }
            let repository = try await repositoryWith([])
            let service = library(repository)
            let added = try await service.addChannel(input: "https://www.are.na/jean/mon-channel")
            #expect(added.slug == "mon-channel" && added.blocks.map(\.id) == [1, 2])
            #expect(StubURLProtocol.requests.count == 1)
            #expect(pageNumber(StubURLProtocol.requests[0]) == 1)
            #expect(added.nextPage == 2 && added.etag == #"W/"e1""# && added.lastRefresh == fixedNow)
            await #expect(throws: LibraryError.alreadyAdded) { try await service.addChannel(input: "mon-channel") }
            await #expect(throws: LibraryError.invalidChannel) { try await service.addChannel(input: "deux mots") }
            #expect(await repository.config.channels.map(\.slug) == ["mon-channel"])
        }

        @Test func addChannelWithoutMorePagesHasNoNextPage() async throws {
            StubURLProtocol.reset { _ in pageReply([1], more: false) }
            let added = try await library(try await repositoryWith([])).addChannel(input: "c")
            #expect(added.nextPage == nil)
        }

        @Test func loadMoreAppendsAndAdvances() async throws {
            StubURLProtocol.reset { _ in pageReply([3, 4], more: false) }
            let repository = try await repositoryWith([Channel(slug: "a", blocks: [testBlock(1), testBlock(2)], nextPage: 2)])
            let service = library(repository)
            #expect(try await service.loadMore(slug: "a") == 2)
            let channel = await repository.config.channels[0]
            #expect(channel.blocks.map(\.id) == [1, 2, 3, 4] && channel.nextPage == nil)
            #expect(pageNumber(StubURLProtocol.requests[0]) == 2)
            #expect(try await service.loadMore(slug: "a") == 0)
            #expect(StubURLProtocol.requests.count == 1)
        }

        @Test func loadMoreSkipsKnownBlocks() async throws {
            StubURLProtocol.reset { _ in pageReply([2, 3], more: true) }
            let repository = try await repositoryWith([Channel(slug: "a", blocks: [testBlock(1), testBlock(2)], nextPage: 2)])
            #expect(try await library(repository).loadMore(slug: "a") == 1)
            let channel = await repository.config.channels[0]
            #expect(channel.blocks.map(\.id) == [1, 2, 3] && channel.nextPage == 3)
        }

        @Test func concurrentLoadMoreSendsOneRequest() async throws {
            StubURLProtocol.reset { _ in pageReply([3], more: false) }
            let repository = try await repositoryWith([Channel(slug: "a", blocks: [testBlock(1)], nextPage: 2)])
            let service = library(repository)
            async let first = service.loadMore(slug: "a")
            async let second = service.loadMore(slug: "a")
            let counts = try await [first, second].sorted()
            #expect(counts == [0, 1])
            #expect(StubURLProtocol.requests.count == 1)
        }

        @Test func refreshSkipsFreshChannels() async throws {
            StubURLProtocol.reset { _ in .init(status: 304) }
            let fresh = Channel(slug: "a", blocks: [testBlock(1)], etag: #"W/"e1""#, lastRefresh: fixedNow.addingTimeInterval(-3600))
            let service = library(try await repositoryWith([fresh]))
            try await service.refresh(slug: "a", force: false)
            #expect(StubURLProtocol.requests.isEmpty)
            try await service.refresh(slug: "a", force: true)
            #expect(StubURLProtocol.requests.count == 1)
            #expect(StubURLProtocol.requests[0].value(forHTTPHeaderField: "If-None-Match") == #"W/"e1""#)
        }

        @Test func staleChannelsAreRevalidated() async throws {
            StubURLProtocol.reset { _ in .init(status: 304) }
            let old = Channel(slug: "a", blocks: [testBlock(1)], lastRefresh: fixedNow.addingTimeInterval(-LibraryService.refreshInterval - 1))
            try await library(try await repositoryWith([old])).refresh(slug: "a", force: false)
            #expect(StubURLProtocol.requests.count == 1)
        }

        @Test func notModifiedOnlyTouchesLastRefresh() async throws {
            StubURLProtocol.reset { _ in .init(status: 304) }
            let old = Channel(slug: "a", blocks: [testBlock(1)], nextPage: 2, etag: #"W/"e1""#, lastRefresh: fixedNow.addingTimeInterval(-90_000))
            let repository = try await repositoryWith([old])
            try await library(repository).refresh(slug: "a", force: false)
            let channel = await repository.config.channels[0]
            #expect(channel.blocks.map(\.id) == [1] && channel.etag == #"W/"e1""# && channel.nextPage == 2)
            #expect(channel.lastRefresh == fixedNow)
        }

        @Test func refreshMergesPageOne() async throws {
            StubURLProtocol.reset { _ in pageReply([9, 1, 2], more: true, etag: #"W/"e2""#, titled: "nouveau") }
            let old = Channel(slug: "a", blocks: [testBlock(1), testBlock(2), testBlock(50)], nextPage: 3, etag: #"W/"e1""#, lastRefresh: fixedNow.addingTimeInterval(-90_000))
            let repository = try await repositoryWith([old])
            try await library(repository).refresh(slug: "a", force: false)
            let channel = await repository.config.channels[0]
            #expect(channel.blocks.map(\.id) == [9, 1, 2, 50])
            #expect(channel.blocks[1].title == "nouveau")
            #expect(channel.etag == #"W/"e2""# && channel.nextPage == 3 && channel.lastRefresh == fixedNow)
        }

        @Test func refreshKeepsChannelsThatFail() async throws {
            StubURLProtocol.reset { request in
                request.url!.path.contains("/a/") ? .init(status: 404) : pageReply([2], more: false)
            }
            let repository = try await repositoryWith([Channel(slug: "a", blocks: [testBlock(1)]), Channel(slug: "b")])
            let failures = await library(repository).refreshAll(force: true)
            #expect(failures == ["a": .notFound])
            let channels = await repository.config.channels
            #expect(channels[0].blocks.map(\.id) == [1])
            #expect(channels[1].blocks.map(\.id) == [2])
        }

        @Test func refreshReportsUnauthorized() async throws {
            StubURLProtocol.reset { _ in .init(status: 401) }
            let repository = try await repositoryWith([Channel(slug: "a", blocks: [testBlock(1)]), Channel(slug: "b")])
            #expect(await library(repository).refreshAll(force: true) == ["a": .unauthorized, "b": .unauthorized])
            #expect(await repository.config.channels[0].blocks.map(\.id) == [1])
        }

        @Test func refreshAllStopsAtTheFirstRateLimit() async throws {
            StubURLProtocol.reset { _ in .init(status: 429) }
            let repository = try await repositoryWith([Channel(slug: "a"), Channel(slug: "b")])
            let failures = await library(repository).refreshAll(force: true)
            #expect(failures == ["a": .rateLimited(retryAfterSeconds: 60)])
            #expect(StubURLProtocol.requests.count == 1)
        }

        @Test func failedRefreshAlsoWaitsADay() async throws {
            for status in [404, 500, 429] {
                StubURLProtocol.reset { _ in .init(status: status) }
                let repository = try await repositoryWith([Channel(slug: "a", blocks: [testBlock(1)])])
                let service = library(repository)
                await #expect(throws: ArenaError.self) { try await service.refresh(slug: "a", force: false) }
                #expect(await repository.config.channels[0].lastRefresh == fixedNow)
                try await service.refresh(slug: "a", force: false)
                #expect(StubURLProtocol.requests.count == 1, "status \(status)")
            }
        }

        @Test func unauthorizedRefreshCanBeRetriedAfterSigningIn() async throws {
            StubURLProtocol.reset { _ in .init(status: 401) }
            let repository = try await repositoryWith([Channel(slug: "a")])
            await #expect(throws: ArenaError.unauthorized) { try await library(repository).refresh(slug: "a", force: false) }
            #expect(await repository.config.channels[0].lastRefresh == nil)
        }

        @Test func channelToGrowCanSkipChannels() async throws {
            let repository = try await repositoryWith([Channel(slug: "a", nextPage: 2), Channel(slug: "b", nextPage: 2)])
            let service = library(repository)
            #expect(await service.channelToGrow(excluding: ["a"]) == "b")
            #expect(await service.channelToGrow(excluding: ["a", "b"]) == nil)
        }

        @Test func channelToGrowSkipsDisabledAndFinished() async throws {
            let repository = try await repositoryWith([
                Channel(slug: "a", enabled: false, nextPage: 2), Channel(slug: "b"), Channel(slug: "c", nextPage: 3),
            ])
            #expect(await library(repository).channelToGrow() == "c")
        }

        @Test func removeAndEnable() async throws {
            let repository = try await repositoryWith([Channel(slug: "a"), Channel(slug: "b")])
            let service = library(repository)
            try await service.setEnabled(slug: "a", enabled: false)
            try await service.removeChannel(slug: "b")
            let channels = await repository.config.channels
            #expect(channels.map(\.slug) == ["a"])
            #expect(channels[0].enabled == false)
        }
    }
}
