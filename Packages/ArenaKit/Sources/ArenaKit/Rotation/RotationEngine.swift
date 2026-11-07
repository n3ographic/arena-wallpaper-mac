import Foundation

/// What the menu bar panel shows: the images on screen and when the timer changes them.
public struct NowPlaying: Equatable, Sendable {
    public var ids: [Int]
    public var nextChange: Date?
    public var paused: Bool

    public init(ids: [Int], nextChange: Date?, paused: Bool) {
        self.ids = ids
        self.nextChange = nextChange
        self.paused = paused
    }
}

/// Chooses the images and applies them. Only the timer changes the image by itself; manual
/// actions work even while paused. Failing images are skipped, then images already on disk
/// are used, and an error is reported only when nothing could be applied.
public actor RotationEngine {
    private static let maxAttempts = 5

    private let repository: ConfigRepository
    private let wallpaper: WallpaperService
    private let screenProvider: ScreenProvider
    private let cache: ImageCache
    private let now: @Sendable () -> Date
    private var scheduler = Scheduler(order: .random)
    private var nextChange: Date?
    private var observers: [UUID: AsyncStream<NowPlaying>.Continuation] = [:]

    public init(
        repository: ConfigRepository, wallpaper: WallpaperService, screens: ScreenProvider, cache: ImageCache,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.wallpaper = wallpaper
        self.screenProvider = screens
        self.cache = cache
        self.now = now
    }

    public var nowPlaying: NowPlaying {
        get async { NowPlaying(ids: await wallpaper.current, nextChange: nextChange, paused: scheduler.isPaused) }
    }

    public func rotate(manual: Bool) async throws {
        let screens = await screenProvider.screens()
        guard !screens.isEmpty else { return }
        let config = await repository.config
        let pool = enabledPool(config)
        scheduler.sync(pool: pool, order: config.order)
        var firstError: Error?
        for _ in 0..<min(max(pool.count, 1), Self.maxAttempts) {
            guard let ids = pickIDs(screens: screens, config: config, poolSize: pool.count, manual: manual) else { return }
            do {
                try await apply(ids: ids, screens: screens)
                return
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        var cached: [Int] = []
        for id in pool where await cache.cachedURL(for: id) != nil {
            cached.append(id)
        }
        if let id = cached.randomElement() {
            do {
                try await apply(ids: Array(repeating: id, count: screens.count), screens: screens)
                return
            } catch {}
        }
        if let firstError { throw firstError }
    }

    /// Applies given images (a click in the grid, a re-render) and tells the observers.
    public func apply(ids: [Int], screens: [Screen]) async throws {
        try await wallpaper.apply(ids: ids, screens: screens)
        await publish()
    }

    public func setPaused(_ paused: Bool) async {
        scheduler.isPaused = paused
        await publish()
    }

    /// Starts a new wait: the next automatic change is one interval from now (1 minute minimum).
    @discardableResult
    public func scheduleNext() async -> Date {
        let minutes = max(1, await repository.config.intervalMinutes)
        let date = now().addingTimeInterval(TimeInterval(minutes * 60))
        nextChange = date
        await publish()
        return date
    }

    /// A stream of every change, starting with the current state.
    public func observe() async -> AsyncStream<NowPlaying> {
        let (stream, continuation) = AsyncStream<NowPlaying>.makeStream()
        let id = UUID()
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        continuation.yield(await nowPlaying)
        return stream
    }

    // MARK: Private

    private func pickIDs(screens: [Screen], config: Config, poolSize: Int, manual: Bool) -> [Int]? {
        let blocks = Dictionary(config.channels.flatMap(\.blocks).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let byOrientation = config.matchOrientation && config.screenMode == .perScreen
        return assign(mode: config.screenMode, screens: screens) { screen in
            let next = { manual ? self.scheduler.nextManual() : self.scheduler.next() }
            guard byOrientation else { return next() }
            return pickCompatible(next: next, ok: { orientationOK(blocks[$0], screen) }, maxDraws: poolSize)
        }
    }

    private func publish() async {
        let state = await nowPlaying
        for continuation in observers.values {
            continuation.yield(state)
        }
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }
}
