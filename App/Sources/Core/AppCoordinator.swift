import AppKit
import ArenaKit
import Observation
import SwiftUI

/// Builds the stores, wires system notifications, and carries the few actions that touch
/// several stores. No other logic lives here.
@MainActor @Observable
final class AppCoordinator {
    let errors: ErrorCenter
    let account: AccountStore
    let library: LibraryStore
    let playback: PlaybackStore
    let display: DisplayStore

    /// Opens the preferences window (set by the app delegate).
    @ObservationIgnored var openPreferences: () -> Void = {}

    init() {
        // Inside the sandbox these are the app's own container folders.
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let secrets = KeychainSecretStore()
        let repository = ConfigRepository(store: ConfigStore(directory: support))
        let cache = ImageCache(directory: caches.appendingPathComponent("originals"))
        // One gate for every client: they are recreated at each call to read the current token.
        let gate = RequestGate()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let userAgent = arenaUserAgent(version: version, contact: AppInfo.contactEmail)
        let service = LibraryService(repository: repository) {
            ArenaClient(token: secrets.token(), userAgent: userAgent, gate: gate)
        }
        let wallpaper = WallpaperService(
            repository: repository, cache: cache, renderedDirectory: support.appendingPathComponent("rendered"),
            setter: WorkspaceWallpaper(), player: DesktopGIFPlayer(),
            reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        )
        let screens = SystemScreens()
        let engine = RotationEngine(repository: repository, wallpaper: wallpaper, screens: screens, cache: cache)

        let errors = ErrorCenter()
        let account = AccountStore(secrets: secrets, auth: WebAuth(), errors: errors)
        let library = LibraryStore(repository: repository, library: service, cache: cache, errors: errors, account: account)
        let clock = RotationClock(
            engine: engine,
            onError: { errors.report($0) },
            onRotated: { await library.refresh(force: false) }
        )
        self.errors = errors
        self.account = account
        self.library = library
        playback = PlaybackStore(engine: engine, clock: clock, repository: repository, errors: errors, library: library)
        display = DisplayStore(repository: repository, wallpaper: wallpaper, engine: engine, screens: screens, errors: errors, library: library)
    }

    /// Called once at launch: state, system observers, first image, timer.
    func start() {
        Task {
            await library.reloadConfig()
            await display.reloadScreens()
        }
        playback.start()
        // Screens added, removed or rearranged: render again for the new sizes.
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.display.reloadScreens(); await self?.display.rerender() }
        }
        // "Reduce motion" turned on or off: start or stop the animations now.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.display.refreshAnimations() }
        }
        // macOS only updates the active Space: set the same files again on the new one.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.display.reapply(first: NSScreen.main?.screenID) }
        }
    }

    /// Pose an image on the target, then a new full wait.
    func apply(_ block: Block, to target: PoseTarget? = nil) async {
        await display.apply(block, to: target)
        playback.restartClock()
    }

    /// Removes (or brings back) images; the screens showing a removed one move on.
    func toggleExcluded(_ ids: [Int]) async {
        await library.toggleExcluded(ids)
        let nowExcluded = Set(ids).intersection(library.config.excluded)
        let screenIDs = screensToAdvance(afterExcluding: nowExcluded, current: playback.nowPlaying.ids, screens: display.screens)
        if !screenIDs.isEmpty { await playback.advance(screenIDs: screenIDs) }
    }
}

extension View {
    /// Gives a view tree the stores it reads.
    func injecting(_ app: AppCoordinator) -> some View {
        environment(app).environment(app.errors).environment(app.account).environment(app.library)
            .environment(app.playback).environment(app.display)
    }
}
