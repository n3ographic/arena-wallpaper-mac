import AppKit
import Observation
import SwiftUI

/// Menu bar icon. Left and right clicks open the same popover (a `MenuBarExtra` ignores the
/// right click, see the prototype report). The icon fades while the rotation is paused.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()

    init<Content: View>(panel: Content, paused: @escaping @MainActor () -> Bool) {
        super.init()
        popover.behavior = .transient
        let host = NSHostingController(rootView: panel)
        // The popover follows the panel's own height, so the image is never squeezed.
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        if let button = item.button {
            button.image = Self.icon
            button.target = self
            button.action = #selector(toggle(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        trackPaused(paused)
    }

    /// Re-reads `paused` each time an observable it touches changes.
    private func trackPaused(_ paused: @escaping @MainActor () -> Bool) {
        let isPaused = withObservationTracking({ paused() }, onChange: { [weak self] in
            Task { @MainActor in self?.trackPaused(paused) }
        })
        item.button?.alphaValue = isPaused ? 0.4 : 1
    }

    /// The app's mark (frame and asterisk) as a template image: macOS tints it for light and dark bars.
    private static let icon: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            // Drawn in a 24 unit box, like an SF Symbol.
            let scale = NSAffineTransform()
            scale.scale(by: 18.0 / 24.0)
            scale.concat()
            NSColor.black.set()
            let frame = NSBezierPath(roundedRect: NSRect(x: 3, y: 5, width: 18, height: 14), xRadius: 2, yRadius: 2)
            frame.lineWidth = 2
            frame.stroke()
            let star = NSBezierPath()
            star.lineWidth = 2
            star.lineCapStyle = .round
            for degrees in [90.0, 30.0, -30.0] {
                let a = degrees * .pi / 180, arm = 3.5
                star.move(to: NSPoint(x: 12 - arm * cos(a), y: 12 - arm * sin(a)))
                star.line(to: NSPoint(x: 12 + arm * cos(a), y: 12 + arm * sin(a)))
            }
            star.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Wallpaper for Are.na"
        return image
    }()

    @objc private func toggle(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }
}
