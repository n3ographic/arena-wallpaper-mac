import AppKit
import SwiftUI

/// Settings window, managed by AppKit. The app gets a Dock icon only while it is open,
/// and the window (with its thumbnails) is released when it closes.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        if window == nil {
            let root = SettingsView().environmentObject(model)
            let w = NSWindow(contentViewController: NSHostingController(rootView: root))
            w.title = "Réglages"
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Thumbnails.shared.clear()
        // Drop the whole view tree so its images are freed; it is rebuilt on the next opening.
        DispatchQueue.main.async { [weak self] in
            self?.window?.contentViewController = nil
            self?.window = nil
        }
    }
}
