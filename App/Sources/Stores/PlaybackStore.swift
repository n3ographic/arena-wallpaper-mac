import ArenaKit
import Observation
import os

/// What is playing and when it changes: next, pause, rhythm, order, and the clock.
@MainActor @Observable
final class PlaybackStore {
    private(set) var nowPlaying = NowPlaying(ids: [], nextChange: nil, paused: false)

    @ObservationIgnored private static let log = Logger(subsystem: "com.n3ographic.arenawallpaper.mac", category: "perf")
    @ObservationIgnored private let engine: RotationEngine
    @ObservationIgnored private let clock: RotationClock
    @ObservationIgnored private let repository: ConfigRepository
    @ObservationIgnored private let errors: ErrorCenter
    @ObservationIgnored private let library: LibraryStore

    init(engine: RotationEngine, clock: RotationClock, repository: ConfigRepository, errors: ErrorCenter, library: LibraryStore) {
        self.engine = engine
        self.clock = clock
        self.repository = repository
        self.errors = errors
        self.library = library
    }

    /// Called once at launch: observer, low pool handler, first image, timer, library refresh.
    func start() {
        Task {
            for await state in await engine.observe() {
                Self.log.info("nowPlaying received by the UI")
                nowPlaying = state
            }
        }
        Task { [weak self] in
            guard let self else { return }
            // Public channels are readable without an account, so this does not wait for a sign-in.
            await engine.setOnLowPool { [weak self] in await self?.library.growLibrary() }
            clock.start(rotateNow: true)
            await library.refresh(force: false)
        }
    }

    func next() async {
        let start = ContinuousClock.now
        await run { try await engine.rotate(manual: true) }
        Self.log.info("next (key to rotate done): \(start.duration(to: .now).description, privacy: .public)")
    }

    /// Back to what was on screen before the last change.
    func previous() async {
        await run { try await engine.goBack() }
    }

    /// One screen only (the thumbnails of the menu bar panel).
    func next(screenID: String) async {
        await run { try await engine.advance(screenIDs: [screenID]) }
    }

    /// Advances the given screens (after their image was removed from the rotation).
    func advance(screenIDs: [String]) async {
        await run { try await engine.advance(screenIDs: screenIDs) }
    }

    func togglePause() async {
        await engine.setPaused(!nowPlaying.paused)
    }

    func setInterval(_ minutes: Int) async {
        let before = library.config.intervalMinutes
        await update { $0.intervalMinutes = max(1, minutes) }
        if library.config.intervalMinutes != before { clock.restart() }
    }

    func setOrder(_ order: RotationOrder) async {
        await update { $0.order = order }
    }

    /// A new full wait, without changing the image now.
    func restartClock() {
        clock.restart()
    }

    private func update(_ change: @escaping (inout Config) -> Void) async {
        do {
            try await repository.update(change)
            await library.reloadConfig()
        } catch {
            errors.report(error)
        }
    }

    private func run(_ action: () async throws -> Void) async {
        do {
            try await action()
            errors.clear()
        } catch {
            errors.report(error)
        }
        clock.restart()
    }
}
