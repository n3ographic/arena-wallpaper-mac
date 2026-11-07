import CryptoKit
import Foundation
import Security

/// Proof Key for Code Exchange (RFC 7636), S256 method.
public struct PKCE: Sendable, Equatable {
    public let verifier: String
    public let challenge: String

    public init(verifier: String) {
        self.verifier = verifier
        self.challenge = Self.challenge(for: verifier)
    }

    /// 32 random bytes in base64url: a 43 character verifier.
    public static func generate() -> PKCE {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "no system randomness")
        return PKCE(verifier: base64URL(Data(bytes)))
    }

    public static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }
}

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

public enum OAuthError: Error, Equatable {
    case stateMismatch
    case missingCode
    case denied(String)
    case tokenRejected(Int)
}

/// Are.na OAuth application. Only the public client id: the app never holds the secret.
public struct OAuthConfig: Sendable {
    public static let redirectURI = "arenawallpaper://oauth/callback"
    public static let callbackScheme = "arenawallpaper"
    public static let authorizeURL = URL(string: "https://www.are.na/oauth/authorize")!
    public static let tokenURL = URL(string: "https://api.are.na/v3/oauth/token")!

    public let clientID: String

    public init(clientID: String) {
        self.clientID = clientID
    }

    /// Read-only access: a wallpaper never writes to Are.na.
    public func authorizationURL(pkce: PKCE, state: String) -> URL {
        var components = URLComponents(url: Self.authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "scope", value: "read"),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }
}

/// The code of the redirect back into the app, after checking that it answers our request.
public func authorizationCode(from callback: URL, expectedState: String) throws -> String {
    let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let value = { (name: String) in items.first { $0.name == name }?.value }
    guard value("state") == expectedState else { throw OAuthError.stateMismatch }
    if let error = value("error") { throw OAuthError.denied(error) }
    guard let code = value("code"), !code.isEmpty else { throw OAuthError.missingCode }
    return code
}

/// Trades the code for an access token with PKCE only (no client secret).
public func exchangeCode(_ code: String, pkce: PKCE, config: OAuthConfig, session: URLSession = .shared) async throws -> String {
    var request = URLRequest(url: OAuthConfig.tokenURL)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data(formEncode([
        ("grant_type", "authorization_code"),
        ("code", code),
        ("redirect_uri", OAuthConfig.redirectURI),
        ("client_id", config.clientID),
        ("code_verifier", pkce.verifier),
    ]).utf8)
    let (data, response) = try await session.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    struct TokenResponse: Decodable { let access_token: String }
    guard (200..<300).contains(status), let token = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
        throw OAuthError.tokenRejected(status)
    }
    return token.access_token
}

func formEncode(_ fields: [(String, String)]) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return fields
        .map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.1)" }
        .joined(separator: "&")
}
