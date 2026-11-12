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

    /// What the library window shows; kept here so the menu bar can open it on a given page.
    var sidebarItem: SidebarItem = .images(.all)
    /// An image to select and inspect when the library window shows (from the menu bar).
    var reveal: Int?
    /// Bumped by ⌘A in the library window (see `LibraryWindowController.selectAll`).
    var selectAllRequests = 0

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
        let makeClient: @Sendable () -> ArenaClient = { ArenaClient(token: secrets.token(), userAgent: userAgent, gate: gate) }
        let service = LibraryService(repository: repository, client: makeClient)
        let wallpaper = WallpaperService(
            repository: repository, cache: cache, renderedDirectory: support.appendingPathComponent("rendered"),
            setter: WorkspaceWallpaper(), player: DesktopGIFPlayer(),
            reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        )
        let screens = SystemScreens()
        let engine = RotationEngine(repository: repository, wallpaper: wallpaper, screens: screens, cache: cache)

        let errors = ErrorCenter()
        let account = AccountStore(secrets: secrets, auth: WebAuth(), errors: errors, makeClient: makeClient)
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
            Task { await self?.display.reapply() }
        }
    }

    /// Pose an image on the target, then a new full wait.
    func apply(_ block: Block, to target: PoseTarget? = nil) async {
        await display.apply(block, to: target)
        playback.restartClock()
    }

    /// Removes (or brings back) images; the screens showing a removed one move on. Undoable
    /// (⌘Z in the library window, or the notice's "Annuler"), and the undo can be redone.
    func toggleExcluded(_ ids: [Int]) async {
        guard !ids.isEmpty else { return }
        registerUndo(ids)
        await performToggle(ids)
        let removed = ids.contains(where: library.isExcluded)
        removalNotice = RemovalNotice(count: ids.count, removed: removed)
    }

    /// Registered synchronously inside the undo handler, so UndoManager files it as the redo.
    /// An undo or redo shows no notice: offering to cancel it again would be confusing.
    private func registerUndo(_ ids: [Int]) {
        undoManager.registerUndo(withTarget: self) { app in
            app.removalNotice = nil
            app.registerUndo(ids)
            Task { await app.performToggle(ids) }
        }
    }

    private func performToggle(_ ids: [Int]) async {
        await library.toggleExcluded(ids)
        let nowExcluded = Set(ids).intersection(library.config.excluded)
        let screenIDs = screensToAdvance(afterExcluding: nowExcluded, current: playback.nowPlaying.ids, screens: display.screens)
        if !screenIDs.isEmpty { await playback.advance(screenIDs: screenIDs) }
    }

    /// The library window's undo stack (given to its window by `LibraryWindowController`).
    @ObservationIgnored let undoManager = UndoManager()
    /// The last removal or return of images, shown a few seconds with "Annuler".
    var removalNotice: RemovalNotice?
}

struct RemovalNotice: Equatable {
    let id = UUID()
    let count: Int
    /// Taken out of the playback (true) or put back (false).
    let removed: Bool
}

extension View {
    /// Gives a view tree the stores it reads.
    func injecting(_ app: AppCoordinator) -> some View {
        environment(app).environment(app.errors).environment(app.account).environment(app.library)
            .environment(app.playback).environment(app.display)
    }
}
