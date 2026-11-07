import AppKit
import ArenaKit

/// Plays animated GIFs in borderless windows just above the desktop picture, under the icons,
/// on every Space, ignoring clicks. A window pauses while it is fully hidden.
final class DesktopGIFPlayer: LiveWallpaperPlayer, @unchecked Sendable {
    @MainActor private var windows: [String: GIFWindow] = [:]
    @MainActor private var shown: [LiveTarget] = []

    func show(_ targets: [LiveTarget]) async {
        await MainActor.run { update(targets) }
    }

    @MainActor private func update(_ targets: [LiveTarget]) {
        guard targets != shown else { return }
        shown = targets
        for window in windows.values { window.close() }
        windows = [:]
        for target in targets {
            guard let screen = NSScreen.screens.first(where: { $0.screenID == target.screenID }),
                  let image = NSImage(contentsOf: target.gif) else { continue }
            let scale = screen.backingScaleFactor
            let window = Self.frame(of: target.imageRect, on: screen)
            // The whole GIF inside the window (AppKit view coordinates: origin at the bottom-left).
            let c = target.contentRect
            let content = NSRect(
                x: CGFloat(c.x) / scale,
                y: window.height - CGFloat(c.y + c.height) / scale,
                width: CGFloat(c.width) / scale, height: CGFloat(c.height) / scale
            )
            windows[target.screenID] = GIFWindow(image: image, frame: window, content: content)
        }
    }

    /// Screen pixels (top-left origin, local to the screen) to global AppKit points.
    @MainActor private static func frame(of rect: PixelRect, on screen: NSScreen) -> NSRect {
        let scale = screen.backingScaleFactor
        let width = CGFloat(rect.width) / scale, height = CGFloat(rect.height) / scale
        let x = screen.frame.minX + CGFloat(rect.x) / scale
        let y = screen.frame.maxY - CGFloat(rect.y) / scale - height
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

@MainActor
private final class GIFWindow {
    private let window: NSWindow
    private let imageView: NSImageView
    private var debouncer = VisibilityDebouncer(delay: 0.3)
    private var observer: NSObjectProtocol?

    init(image: NSImage, frame: NSRect, content: NSRect) {
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        imageView = NSImageView(frame: content)
        imageView.image = image
        imageView.imageScaling = .scaleAxesIndependently
        imageView.animates = true
        // The container clips the parts of a cropped (fill) GIF that fall outside the window.
        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.wantsLayer = true
        container.layer?.masksToBounds = true
        container.addSubview(imageView)
        window.contentView = container
        window.orderFrontRegardless()
        observer = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.occlusionChanged() }
        }
    }

    func close() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        imageView.animates = false
        window.close()
    }

    /// Pause when fully hidden (full-screen app, other Space, locked screen), after the state held 300 ms.
    private func occlusionChanged() {
        debouncer.observe(window.occlusionState.contains(.visible), at: Date())
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.31) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let visible = self.debouncer.settled(at: Date()) else { return }
                if self.imageView.animates != visible { self.imageView.animates = visible }
            }
        }
    }
}
