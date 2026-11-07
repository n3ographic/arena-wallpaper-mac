import Foundation
import Testing
@testable import ArenaKit

private func sampleBlock(id: Int) -> Block {
    Block(
        id: id, title: "t\(id)",
        fullURL: URL(string: "https://x/\(id).jpg")!,
        thumbURL: URL(string: "https://x/\(id)-s.jpg")!,
        previewURL: URL(string: "https://x/\(id)-l.jpg")!,
        width: 2000, height: 1200, fileSize: 5000, contentType: "image/jpeg"
    )
}

@Test func configRoundTrips() throws {
    let store = ConfigStore(directory: makeTempDirectory())
    var config = Config()
    config.channels = [Channel(slug: "c", enabled: false, blocks: [sampleBlock(id: 1)])]
    config.intervalMinutes = 5
    config.order = .ordered
    config.screenMode = .span
    config.fit = .contain
    config.positionX = 0
    config.positionY = 100
    config.background = .color(hex: "#112233")
    config.matchOrientation = false
    config.excluded = [7, 9]
    config.hideSensitive = false
    config.sensitiveVerdicts = [3: true]
    config.sensitiveAllowed = [3]
    try store.save(config)
    #expect(store.load() == config)
}

@Test func missingFileGivesDefault() {
    #expect(ConfigStore(directory: makeTempDirectory()).load() == Config())
}

@Test func corruptFileGivesDefault() throws {
    let dir = makeTempDirectory()
    try Data("{ pas du json".utf8).write(to: dir.appendingPathComponent("config.json"))
    #expect(ConfigStore(directory: dir).load() == Config())
}

@Test func oldFileWithoutNewKeysUsesDefaults() throws {
    let dir = makeTempDirectory()
    try Data(#"{"schemaVersion":1,"channels":[],"intervalMinutes":12}"#.utf8).write(to: dir.appendingPathComponent("config.json"))
    let config = ConfigStore(directory: dir).load()
    #expect(config.intervalMinutes == 12)
    #expect(config.fit == .fill)
    #expect(config.positionX == 50)
    #expect(config.matchOrientation)
    #expect(config.hideSensitive)
    #expect(config.excluded.isEmpty)
}

@Test func positionsAreClampedTo0Through100() throws {
    let config = try JSONDecoder().decode(Config.self, from: Data(#"{"positionX":150,"positionY":-5}"#.utf8))
    #expect(config.positionX == 100)
    #expect(config.positionY == 0)
}

@Test func repositoryUpdatePersists() async throws {
    let dir = makeTempDirectory()
    let repository = ConfigRepository(store: ConfigStore(directory: dir))
    let updated = try await repository.update { $0.intervalMinutes = 5 }
    #expect(updated.intervalMinutes == 5)
    #expect(await repository.config.intervalMinutes == 5)
    #expect(ConfigStore(directory: dir).load().intervalMinutes == 5)
}

@Test func gifIsDetectedFromContentType() {
    var block = sampleBlock(id: 1)
    #expect(!block.isGIF)
    block.contentType = "image/gif"
    #expect(block.isGIF)
}
