import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private let model = AppModel()
    private lazy var settings = SettingsWindowController(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = StatusItemController(
            panel: PanelView(model: model, openSettings: { [weak self] in self?.showSettings() }),
            paused: model.$nowPlaying.map(\.paused).eraseToAnyPublisher()
        )
        model.start()
        // Screens added, removed or rearranged: render again for the new sizes.
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.model.rerender() }
        }
        // "Reduce motion" turned on or off: start or stop the animations now.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.model.refreshAnimations() }
        }
        // macOS only updates the active Space: set the same files again on the new one.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.model.reapply() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showSettings() {
        statusItem?.closePopover()
        settings.show()
    }
}
