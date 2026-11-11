import Foundation
import Testing
@testable import ArenaKit

private struct FixedScreens: ScreenProvider {
    let list: [Screen]
    func screens() async -> [Screen] { list }
}

private let landscape = testScreen("landscape", 0, 0, 192, 108)
private let portrait = testScreen("portrait", 192, 0, 108, 192)

private func engine(
    _ repository: ConfigRepository, _ cache: ImageCache, _ rendered: URL, setter: RecordingSetter,
    screens: [Screen] = [landscape], now: @escaping @Sendable () -> Date = { Date(timeIntervalSince1970: 1_000) }
) -> RotationEngine {
    let wallpaper = WallpaperService(repository: repository, cache: cache, renderedDirectory: rendered, setter: setter, player: RecordingPlayer())
    return RotationEngine(repository: repository, wallpaper: wallpaper, screens: FixedScreens(list: screens), cache: cache, now: now)
}

@Test func rotateWithEmptyPoolDoesNothing() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [])
    let setter = RecordingSetter()
    let rotation = engine(repository, cache, rendered, setter: setter)
    try await rotation.rotate(manual: false)
    #expect(await setter.calls.isEmpty)
    #expect(await rotation.nowPlaying.ids.isEmpty)
}

@Test func timerRotationDoesNothingWhilePaused() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1])
    let setter = RecordingSetter()
    let rotation = engine(repository, cache, rendered, setter: setter)
    await rotation.setPaused(true)
    try await rotation.rotate(manual: false)
    #expect(await setter.calls.isEmpty)
}

@Test func manualRotationWorksWhilePaused() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1])
    let setter = RecordingSetter()
    let rotation = engine(repository, cache, rendered, setter: setter)
    await rotation.setPaused(true)
    try await rotation.rotate(manual: true)
    #expect(await setter.calls.count == 1)
    #expect(await rotation.nowPlaying == NowPlaying(ids: [1], nextChange: nil, paused: true))
}

@Test func perScreenWithOrientationPicksMatchingImages() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [2, 1], mode: .perScreen)
    try await repository.update { config in
        config.order = .ordered
        config.channels[0].blocks[0].width = 1000   // id 2: portrait
        config.channels[0].blocks[0].height = 2000
        config.channels[0].blocks[1].width = 2000   // id 1: landscape
        config.channels[0].blocks[1].height = 1000
    }
    let rotation = engine(repository, cache, rendered, setter: RecordingSetter(), screens: [landscape, portrait])
    try await rotation.rotate(manual: false)
    #expect(await rotation.nowPlaying.ids == [1, 2])
}

@Test func scheduleNextAddsIntervalAndClampsToOneMinute() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1])
    let rotation = engine(repository, cache, rendered, setter: RecordingSetter())
    try await repository.update { $0.intervalMinutes = 0 }
    #expect(await rotation.scheduleNext() == Date(timeIntervalSince1970: 1_060))
    try await repository.update { $0.intervalMinutes = 30 }
    #expect(await rotation.scheduleNext() == Date(timeIntervalSince1970: 2_800))
    #expect(await rotation.nowPlaying.nextChange == Date(timeIntervalSince1970: 2_800))
}

@Test func observersReceiveNowPlayingChanges() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1])
    let rotation = engine(repository, cache, rendered, setter: RecordingSetter())
    var updates = await rotation.observe().makeAsyncIterator()
    #expect(await updates.next() == NowPlaying(ids: [], nextChange: nil, paused: false))
    await rotation.setPaused(true)
    #expect(await updates.next()?.paused == true)
    try await rotation.rotate(manual: true)
    #expect(await updates.next()?.ids == [1])
}

extension Network {
    @Suite struct RotationFallback {
        @Test func rotateFallsBackToCachedImagesWhenDownloadsFail() async throws {
            StubURLProtocol.reset { _ in .init(status: 503) }
            let (repository, seeded, rendered) = try await fixture(ids: [6])
            try await repository.update { config in
                config.order = .ordered
                config.channels[0].blocks = [1, 2, 3, 4, 5].map { testBlock($0) } + config.channels[0].blocks
            }
            let originals = try #require(await seeded.cachedURL(for: 6)).deletingLastPathComponent()
            let cache = ImageCache(directory: originals, session: StubURLProtocol.session())
            let setter = RecordingSetter()
            let rotation = engine(repository, cache, rendered, setter: setter)
            try await rotation.rotate(manual: false)
            #expect(await rotation.nowPlaying.ids == [6])
            #expect(StubURLProtocol.requests.count == 5)
        }
    }
}

@Test func cancelledRotationAppliesNothing() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2])
    let setter = RecordingSetter()
    let rotation = engine(repository, cache, rendered, setter: setter)
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        try await rotation.rotate(manual: false)
    }
    try? await task.value
    #expect(await setter.calls.isEmpty)
}

/// Counts the calls of `onLowPool` and holds each one until released.
private actor LowPoolProbe {
    private(set) var calls = 0
    private var released = false

    func handler() async {
        calls += 1
        while !released { await Task.yield() }
    }

    func release() { released = true }
}

@Test func lowPoolAsksForMoreOnce() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2, 3, 4, 5])
    let rotation = engine(repository, cache, rendered, setter: RecordingSetter())
    let probe = LowPoolProbe()
    await rotation.setOnLowPool { await probe.handler() }
    try await rotation.rotate(manual: true)
    while await probe.calls == 0 { await Task.yield() }
    try await rotation.rotate(manual: true)
    for _ in 0..<50 { await Task.yield() }
    #expect(await probe.calls == 1)
    await probe.release()
    for _ in 0..<500 where await probe.calls < 2 {
        try await rotation.rotate(manual: true)
        await Task.yield()
    }
    #expect(await probe.calls >= 2)
}

@Test func gridClickDoesNotAskForMore() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2, 3, 4, 5])
    let rotation = engine(repository, cache, rendered, setter: RecordingSetter())
    let probe = LowPoolProbe()
    await rotation.setOnLowPool { await probe.handler() }
    try await rotation.apply(ids: [1], screens: [landscape])
    for _ in 0..<50 { await Task.yield() }
    #expect(await probe.calls == 0)
}
