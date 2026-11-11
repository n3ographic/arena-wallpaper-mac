import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private let app = AppCoordinator()
    private lazy var library = LibraryWindowController(app: app)
    private lazy var preferences = PreferencesWindowController(app: app)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = StatusItemController(
            panel: PanelView(openLibrary: { [weak self] in self?.showLibrary() }, openPreferences: { [weak self] in self?.showPreferences() }).injecting(app),
            paused: { [app] in app.playback.nowPlaying.paused }
        )
        app.openPreferences = { [weak self] in self?.showPreferences() }
        app.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showLibrary() {
        statusItem?.closePopover()
        library.show()
    }

    func showPreferences() {
        statusItem?.closePopover()
        preferences.show()
    }
}
