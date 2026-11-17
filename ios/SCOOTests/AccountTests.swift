import XCTest
@testable import SCOO

final class AccountTests: XCTestCase {
    func testNonceIsRandomAndHashedLikeApple() {
        let a = AppleNonce.make(), b = AppleNonce.make()
        XCTAssertEqual(a.count, 32)
        XCTAssertNotEqual(a, b)
        // SHA-256 of "abc" (FIPS 180-2 test vector), as lowercase hex
        XCTAssertEqual(AppleNonce.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testSessionsSavedBeforeAppleLoginStillLoad() throws {
        let old = #"{"accessToken":"a","refreshToken":"r","expiresAt":0,"userID":"u"}"#
        let session = try JSONDecoder().decode(SupabaseClient.Session.self, from: Data(old.utf8))
        XCTAssertNil(session.isAnonymous, "예전 세션은 익명으로 취급해요")
        XCTAssertNil(session.email)
    }

    func testPKCEChallengeMatchesRFC7636() {
        // base64url(SHA-256(verifier)) without padding, checked with Python hashlib
        let pkce = PKCE(verifier: "dBjftJeZ4CVP-mJ92K9qNKbN4D4EnBKyXVJ1Za7Mjd8")
        XCTAssertEqual(pkce.challenge, "Ow-hlgGprli0GCqLCNxug4JF7KCrhYmF766142cafxE")
        let random = PKCE()
        XCTAssertGreaterThanOrEqual(random.verifier.count, 43)
        XCTAssertNil(random.verifier.rangeOfCharacter(from: CharacterSet(charactersIn: "+/=")))
        XCTAssertNotEqual(random.verifier, PKCE().verifier)
    }

    func testLoginCallbackCarriesCodeOrReason() {
        XCTAssertEqual(OAuthCallback(URL(string: "scoo://auth-callback?code=abc-123")!), .code("abc-123"))
        let taken = OAuthCallback(URL(string: "scoo://auth-callback#error=server_error&error_code=identity_already_exists&error_description=Identity+is+already+linked+to+another+user")!)
        XCTAssertEqual(taken, .failure(code: "identity_already_exists", description: "Identity is already linked to another user"))
        if case .failure(let code, let description) = taken {
            XCTAssertTrue(SupabaseClient.isAlreadyTaken("\(code) \(description)"))
        }
        XCTAssertNil(OAuthCallback(URL(string: "scoo://auth-callback")!))
    }

    func testLoggedInSessionRemembersProvider() throws {
        let saved = #"{"accessToken":"a","refreshToken":"r","expiresAt":0,"userID":"u","isAnonymous":false,"provider":"kakao"}"#
        let session = try JSONDecoder().decode(SupabaseClient.Session.self, from: Data(saved.utf8))
        XCTAssertEqual(session.provider, "kakao")
    }
}
