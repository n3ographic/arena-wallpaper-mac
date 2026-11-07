import Foundation
@testable import ArenaKit

actor RecordingSetter: WallpaperSetter {
    private(set) var calls: [(file: URL, screenID: String)] = []
    var failing: Set<String> = []

    init(failing: Set<String> = []) {
        self.failing = failing
    }

    func setWallpaper(_ file: URL, screenID: String) async throws {
        calls.append((file, screenID))
        if failing.contains(screenID) { throw CocoaError(.fileWriteNoPermission) }
    }
}

actor RecordingPlayer: LiveWallpaperPlayer {
    private(set) var shown: [[LiveTarget]] = []

    func show(_ targets: [LiveTarget]) async {
        shown.append(targets)
    }
}

func testScreen(_ id: String, _ x: Int, _ y: Int, _ w: Int, _ h: Int) -> Screen {
    Screen(id: id, frame: PixelRect(x: x, y: y, width: w, height: h))
}

/// Increments by one second at each call, for deterministic file names.
final class TestClock: @unchecked Sendable {
    private var seconds = 1_000_000.0
    func now() -> Date {
        seconds += 1
        return Date(timeIntervalSince1970: seconds)
    }
}

/// A repository with one channel of the given ids, and their originals already in the cache.
func fixture(ids: [Int], mode: ScreenMode = .same, gifIDs: Set<Int> = []) async throws -> (ConfigRepository, ImageCache, URL) {
    let root = makeTempDirectory()
    let originals = root.appendingPathComponent("originals")
    try FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
    var blocks: [Block] = []
    for id in ids {
        var block = testBlock(id)
        if gifIDs.contains(id) {
            block.contentType = "image/gif"
            try encoded([solidImage(width: 64, height: 48, rgb: (1, 0, 0)), solidImage(width: 64, height: 48, rgb: (0, 0, 1))], type: .gif)
                .write(to: originals.appendingPathComponent(String(id)))
        } else {
            try pngData(width: 64, height: 48).write(to: originals.appendingPathComponent(String(id)))
        }
        blocks.append(block)
    }
    let repository = ConfigRepository(store: ConfigStore(directory: root))
    try await repository.update {
        $0.channels = [Channel(slug: "c", blocks: blocks)]
        $0.screenMode = mode
    }
    return (repository, ImageCache(directory: originals), root.appendingPathComponent("rendered"))
}
