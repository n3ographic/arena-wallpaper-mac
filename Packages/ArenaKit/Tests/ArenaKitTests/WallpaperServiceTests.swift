import Foundation
import Testing
@testable import ArenaKit

private let mainScreen = testScreen("main", 0, 0, 192, 108)
private let rightScreen = testScreen("right", 192, 0, 128, 102)

private func service(_ repository: ConfigRepository, _ cache: ImageCache, _ rendered: URL, setter: RecordingSetter, player: RecordingPlayer = RecordingPlayer()) -> WallpaperService {
    let clock = TestClock()
    return WallpaperService(repository: repository, cache: cache, renderedDirectory: rendered, setter: setter, player: player, now: { clock.now() })
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
        reduceMotion: { true }
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
        reduceMotion: { flag.value }
    )
    try await wallpaper.apply(ids: [1], screens: [mainScreen])
    #expect(await player.shown.last?.count == 1)
    flag.value = true
    await wallpaper.refreshAnimations()
    #expect(await player.shown.last == [])
}

/// Holds the call for the image 1 (file "0-1-...") until released, so a newer application can finish first.
private actor GateSetter: WallpaperSetter {
    private var waiting: CheckedContinuation<Void, Never>?
    private(set) var isHolding = false

    func setWallpaper(_ file: URL, screenID: String) async throws {
        if file.lastPathComponent.hasPrefix("0-1-") {
            isHolding = true
            await withCheckedContinuation { waiting = $0 }
        }
    }

    func release() {
        waiting?.resume()
        waiting = nil
    }
}

@Test func olderApplicationDoesNotOverrideANewerOne() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2])
    let gate = GateSetter()
    let wallpaper = WallpaperService(repository: repository, cache: cache, renderedDirectory: rendered, setter: gate, player: RecordingPlayer())
    let older = Task { try await wallpaper.apply(ids: [1], screens: [mainScreen]) }
    while await !gate.isHolding { await Task.yield() }
    try await wallpaper.apply(ids: [2], screens: [mainScreen])
    await gate.release()
    try await older.value
    #expect(await wallpaper.current == [2])
}

// MARK: Per-screen framing

private let greenBands = Framing(fit: .contain, background: .color(hex: "#00ff00"))

@Test func perScreenFramingIsUsed() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2], mode: .perScreen)
    try await repository.update { $0.setFraming(greenBands, for: "right") }
    let setter = RecordingSetter()
    try await service(repository, cache, rendered, setter: setter).apply(ids: [1, 2], screens: [mainScreen, rightScreen])
    let files = await setter.calls.map(\.file)
    let a = try Renderer.loadFirstFrame(files[0]), b = try Renderer.loadFirstFrame(files[1])
    #expect(pixel(a, 0, 0).r > 235)
    let band = pixel(b, 64, 0)
    #expect(band.g > 235 && band.r < 20)
}

@Test func spanUsesDefaultFraming() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1], mode: .span)
    try await repository.update { $0.setFraming(greenBands, for: "main") }
    let setter = RecordingSetter()
    let left = testScreen("left", -128, 0, 128, 102)
    try await service(repository, cache, rendered, setter: setter).apply(ids: [1, 1], screens: [mainScreen, left])
    let main = try Renderer.loadFirstFrame(await setter.calls[0].file)
    #expect(pixel(main, 0, 0).r > 235)
}

@Test func framingOfUnpluggedScreenIsIgnored() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2], mode: .perScreen)
    try await repository.update { $0.setFraming(greenBands, for: "gone") }
    let setter = RecordingSetter()
    try await service(repository, cache, rendered, setter: setter).apply(ids: [1, 2], screens: [mainScreen, rightScreen])
    let files = await setter.calls.map(\.file)
    #expect(pixel(try Renderer.loadFirstFrame(files[0]), 0, 0).r > 235)
    #expect(pixel(try Renderer.loadFirstFrame(files[1]), 64, 0).r > 235)
}

@Test func rerenderTouchesOnlyThatScreen() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2], mode: .perScreen)
    let setter = RecordingSetter()
    let wallpaper = service(repository, cache, rendered, setter: setter)
    try await wallpaper.apply(ids: [1, 2], screens: [mainScreen, rightScreen])
    try await repository.update { $0.setFraming(greenBands, for: "right") }
    try await wallpaper.rerender(screenID: "right")
    let calls = await setter.calls
    #expect(calls.map(\.screenID) == ["main", "right", "right"])
    #expect(pixel(try Renderer.loadFirstFrame(calls[2].file), 64, 0).g > 235)
    #expect(await wallpaper.current == [1, 2])
}

@Test func rerenderWithoutApplyDoesNothing() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1])
    let setter = RecordingSetter()
    try await service(repository, cache, rendered, setter: setter).rerender(screenID: "main")
    #expect(await setter.calls.isEmpty)
}

@Test func reapplySetsRequestedScreenFirst() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1, 2], mode: .perScreen)
    let setter = RecordingSetter()
    let wallpaper = service(repository, cache, rendered, setter: setter)
    try await wallpaper.apply(ids: [1, 2], screens: [mainScreen, rightScreen])
    await wallpaper.reapply(first: "right")
    #expect(await setter.calls.map(\.screenID) == ["main", "right", "right", "main"])
    await wallpaper.reapply()
    #expect(await setter.calls.map(\.screenID).suffix(2) == ["main", "right"])
}
