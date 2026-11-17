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
}
