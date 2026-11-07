import Foundation
import Testing
@testable import ArenaKit

private let mainScreen = testScreen("main", 0, 0, 192, 108)
private let rightScreen = testScreen("right", 192, 0, 128, 102)

private func service(_ repository: ConfigRepository, _ cache: ImageCache, _ rendered: URL, setter: RecordingSetter, player: RecordingPlayer = RecordingPlayer()) -> WallpaperService {
    let clock = TestClock()
    return WallpaperService(repository: repository, cache: cache, renderedDirectory: rendered, setter: setter, player: player, checker: NoSensitivityChecker(), now: { clock.now() })
}

private func renderedFiles(_ dir: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: dir.path).sorted()
}

@Test func writesOneFilePerScreenAndSetsEach() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2], mode: .perScreen)
    let setter = RecordingSetter()
    try await service(repository, cache, rendered, setter: setter).apply(ids: [1, 2], screens: [mainScreen, rightScreen])
    let calls = await setter.calls
    #expect(calls.map(\.screenID) == ["main", "right"])
    #expect(calls[0].file.lastPathComponent.range(of: #"^0-1-\d+\.png$"#, options: .regularExpression) != nil)
    #expect(calls[1].file.lastPathComponent.range(of: #"^1-2-\d+\.png$"#, options: .regularExpression) != nil)
    #expect(try renderedFiles(rendered).count == 2)
}

@Test func spanCropsOneCanvasAcrossScreens() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1], mode: .span)
    let setter = RecordingSetter()
    let left = testScreen("left", -128, 0, 128, 102)
    try await service(repository, cache, rendered, setter: setter).apply(ids: [1, 1], screens: [mainScreen, left])
    let files = await setter.calls.map(\.file)
    let sizes = try files.map { file -> (Int, Int) in
        let image = try Renderer.loadFirstFrame(file)
        return (image.width, image.height)
    }
    #expect(sizes[0] == (192, 108))
    #expect(sizes[1] == (128, 102))
}

@Test func keepsThreeGenerationsPerScreen() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2], mode: .perScreen)
    let wallpaper = service(repository, cache, rendered, setter: RecordingSetter())
    for _ in 0..<5 {
        try await wallpaper.apply(ids: [1, 2], screens: [mainScreen, rightScreen])
    }
    #expect(try renderedFiles(rendered).count <= 6)
}

@Test func oneScreenFailureDoesNotStopTheOther() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1])
    let setter = RecordingSetter(failing: ["main"])
    try await service(repository, cache, rendered, setter: setter).apply(ids: [1, 1], screens: [mainScreen, rightScreen])
    #expect(await setter.calls.map(\.screenID) == ["main", "right"])
}

@Test func allScreensFailingThrows() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1])
    let setter = RecordingSetter(failing: ["main", "right"])
    let wallpaper = service(repository, cache, rendered, setter: setter)
    await #expect(throws: ApplyError.self) { try await wallpaper.apply(ids: [1, 1], screens: [mainScreen, rightScreen]) }
    #expect(await wallpaper.current.isEmpty)
}

@Test func currentIsUpdatedOnSuccess() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2], mode: .perScreen)
    let player = RecordingPlayer()
    let wallpaper = service(repository, cache, rendered, setter: RecordingSetter(), player: player)
    try await wallpaper.apply(ids: [1, 2], screens: [mainScreen, rightScreen])
    #expect(await wallpaper.current == [1, 2])
    #expect(await player.shown == [[]])
}

@Test func unknownImageIsRejected() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1])
    await #expect(throws: ApplyError.unknownImage(99)) {
        try await service(repository, cache, rendered, setter: RecordingSetter()).apply(ids: [99], screens: [mainScreen])
    }
}

@Test func undecodableOriginalIsDiscarded() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1])
    let original = try #require(await cache.cachedURL(for: 1))
    try Data("abîmé".utf8).write(to: original)
    await #expect(throws: RenderError.unreadable) {
        try await service(repository, cache, rendered, setter: RecordingSetter()).apply(ids: [1], screens: [mainScreen])
    }
    #expect(await cache.cachedURL(for: 1) == nil)
}

@Test func reapplySetsTheSameFilesAgain() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2], mode: .perScreen)
    let setter = RecordingSetter()
    let wallpaper = service(repository, cache, rendered, setter: setter)
    try await wallpaper.apply(ids: [1, 2], screens: [mainScreen, rightScreen])
    await wallpaper.reapply()
    let calls = await setter.calls
    #expect(calls.count == 4)
    #expect(calls[2].file == calls[0].file && calls[3].file == calls[1].file)
    #expect(calls[2].screenID == "main" && calls[3].screenID == "right")
}

@Test func animatedGIFIsSentToThePlayer() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1], gifIDs: [1])
    let player = RecordingPlayer()
    let wallpaper = service(repository, cache, rendered, setter: RecordingSetter(), player: player)
    try await wallpaper.apply(ids: [1], screens: [mainScreen])
    let shown = try #require(await player.shown.last)
    #expect(shown.count == 1)
    #expect(shown.first?.gif == (await cache.cachedURL(for: 1)))
    #expect(shown.first?.screenID == "main")
}

@Test func reduceMotionKeepsGIFsStill() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1], gifIDs: [1])
    let player = RecordingPlayer()
    let wallpaper = WallpaperService(
        repository: repository, cache: cache, renderedDirectory: rendered, setter: RecordingSetter(), player: player,
        checker: NoSensitivityChecker(), reduceMotion: { true }
    )
    try await wallpaper.apply(ids: [1], screens: [mainScreen])
    #expect(await player.shown == [[]])
}

@Test func reduceMotionTurnedOnLaterStopsTheAnimation() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1], gifIDs: [1])
    let player = RecordingPlayer()
    let flag = ReduceMotionFlag()
    let wallpaper = WallpaperService(
        repository: repository, cache: cache, renderedDirectory: rendered, setter: RecordingSetter(), player: player,
        checker: NoSensitivityChecker(), reduceMotion: { flag.value }
    )
    try await wallpaper.apply(ids: [1], screens: [mainScreen])
    #expect(await player.shown.last?.count == 1)
    flag.value = true
    await wallpaper.refreshAnimations()
    #expect(await player.shown.last == [])
}

/// Holds `isSensitive` for the image 1 until released, so a newer application can finish first.
private actor GateChecker: SensitivityChecker {
    private var waiting: CheckedContinuation<Void, Never>?
    private(set) var isHolding = false

    func isActive() async -> Bool { true }

    func isSensitive(_ file: URL) async throws -> Bool {
        if file.lastPathComponent == "1" {
            isHolding = true
            await withCheckedContinuation { waiting = $0 }
        }
        return false
    }

    func release() {
        waiting?.resume()
        waiting = nil
    }
}

@Test func olderApplicationDoesNotOverrideANewerOne() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2])
    let setter = RecordingSetter()
    let gate = GateChecker()
    let wallpaper = WallpaperService(repository: repository, cache: cache, renderedDirectory: rendered, setter: setter, player: RecordingPlayer(), checker: gate)
    let older = Task { try await wallpaper.apply(ids: [1], screens: [mainScreen]) }
    while await !gate.isHolding { await Task.yield() }
    try await wallpaper.apply(ids: [2], screens: [mainScreen])
    await gate.release()
    try await older.value
    #expect(await setter.calls.count == 1)
    #expect(await wallpaper.current == [2])
}
