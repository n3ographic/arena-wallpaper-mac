import Foundation
import Testing
@testable import ArenaKit

@Test func diskUsageCountsCachedFilesAndClearEmptiesIt() async throws {
    let dir = makeTempDirectory()
    try Data(count: 1000).write(to: dir.appendingPathComponent("1"))
    try Data(count: 500).write(to: dir.appendingPathComponent("2"))
    let cache = ImageCache(directory: dir)
    #expect(await cache.diskUsage() == 1500)
    await cache.clear()
    #expect(await cache.diskUsage() == 0)
    #expect(await cache.cachedURL(for: 1) == nil)
}

@Test func diskUsageOfMissingDirectoryIsZero() async {
    let cache = ImageCache(directory: makeTempDirectory().appendingPathComponent("absent"))
    #expect(await cache.diskUsage() == 0)
}
