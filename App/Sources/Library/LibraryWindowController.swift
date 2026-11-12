import AppKit
import SwiftUI

/// Library window, managed by AppKit. The app gets a Dock icon only while it is open,
/// and the window (with its thumbnails) is released when it closes.
@MainActor
final class LibraryWindowController: NSObject, NSWindowDelegate {
    private let app: AppCoordinator
    private var window: NSWindow?

    init(app: AppCoordinator) {
        self.app = app
    }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: LibraryView().injecting(app))
            // The view's toolbar items (the inspector button) go into the window's toolbar.
            host.sceneBridgingOptions = [.toolbars]
            let w = NSWindow(contentViewController: host)
            w.title = String(localized: "Bibliothèque")
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.setContentSize(NSSize(width: 960, height: 640))
            w.minSize = NSSize(width: 760, height: 480)
            w.center()
            window = w
            DockPresence.opened()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// ⌘A when no text field takes it: the window delegate is the end of the window's
    /// responder chain, so the menu item reaches it and selects every image of the grid.
    @objc func selectAll(_ sender: Any?) {
        app.selectAllRequests += 1
    }

    /// ⌘Z undoes the removals of images made in this window.
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        app.undoManager
    }

    func windowWillClose(_ notification: Notification) {
        DockPresence.closed()
        Thumbnails.shared.clear()
        // Drop the whole view tree so its images are freed; it is rebuilt on the next opening.
        DispatchQueue.main.async { [weak self] in
            self?.window?.contentViewController = nil
            self?.window = nil
        }
    }
}
