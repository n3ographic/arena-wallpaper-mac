import AppKit

/// AppKit lifecycle: a SwiftUI `Window` scene would open at launch on macOS 14,
/// and a menu bar app must start with nothing on screen.
@main
enum ArenaWallpaperApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
