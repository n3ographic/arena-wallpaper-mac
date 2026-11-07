import CoreGraphics
import Foundation
import ImageIO

public enum ApplyError: Error, Equatable {
    case allScreensFailed(String)
    case sensitive(Int)
    case unknownImage(Int)
}

/// Downloads, renders and sets one image per screen. A screen that fails does not stop the
/// others; the call fails only when no screen could be updated.
public actor WallpaperService {
    private let repository: ConfigRepository
    private let cache: ImageCache
    private let renderedDirectory: URL
    private let setter: WallpaperSetter
    private let player: LiveWallpaperPlayer
    private let checker: SensitivityChecker
    private let now: @Sendable () -> Date
    private let reduceMotion: @Sendable () -> Bool

    /// Image ids on screen, one per screen.
    public private(set) var current: [Int] = []
    /// The files last set, per screen id, to set them again without rendering.
    private var currentFiles: [(screenID: String, file: URL)] = []
    /// What was last applied, to recompute the animations without rendering again.
    private var lastApplied: (ids: [Int], screens: [Screen], originals: [Int: URL])?
    /// Increases with every application: an older one that finishes late must not win.
    private var generation = 0

    public init(
        repository: ConfigRepository, cache: ImageCache, renderedDirectory: URL,
        setter: WallpaperSetter, player: LiveWallpaperPlayer, checker: SensitivityChecker,
        now: @escaping @Sendable () -> Date = { Date() },
        reduceMotion: @escaping @Sendable () -> Bool = { false }
    ) {
        self.repository = repository
        self.cache = cache
        self.renderedDirectory = renderedDirectory
        self.setter = setter
        self.player = player
        self.checker = checker
        self.now = now
        self.reduceMotion = reduceMotion
    }

    public func apply(ids: [Int], screens: [Screen]) async throws {
        guard !screens.isEmpty, ids.count == screens.count else { return }
        generation += 1
        let mine = generation
        let config = await repository.config
        var originals: [Int: URL] = [:]
        for id in Set(ids) {
            guard let block = config.channels.lazy.flatMap(\.blocks).first(where: { $0.id == id }) else {
                throw ApplyError.unknownImage(id)
            }
            originals[id] = try await cache.original(for: block)
        }
        try await checkSensitive(originals: originals, config: config)
        let files = try await render(ids: ids, screens: screens, originals: originals, config: config)
        guard mine == generation else { return }

        var errors: [String] = []
        for (screen, file) in zip(screens, files) {
            guard mine == generation else { return }
            do {
                try await setter.setWallpaper(file, screenID: screen.id)
            } catch {
                errors.append(error.localizedDescription)
            }
        }
        removeStaleFiles(keeping: files, keep: 3 * screens.count)
        if errors.count == screens.count {
            throw ApplyError.allScreensFailed(errors.first ?? "")
        }
        guard mine == generation else { return }
        current = ids
        currentFiles = zip(screens, files).map { ($0.id, $1) }
        lastApplied = (ids, screens, originals)
        await player.show(animatedTargets(ids: ids, screens: screens, originals: originals, config: config))
    }

    /// Recomputes the animations of what is on screen (for example after "Reduce motion" changed).
    public func refreshAnimations() async {
        guard let lastApplied else { return }
        let config = await repository.config
        await player.show(animatedTargets(ids: lastApplied.ids, screens: lastApplied.screens, originals: lastApplied.originals, config: config))
    }

    /// GIFs play in windows over the still first frame that was just set.
    private func animatedTargets(ids: [Int], screens: [Screen], originals: [Int: URL], config: Config) -> [LiveTarget] {
        let blocks = Dictionary(config.channels.flatMap(\.blocks).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var frameCounts: [Int: Int] = [:]
        var sizes: [Int: CGSize] = [:]
        for (id, url) in originals where blocks[id]?.isGIF == true {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int else { continue }
            frameCounts[id] = CGImageSourceGetCount(source)
            sizes[id] = CGSize(width: width, height: height)
        }
        return liveTargets(
            ids: ids, screens: screens, blocks: blocks, originals: originals, frameCounts: frameCounts, imageSizes: sizes,
            mode: config.screenMode, reduceMotion: reduceMotion(), fit: config.fit, positionX: config.positionX, positionY: config.positionY
        )
    }

    /// Each image is checked once, on the device, before it is first set; the verdict stays
    /// in the local config. Images the user chose to keep are not checked again.
    private func checkSensitive(originals: [Int: URL], config: Config) async throws {
        guard config.hideSensitive, await checker.isActive() else { return }
        let allowed = Set(config.sensitiveAllowed)
        for (id, url) in originals.sorted(by: { $0.key < $1.key }) where !allowed.contains(id) {
            let flagged: Bool
            if let verdict = config.sensitiveVerdicts[id] {
                flagged = verdict
            } else {
                flagged = try await checker.isSensitive(url)
                try await repository.update { $0.sensitiveVerdicts[id] = flagged }
            }
            if flagged { throw ApplyError.sensitive(id) }
        }
    }

    /// Sets the current files again: after a Space change, the system may still show an older
    /// picture on the newly active Space.
    public func reapply() async {
        for (screenID, file) in currentFiles {
            try? await setter.setWallpaper(file, screenID: screenID)
        }
    }

    // MARK: Rendering

    private func render(ids: [Int], screens: [Screen], originals: [Int: URL], config: Config) async throws -> [URL] {
        try FileManager.default.createDirectory(at: renderedDirectory, withIntermediateDirectories: true)
        let stamp = Int(now().timeIntervalSince1970 * 1000)
        var images: [Int: CGImage] = [:]
        func image(_ id: Int) async throws -> CGImage {
            if let cached = images[id] { return cached }
            do {
                let loaded = try Renderer.loadFirstFrame(originals[id]!)
                images[id] = loaded
                return loaded
            } catch {
                // A broken cached original is fetched again next time.
                await cache.discard(id)
                throw error
            }
        }
        func compose(_ id: Int, _ size: CGSize) async throws -> CGImage {
            Renderer.render(try await image(id), canvasSize: size, fit: config.fit, positionX: config.positionX, positionY: config.positionY, background: config.background)
        }

        var big: (canvas: PixelRect, image: CGImage)?
        if config.screenMode == .span {
            let canvas = spanCanvas(screens)
            big = (canvas, try await compose(ids[0], CGSize(width: canvas.width, height: canvas.height)))
        }
        var files: [URL] = []
        for (index, (screen, id)) in zip(screens, ids).enumerated() {
            let output: CGImage
            if let big {
                let crop = cropInCanvas(big.canvas, screen)
                output = big.image.cropping(to: CGRect(x: crop.x, y: crop.y, width: crop.width, height: crop.height)) ?? big.image
            } else {
                output = try await compose(id, CGSize(width: screen.frame.width, height: screen.frame.height))
            }
            // A unique name, so the system does not keep showing a cached older picture.
            let file = renderedDirectory.appendingPathComponent("\(index)-\(id)-\(stamp).png")
            try Renderer.writePNG(output, to: file)
            files.append(file)
        }
        return files
    }

    private func removeStaleFiles(keeping inUse: [URL], keep: Int) {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: renderedDirectory.path) else { return }
        let files = names.compactMap { name -> (url: URL, modified: Date)? in
            let url = renderedDirectory.appendingPathComponent(name)
            guard let date = (try? fm.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date else { return nil }
            return (url, date)
        }
        for url in staleRenderedFiles(files, inUse: inUse, keep: keep) {
            try? fm.removeItem(at: url)
        }
    }
}
