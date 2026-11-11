import Foundation
import Testing
@testable import ArenaKit

private func library(_ repository: ConfigRepository) -> LibraryService {
    LibraryService(repository: repository) {
        ArenaClient(token: "t", userAgent: "ArenaWallpaper/0.1.0", gate: RequestGate(minInterval: 0), baseURL: URL(string: "https://api.test")!, session: StubURLProtocol.session())
    }
}

private func repositoryWith(_ channels: [Channel]) async throws -> ConfigRepository {
    let repository = ConfigRepository(store: ConfigStore(directory: makeTempDirectory()))
    try await repository.update { $0.channels = channels }
    return repository
}

extension Network {
    @Suite struct LibraryServiceTests {
        @Test func addChannelRejectsDuplicatesAndBadInput() async throws {
            StubURLProtocol.reset { _ in StubURLProtocol.json(pageJSON([imageJSON(id: 1)], more: false)) }
            let repository = try await repositoryWith([])
            let service = library(repository)
            let added = try await service.addChannel(input: "https://www.are.na/jean/mon-channel")
            #expect(added.slug == "mon-channel" && added.blocks.map(\.id) == [1])
            await #expect(throws: LibraryError.alreadyAdded) { try await service.addChannel(input: "mon-channel") }
            await #expect(throws: LibraryError.invalidChannel) { try await service.addChannel(input: "deux mots") }
            #expect(await repository.config.channels.map(\.slug) == ["mon-channel"])
        }

        @Test func refreshKeepsChannelsThatFail() async throws {
            StubURLProtocol.reset { request in
                request.url!.path.contains("/a/") ? .init(status: 404) : StubURLProtocol.json(pageJSON([imageJSON(id: 2)], more: false))
            }
            let repository = try await repositoryWith([Channel(slug: "a", blocks: [testBlock(1)]), Channel(slug: "b")])
            let failures = await library(repository).refreshAll()
            #expect(failures == ["a": .notFound])
            let channels = await repository.config.channels
            #expect(channels[0].blocks.map(\.id) == [1])
            #expect(channels[1].blocks.map(\.id) == [2])
        }

        @Test func refreshReportsUnauthorized() async throws {
            StubURLProtocol.reset { _ in .init(status: 401) }
            let repository = try await repositoryWith([Channel(slug: "a", blocks: [testBlock(1)]), Channel(slug: "b")])
            #expect(await library(repository).refreshAll() == ["a": .unauthorized, "b": .unauthorized])
            #expect(await repository.config.channels[0].blocks.map(\.id) == [1])
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
