import CoreGraphics
import Foundation
import ImageIO

public enum ApplyError: Error, Equatable {
    case allScreensFailed(String)
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
        setter: WallpaperSetter, player: LiveWallpaperPlayer,
        now: @escaping @Sendable () -> Date = { Date() },
        reduceMotion: @escaping @Sendable () -> Bool = { false }
    ) {
        self.repository = repository
        self.cache = cache
        self.renderedDirectory = renderedDirectory
        self.setter = setter
        self.player = player
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
            mode: config.screenMode, reduceMotion: reduceMotion(), framing: { config.framing(for: $0) }
        )
    }

    /// Sets the current files again: after a Space change, the system may still show an older
    /// picture on the newly active Space.
    /// `first` is the screen the user is looking at: it is set before the others.
    public func reapply(first screenID: String? = nil) async {
        let files = currentFiles.filter { $0.screenID == screenID } + currentFiles.filter { $0.screenID != screenID }
        for (screenID, file) in files {
            try? await setter.setWallpaper(file, screenID: screenID)
        }
    }

    /// Draws and sets one screen again with the image it shows, after its framing changed.
    /// The other screens, `current` and their files stay as they are.
    public func rerender(screenID: String) async throws {
        guard let applied = lastApplied, let index = applied.screens.firstIndex(where: { $0.id == screenID }) else { return }
        let config = await repository.config
        if config.screenMode == .span {
            try await apply(ids: applied.ids, screens: applied.screens)
            return
        }
        generation += 1
        let mine = generation
        let screen = applied.screens[index]
        let files = try await render(ids: [applied.ids[index]], screens: [screen], originals: applied.originals, config: config)
        guard mine == generation else { return }
        try await setter.setWallpaper(files[0], screenID: screenID)
        if let at = currentFiles.firstIndex(where: { $0.screenID == screenID }) {
            currentFiles[at] = (screenID, files[0])
        }
        removeStaleFiles(keeping: currentFiles.map(\.file), keep: 3 * applied.screens.count)
        await player.show(animatedTargets(ids: applied.ids, screens: applied.screens, originals: applied.originals, config: config))
    }

    // MARK: Rendering

    private func render(ids: [Int], screens: [Screen], originals: [Int: URL], config: Config) async throws -> [URL] {
        try FileManager.default.createDirectory(at: renderedDirectory, withIntermediateDirectories: true)
        let stamp = Int(now().timeIntervalSince1970 * 1000)
        // Decoded once per image, at the largest size a screen needs.
        var images: [Int: CGImage] = [:]
        func image(_ id: Int, canvas: CGSize, framing: Framing) async throws -> CGImage {
            do {
                let url = originals[id]!
                let needed = FrameGeometry.decodeMaxPixelSize(imageSize: try Renderer.orientedSize(url), canvasSize: canvas, framing: framing)
                if let cached = images[id], max(cached.width, cached.height) >= needed { return cached }
                let loaded = try Renderer.loadFirstFrame(url, maxPixelSize: needed)
                images[id] = loaded
                return loaded
            } catch {
                // A broken cached original is fetched again next time.
                await cache.discard(id)
                throw error
            }
        }
        func compose(_ id: Int, _ size: CGSize, _ framing: Framing) async throws -> CGImage {
            Renderer.render(try await image(id, canvas: size, framing: framing), canvasSize: size, framing: framing)
        }

        var big: (canvas: PixelRect, image: CGImage)?
        if config.screenMode == .span {
            let canvas = spanCanvas(screens)
            // One image over every screen: only the default framing applies.
            big = (canvas, try await compose(ids[0], CGSize(width: canvas.width, height: canvas.height), config.defaultFraming))
        }
        var files: [URL] = []
        for (index, (screen, id)) in zip(screens, ids).enumerated() {
            let output: CGImage
            if let big {
                let crop = cropInCanvas(big.canvas, screen)
                output = big.image.cropping(to: CGRect(x: crop.x, y: crop.y, width: crop.width, height: crop.height)) ?? big.image
            } else {
                output = try await compose(id, CGSize(width: screen.frame.width, height: screen.frame.height), config.framing(for: screen.id))
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
