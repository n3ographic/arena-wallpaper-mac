import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private let app = AppCoordinator()
    private lazy var library = LibraryWindowController(app: app)
    private let about = AboutWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = StatusItemController(
            panel: PanelView(openLibrary: { [weak self] in self?.showLibrary() }, openPreferences: { [weak self] in self?.showPreferences() }, openAbout: { [weak self] in self?.showAbout() }).injecting(app),
            paused: { [app] in app.playback.nowPlaying.paused }
        )
        installMainMenu()
        app.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showLibrary() {
        if case .images = app.sidebarItem {} else { app.sidebarItem = .images(.all) }
        statusItem?.closePopover()
        library.show()
    }

    /// The preferences are pages of the library window.
    func showPreferences() {
        app.sidebarItem = .playback
        statusItem?.closePopover()
        library.show()
    }

    func showAbout() {
        statusItem?.closePopover()
        about.show()
    }

    /// Shortcuts need a menu: a menu bar app has none by default. It shows only while a window is open.
    private func installMainMenu() {
        let main = NSMenu()
        func submenu(_ title: String, _ items: [NSMenuItem]) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            item.submenu = menu
            main.addItem(item)
        }
        let preferences = NSMenuItem(title: String(localized: "Préférences"), action: #selector(openPreferencesFromMenu), keyEquivalent: ",")
        preferences.target = self
        let aboutItem = NSMenuItem(title: String(localized: "À propos d'Arena Wallpaper"), action: #selector(openAboutFromMenu), keyEquivalent: "")
        aboutItem.target = self
        let reportItem = NSMenuItem(title: String(localized: "Signaler un problème…"), action: #selector(reportProblem), keyEquivalent: "")
        reportItem.target = self
        submenu("Arena Wallpaper", [
            aboutItem, reportItem, .separator(),
            preferences, .separator(),
            NSMenuItem(title: String(localized: "Quitter"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"),
        ])
        submenu(String(localized: "Édition"), [
            NSMenuItem(title: String(localized: "Couper"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"),
            NSMenuItem(title: String(localized: "Copier"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
            NSMenuItem(title: String(localized: "Coller"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
            NSMenuItem(title: String(localized: "Tout sélectionner"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"),
        ])
        submenu(String(localized: "Fenêtre"), [
            NSMenuItem(title: String(localized: "Fermer"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"),
        ])
        NSApp.mainMenu = main
    }

    @objc private func reportProblem() {
        NSWorkspace.shared.open(UpdateChecker.repository.appendingPathComponent("issues/new"))
    }

    @objc private func openAboutFromMenu() {
        showAbout()
    }

    @objc private func openPreferencesFromMenu() {
        showPreferences()
    }
}
