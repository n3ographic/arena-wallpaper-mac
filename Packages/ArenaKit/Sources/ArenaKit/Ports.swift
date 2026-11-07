import Foundation

// System services the app implements; the logic in ArenaKit only sees these protocols,
// so it is tested with fakes.

/// Where the Are.na access token is kept (the Keychain in the app).
public protocol SecretStore: Sendable {
    func token() -> String?
    func setToken(_ token: String) throws
    func clearToken() throws
}

/// Opens the Are.na sign-in page and returns the redirect URL back into the app.
public protocol WebAuthenticator {
    @MainActor func authenticate(url: URL, callbackScheme: String) async throws -> URL
}

/// A rectangle in physical pixels, origin at the top-left of the primary screen.
public struct PixelRect: Equatable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// A display, identified like the system does (`NSScreenNumber`).
public struct Screen: Equatable, Sendable {
    public var id: String
    public var frame: PixelRect

    public init(id: String, frame: PixelRect) {
        self.id = id
        self.frame = frame
    }
}

public protocol ScreenProvider: Sendable {
    func screens() async -> [Screen]
}

/// Sets the desktop picture of one screen (NSWorkspace in the app, on the main thread).
public protocol WallpaperSetter: Sendable {
    func setWallpaper(_ file: URL, screenID: String) async throws
}

/// An animated GIF to play over a screen, in the rectangle the framing gives the image.
public struct LiveTarget: Equatable, Sendable {
    public var screenID: String
    public var gif: URL
    public var imageRect: PixelRect

    public init(screenID: String, gif: URL, imageRect: PixelRect) {
        self.screenID = screenID
        self.gif = gif
        self.imageRect = imageRect
    }
}

/// Windows behind the desktop icons that play GIFs. An empty list closes them all.
public protocol LiveWallpaperPlayer: Sendable {
    func show(_ targets: [LiveTarget]) async
}

/// On-device sensitive content check (Apple's framework in signed builds).
public protocol SensitivityChecker: Sendable {
    func isActive() async -> Bool
    func isSensitive(_ file: URL) async throws -> Bool
}

/// Used when the framework is unavailable: never active, never flags anything.
public struct NoSensitivityChecker: SensitivityChecker {
    public init() {}
    public func isActive() async -> Bool { false }
    public func isSensitive(_ file: URL) async throws -> Bool { false }
}
