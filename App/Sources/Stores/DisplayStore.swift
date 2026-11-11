import ArenaKit
import Observation

/// Screens, where a picked image goes, their framing, and the wallpaper itself.
@MainActor @Observable
final class DisplayStore {
    private(set) var screens: [Screen] = []
    /// Where a picked image is posed; always one that makes sense now (see `validTarget`).
    private(set) var target: PoseTarget = .all

    @ObservationIgnored private let repository: ConfigRepository
    @ObservationIgnored private let wallpaper: WallpaperService
    @ObservationIgnored private let engine: RotationEngine
    @ObservationIgnored private let provider: ScreenProvider
    @ObservationIgnored private let errors: ErrorCenter
    @ObservationIgnored private let library: LibraryStore

    init(repository: ConfigRepository, wallpaper: WallpaperService, engine: RotationEngine, screens: ScreenProvider, errors: ErrorCenter, library: LibraryStore) {
        self.repository = repository
        self.wallpaper = wallpaper
        self.engine = engine
        self.provider = screens
        self.errors = errors
        self.library = library
    }

    func reloadScreens() async {
        screens = await provider.screens()
        await revalidateTarget()
    }

    func setTarget(_ newTarget: PoseTarget) async {
        target = validTarget(newTarget, mode: await repository.config.screenMode, screens: screens)
    }

    /// This image on the target (or on `override`): every screen, or one screen with the others kept.
    func apply(_ block: Block, to override: PoseTarget? = nil) async {
        let screens = await provider.screens()
        let current = await engine.nowPlaying.ids
        await apply(ids: idsToApply(block.id, target: override ?? target, current: current, screens: screens), screens: screens)
    }

    /// `nil` screen is "Tous": the default framing for every screen.
    func setFraming(_ framing: Framing, for screenID: String?) async {
        do {
            try await repository.update { $0.setFraming(framing, for: screenID) }
            await library.reloadConfig()
            if let screenID {
                try await wallpaper.rerender(screenID: screenID)
            } else {
                await rerender()
            }
        } catch {
            errors.report(error)
        }
    }

    func setScreenMode(_ mode: ScreenMode) async {
        await update { $0.screenMode = mode }
        await revalidateTarget()
    }

    func setMatchOrientation(_ match: Bool) async {
        await update { $0.matchOrientation = match }
    }

    /// Draws the images on screen again with the current settings (or screens).
    func rerender() async {
        let screens = await provider.screens()
        guard let ids = currentFor(await engine.nowPlaying.ids, screenCount: screens.count) else { return }
        await apply(ids: ids, screens: screens)
    }

    func refreshAnimations() async {
        await wallpaper.refreshAnimations()
    }

    /// After a Space change: the same files, set again.
    func reapply() async {
        await wallpaper.reapply()
    }

    private func apply(ids: [Int], screens: [Screen]) async {
        do {
            try await engine.apply(ids: ids, screens: screens)
            errors.clear()
        } catch {
            errors.report(error)
        }
    }

    private func update(_ change: @escaping (inout Config) -> Void) async {
        do {
            try await repository.update(change)
            await library.reloadConfig()
            await rerender()
        } catch {
            errors.report(error)
        }
    }

    private func revalidateTarget() async {
        target = validTarget(target, mode: await repository.config.screenMode, screens: screens)
    }
}
