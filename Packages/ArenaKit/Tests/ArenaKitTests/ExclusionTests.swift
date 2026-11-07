import Foundation
import Testing
@testable import ArenaKit

@Test func toggleExcludesThenReincludes() {
    var config = Config()
    config.excluded = [5]
    toggleExclusion([1, 2], in: &config)
    #expect(Set(config.excluded) == [5, 1, 2])
    toggleExclusion([1, 2], in: &config)
    #expect(config.excluded == [5])
}

@Test func toggleWithPartlyExcludedImagesExcludesAll() {
    var config = Config()
    config.excluded = [1]
    toggleExclusion([1, 2], in: &config)
    #expect(Set(config.excluded) == [1, 2])
    #expect(config.excluded.count == 2)
}

@Test func excludedImagesLeaveThePool() {
    var config = Config()
    config.channels = [Channel(slug: "a", blocks: [1, 2, 3].map { testBlock($0) })]
    toggleExclusion([2], in: &config)
    #expect(enabledPool(config) == [1, 3])
    #expect(config.channels[0].blocks.count == 3)
}

@Test func blockURLPointsToAreNa() {
    #expect(blockURL(42).absoluteString == "https://www.are.na/block/42")
}
