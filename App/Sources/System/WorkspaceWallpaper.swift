import AppKit
import ArenaKit

enum WallpaperError: Error, LocalizedError {
    case screenGone

    var errorDescription: String? { "Écran débranché" }
}

/// Sets the desktop picture of one screen. The value read back right after is the previous
/// one (prototype report), so only the absence of an error counts.
struct WorkspaceWallpaper: WallpaperSetter {
    func setWallpaper(_ file: URL, screenID: String) async throws {
        try await MainActor.run {
            guard let screen = NSScreen.screens.first(where: { $0.screenID == screenID }) else { throw WallpaperError.screenGone }
            try NSWorkspace.shared.setDesktopImageURL(file, for: screen, options: [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue])
        }
    }
}
