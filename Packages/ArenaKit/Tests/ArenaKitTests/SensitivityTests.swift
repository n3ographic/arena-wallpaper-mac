import Foundation
import Testing
@testable import ArenaKit

/// Flags the files whose name (the image id) is in `flagged`.
private actor FakeChecker: SensitivityChecker {
    let active: Bool
    let flagged: Set<String>
    private(set) var calls = 0

    init(active: Bool = true, flagged: Set<String> = []) {
        self.active = active
        self.flagged = flagged
    }

    func isActive() async -> Bool { active }

    func isSensitive(_ file: URL) async throws -> Bool {
        calls += 1
        return flagged.contains(file.lastPathComponent)
    }
}

private let screen = testScreen("main", 0, 0, 192, 108)

private func service(_ repository: ConfigRepository, _ cache: ImageCache, _ rendered: URL, _ setter: RecordingSetter, _ checker: FakeChecker) -> WallpaperService {
    WallpaperService(repository: repository, cache: cache, renderedDirectory: rendered, setter: setter, player: RecordingPlayer(), checker: checker)
}

@Test func flaggedImageIsNeverApplied() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [5])
    let setter = RecordingSetter()
    await #expect(throws: ApplyError.sensitive(5)) {
        try await service(repository, cache, rendered, setter, FakeChecker(flagged: ["5"])).apply(ids: [5], screens: [screen])
    }
    #expect(await setter.calls.isEmpty)
    #expect(await repository.config.sensitiveVerdicts[5] == true)
}

@Test func inactiveCheckerAppliesEverything() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [5])
    let setter = RecordingSetter()
    try await service(repository, cache, rendered, setter, FakeChecker(active: false, flagged: ["5"])).apply(ids: [5], screens: [screen])
    #expect(await setter.calls.count == 1)
    #expect(await repository.config.sensitiveVerdicts.isEmpty)
}

@Test func hideSensitiveOffSkipsTheCheck() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [5])
    try await repository.update { $0.hideSensitive = false }
    let checker = FakeChecker(flagged: ["5"])
    try await service(repository, cache, rendered, RecordingSetter(), checker).apply(ids: [5], screens: [screen])
    #expect(await checker.calls == 0)
}

@Test func verdictIsCachedPerImage() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [1])
    let checker = FakeChecker()
    let wallpaper = service(repository, cache, rendered, RecordingSetter(), checker)
    try await wallpaper.apply(ids: [1], screens: [screen])
    try await wallpaper.apply(ids: [1], screens: [screen])
    #expect(await checker.calls == 1)
    #expect(await repository.config.sensitiveVerdicts[1] == false)
}

@Test func allowedImageIsReused() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [5])
    try await repository.update {
        $0.sensitiveVerdicts = [5: true]
        $0.sensitiveAllowed = [5]
    }
    #expect(enabledPool(await repository.config) == [5])
    let setter = RecordingSetter()
    try await service(repository, cache, rendered, setter, FakeChecker(flagged: ["5"])).apply(ids: [5], screens: [screen])
    #expect(await setter.calls.count == 1)
}

@Test func rotationSkipsFlaggedImage() async throws {
    let (repository, cache, rendered) = try await fixture(ids: [5, 6])
    try await repository.update { $0.order = .ordered }
    let wallpaper = service(repository, cache, rendered, RecordingSetter(), FakeChecker(flagged: ["5"]))
    struct OneScreen: ScreenProvider { func screens() async -> [Screen] { [screen] } }
    let rotation = RotationEngine(repository: repository, wallpaper: wallpaper, screens: OneScreen(), cache: cache)
    try await rotation.rotate(manual: false)
    #expect(await rotation.nowPlaying.ids == [6])
}
