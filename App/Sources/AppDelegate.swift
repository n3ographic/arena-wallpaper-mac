import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private let app = AppCoordinator()
    private lazy var settings = SettingsWindowController(app: app)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = StatusItemController(
            panel: PanelView(openSettings: { [weak self] in self?.showSettings() }).injecting(app),
            paused: { [app] in app.playback.nowPlaying.paused }
        )
        app.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showSettings() {
        statusItem?.closePopover()
        settings.show()
    }
}
