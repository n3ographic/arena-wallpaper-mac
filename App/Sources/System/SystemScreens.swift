import AppKit
import ArenaKit

extension NSScreen {
    /// The id the wallpaper API and the screen list share (`NSScreenNumber`).
    var screenID: String? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue
    }
}

/// Screens in physical pixels, origin at the top-left of the primary screen.
struct SystemScreens: ScreenProvider {
    func screens() async -> [Screen] {
        await MainActor.run {
            let screens = NSScreen.screens
            // AppKit's origin is the bottom-left of the primary screen (the first one): flip it.
            let mainHeight = screens.first?.frame.height ?? 0
            return screens.compactMap { screen in
                guard let id = screen.screenID else { return nil }
                let frame = screen.frame
                let scale = screen.backingScaleFactor
                let top = mainHeight - (frame.origin.y + frame.height)
                return Screen(id: id, frame: PixelRect(
                    x: Int((frame.origin.x * scale).rounded()),
                    y: Int((top * scale).rounded()),
                    width: max(1, Int((frame.width * scale).rounded())),
                    height: max(1, Int((frame.height * scale).rounded()))
                ))
            }
        }
    }
}
