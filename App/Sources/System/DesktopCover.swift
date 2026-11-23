import AppKit
import ImageIO

/// The still picture in a window just above the desktop picture, under the icons, on every Space.
/// Without it, each Space keeps its own desktop picture and shows an older image for a moment
/// after a Space change, until the app sets the current one again. The desktop picture itself is
/// still set (locked screen, Mission Control, app quit).
@MainActor
final class DesktopCover {
    static let shared = DesktopCover()

    private var windows: [String: (window: NSWindow, file: FileIdentity)] = [:]

    func show(_ file: URL, on screen: NSScreen, screenID: String) {
        closeUnpluggedScreens()
        let identity = FileIdentity(file)
        if let current = windows[screenID], current.file == identity, current.window.frame == screen.frame { return }
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return }
        let window = windows[screenID]?.window ?? Self.makeWindow()
        window.setFrame(screen.frame, display: false)
        window.contentView?.layer?.contents = image
        window.orderFrontRegardless()
        windows[screenID] = (window, identity)
    }

    private func closeUnpluggedScreens() {
        let present = Set(NSScreen.screens.map(\.screenID))
        for (id, entry) in windows where !present.contains(id) {
            entry.window.close()
            windows[id] = nil
        }
    }

    private static func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.level = .desktopCover
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let view = NSView()
        view.wantsLayer = true
        view.layer?.contentsGravity = .resize
        window.contentView = view
        return window
    }
}

extension NSWindow.Level {
    /// Just above the desktop picture: the still picture, then the GIFs over it.
    static let desktopCover = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
    static let desktopGIF = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 2)
}

/// Same file on disk: a hard link (`N-a-s.tiff`) is the file it points to, so setting it again
/// after a Space change decodes nothing. A rewritten file is a new one (new inode or date).
private struct FileIdentity: Equatable {
    let inode: Int?
    let modified: Date?

    init(_ url: URL) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        inode = attributes?[.systemFileNumber] as? Int
        modified = attributes?[.modificationDate] as? Date
    }
}
