import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private let app = AppCoordinator()
    private lazy var library = LibraryWindowController(app: app)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = StatusItemController(
            panel: PanelView(openLibrary: { [weak self] in self?.showLibrary() }).injecting(app),
            paused: { [app] in app.playback.nowPlaying.paused }
        )
        app.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showLibrary() {
        statusItem?.closePopover()
        library.show()
    }
}
