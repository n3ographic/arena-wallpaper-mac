import ArenaKit
import AuthenticationServices
import Foundation
import Observation

/// Are.na sign-in state: OAuth, or a personal token as plan B.
@MainActor @Observable
final class AccountStore {
    private(set) var isConnected: Bool
    @ObservationIgnored private let secrets: SecretStore
    @ObservationIgnored private let auth: WebAuthenticator
    @ObservationIgnored private let errors: ErrorCenter

    init(secrets: SecretStore, auth: WebAuthenticator, errors: ErrorCenter) {
        self.secrets = secrets
        self.auth = auth
        self.errors = errors
        isConnected = secrets.token() != nil
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
            isConnected = true
            errors.clear()
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
            isConnected = true
            errors.clear()
        } catch {
            errors.report(error)
        }
    }

    func disconnect() {
        try? secrets.clearToken()
        isConnected = false
    }
}
