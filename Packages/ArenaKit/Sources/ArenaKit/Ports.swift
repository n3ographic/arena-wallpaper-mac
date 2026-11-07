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
