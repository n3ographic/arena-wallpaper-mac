import AppKit
import SwiftUI

/// Menu bar icon. Left and right clicks open the same popover (a `MenuBarExtra` ignores the
/// right click, see the prototype report).
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()

    init<Content: View>(panel: Content) {
        super.init()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: panel)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "Arena Wallpaper")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(toggle(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

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
