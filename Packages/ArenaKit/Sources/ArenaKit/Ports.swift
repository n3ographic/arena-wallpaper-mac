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
