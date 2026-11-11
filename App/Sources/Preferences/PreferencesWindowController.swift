import AppKit
import SwiftUI

/// Preferences window, managed like the library window: the Dock icon stays while either is open.
@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private let app: AppCoordinator
    private var window: NSWindow?

    init(app: AppCoordinator) {
        self.app = app
    }

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: PreferencesView().injecting(app)))
            w.title = String(localized: "Préférences")
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
            DockPresence.opened()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        DockPresence.closed()
        DispatchQueue.main.async { [weak self] in
            self?.window?.contentViewController = nil
            self?.window = nil
        }
    }
}
