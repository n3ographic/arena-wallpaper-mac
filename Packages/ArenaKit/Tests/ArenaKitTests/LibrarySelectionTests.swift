import Testing
@testable import ArenaKit

private func config() -> Config {
    var config = Config()
    config.channels = [
        Channel(slug: "a", blocks: [testBlock(1), testBlock(2)]),
        Channel(slug: "off", enabled: false, blocks: [testBlock(3)]),
        Channel(slug: "b", blocks: [testBlock(2), testBlock(4)]),
    ]
    config.excluded = [3, 4]
    return config
}

@Test func allSkipsDisabledChannelsAndRemovedImages() {
    #expect(blocks(for: .all, in: config()).map(\.id) == [1, 2])
}

@Test func removedListsExcludedAcrossChannels() {
    #expect(blocks(for: .all, in: config(), removed: true).map(\.id) == [3, 4])
}

@Test func removedFiltersAChannel() {
    #expect(blocks(for: .channel("b"), in: config(), removed: true).map(\.id) == [4])
}

@Test func channelKeepsOrderWithoutRemovedImages() {
    #expect(blocks(for: .channel("b"), in: config()).map(\.id) == [2])
    #expect(blocks(for: .channel("a"), in: config()).map(\.id) == [1, 2])
    #expect(blocks(for: .channel("unknown"), in: config()).isEmpty)
}

@Test func duplicateIdsAppearOnce() {
    #expect(blocks(for: .all, in: config()).filter { $0.id == 2 }.count == 1)
}
