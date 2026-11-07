import Foundation
import Testing
@testable import ArenaKit

@Test func challengeMatchesRFC7636Vector() {
    #expect(PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
}

@Test func generatedVerifierIsBase64URLAndLongEnough() {
    let pkce = PKCE.generate()
    #expect((43...128).contains(pkce.verifier.count))
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    #expect(pkce.verifier.unicodeScalars.allSatisfy { allowed.contains($0) })
    #expect(pkce.challenge == PKCE.challenge(for: pkce.verifier))
    #expect(PKCE.generate().verifier != pkce.verifier)
}

@Test func authorizationURLCarriesAllParameters() throws {
    let pkce = PKCE.generate()
    let url = OAuthConfig(clientID: "abc").authorizationURL(pkce: pkce, state: "s1")
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(components.host == "www.are.na")
    #expect(components.path == "/oauth/authorize")
    let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    #expect(query == [
        "response_type": "code",
        "client_id": "abc",
        "redirect_uri": "arenawallpaper://oauth/callback",
        "scope": "read",
        "code_challenge": pkce.challenge,
        "code_challenge_method": "S256",
        "state": "s1",
    ])
}

@Test func callbackWithMatchingStateGivesTheCode() throws {
    let url = URL(string: "arenawallpaper://oauth/callback?code=c123&state=s1")!
    #expect(try authorizationCode(from: url, expectedState: "s1") == "c123")
}

@Test func callbackWithWrongStateIsRejected() {
    let url = URL(string: "arenawallpaper://oauth/callback?code=c123&state=other")!
    #expect(throws: OAuthError.stateMismatch) { try authorizationCode(from: url, expectedState: "s1") }
}

@Test func callbackWithErrorIsDenied() {
    let url = URL(string: "arenawallpaper://oauth/callback?error=access_denied&state=s1")!
    #expect(throws: OAuthError.denied("access_denied")) { try authorizationCode(from: url, expectedState: "s1") }
}

@Test func callbackWithoutCodeIsRejected() {
    let url = URL(string: "arenawallpaper://oauth/callback?state=s1")!
    #expect(throws: OAuthError.missingCode) { try authorizationCode(from: url, expectedState: "s1") }
}

extension Network {
    @Suite struct OAuthExchange {
        @Test func exchangePostsFormWithoutSecret() async throws {
            StubURLProtocol.reset { _ in StubURLProtocol.json(#"{"access_token":"t","token_type":"Bearer"}"#) }
            let pkce = PKCE.generate()
            let token = try await exchangeCode("c123", pkce: pkce, config: OAuthConfig(clientID: "abc"), session: StubURLProtocol.session())
            #expect(token == "t")
            let request = try #require(StubURLProtocol.requests.first)
            #expect(request.httpMethod == "POST")
            #expect(request.url == OAuthConfig.tokenURL)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
            #expect(formFields(request.httpBody) == [
                "grant_type": "authorization_code",
                "code": "c123",
                "redirect_uri": "arenawallpaper://oauth/callback",
                "client_id": "abc",
                "code_verifier": pkce.verifier,
            ])
        }

        @Test func exchangeErrorStatusIsTokenRejected() async {
            StubURLProtocol.reset { _ in StubURLProtocol.json(#"{"error":"invalid_client"}"#, status: 401) }
            await #expect(throws: OAuthError.tokenRejected(401)) {
                try await exchangeCode("c", pkce: PKCE.generate(), config: OAuthConfig(clientID: "abc"), session: StubURLProtocol.session())
            }
        }
    }
}
