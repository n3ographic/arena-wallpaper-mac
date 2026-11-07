import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private let model = AppModel()
    private lazy var settings = SettingsWindowController(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = StatusItemController(panel: PanelView(openSettings: { [weak self] in self?.showSettings() }))
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showSettings() {
        statusItem?.closePopover()
        settings.show()
    }
}
