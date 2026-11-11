import ArenaKit
import AuthenticationServices
import Foundation
import Observation

/// Are.na sign-in state: OAuth, or a personal token as plan B.
@MainActor @Observable
final class AccountStore {
    private(set) var isConnected: Bool
    /// The Are.na profile, loaded when the account page opens.
    private(set) var profile: ArenaProfile?
    private(set) var isLoadingProfile = false
    /// How and when the user signed in (nil for a sign-in made before this was recorded).
    private(set) var method: ConnectionMethod?
    private(set) var connectedSince: Date?

    enum ConnectionMethod: String {
        case oauth, personalToken
    }
    @ObservationIgnored private let secrets: SecretStore
    @ObservationIgnored private let auth: WebAuthenticator
    @ObservationIgnored private let errors: ErrorCenter
    @ObservationIgnored private let makeClient: @Sendable () -> ArenaClient
    @ObservationIgnored private let defaults = UserDefaults.standard

    init(secrets: SecretStore, auth: WebAuthenticator, errors: ErrorCenter, makeClient: @escaping @Sendable () -> ArenaClient) {
        self.secrets = secrets
        self.auth = auth
        self.errors = errors
        self.makeClient = makeClient
        isConnected = secrets.token() != nil
        method = defaults.string(forKey: Keys.method).flatMap(ConnectionMethod.init)
        connectedSince = defaults.object(forKey: Keys.since) as? Date
    }

    private enum Keys {
        static let method = "accountMethod"
        static let since = "accountConnectedSince"
    }

    /// Loads the profile once per sign-in; a refused token signs out.
    func loadProfile() async {
        guard isConnected, profile == nil, !isLoadingProfile else { return }
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        do {
            profile = try await makeClient().me()
        } catch ArenaError.unauthorized {
            disconnect()
            errors.report(String(localized: "Reconnecte-toi à Are.na."))
        } catch {
            errors.report(error)
        }
    }

    private func signedIn(_ method: ConnectionMethod) {
        isConnected = true
        profile = nil
        self.method = method
        connectedSince = Date()
        defaults.set(method.rawValue, forKey: Keys.method)
        defaults.set(connectedSince, forKey: Keys.since)
        errors.clear()
    }

    func connect() async {
        guard !AppOAuth.clientID.isEmpty else {
            errors.report(String(localized: "La connexion Are.na n'est pas encore configurée : utilise un token personnel."))
            return
        }
        let oauth = OAuthConfig(clientID: AppOAuth.clientID)
        let pkce = PKCE.generate()
        let state = PKCE.generate().verifier
        do {
            let callback = try await auth.authenticate(url: oauth.authorizationURL(pkce: pkce, state: state), callbackScheme: OAuthConfig.callbackScheme)
            let code = try authorizationCode(from: callback, expectedState: state)
            try secrets.setToken(try await exchangeCode(code, pkce: pkce, config: oauth))
            signedIn(.oauth)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch {
            errors.report(error)
        }
    }

    /// Plan B when the OAuth exchange is refused: a personal token pasted by the user.
    func connect(personalToken: String) async {
        let token = personalToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        do {
            try secrets.setToken(token)
            signedIn(.personalToken)
        } catch {
            errors.report(error)
        }
    }

    func disconnect() {
        try? secrets.clearToken()
        isConnected = false
        profile = nil
        method = nil
        connectedSince = nil
        defaults.removeObject(forKey: Keys.method)
        defaults.removeObject(forKey: Keys.since)
    }
}
