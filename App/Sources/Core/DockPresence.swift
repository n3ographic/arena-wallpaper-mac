import AppKit

/// The Dock icon shows while at least one window of the app is open.
@MainActor
enum DockPresence {
    private static var openWindows = 0

    static func opened() {
        openWindows += 1
        NSApp.setActivationPolicy(.regular)
    }

    static func closed() {
        openWindows = max(0, openWindows - 1)
        if openWindows == 0 { NSApp.setActivationPolicy(.accessory) }
    }
}
