import Foundation
import CryptoKit
import Security
import AuthenticationServices
import UIKit

/// The web login providers Supabase handles for SCOO (Apple uses the native sheet instead).
enum OAuthProvider: String, CaseIterable, Identifiable {
    case google, kakao
    var id: String { rawValue }
    var title: String {
        switch self {
        case .google: return "Google"
        case .kakao: return "카카오"
        }
    }
}

/// PKCE (RFC 7636): the app keeps a random verifier and only sends its SHA-256 challenge, so a code caught
/// on its way back to `scoo://` is useless to anyone else.
struct PKCE {
    let verifier: String

    init(verifier: String = PKCE.randomVerifier()) { self.verifier = verifier }

    var challenge: String { Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }

    static func randomVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 48)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = (0..<bytes.count).map { _ in UInt8.random(in: 0...255) }
        }
        return base64URL(Data(bytes))   // 64 characters, all unreserved
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// What came back to `scoo://auth-callback`: a code to exchange, or the server's reason for refusing.
enum OAuthCallback: Equatable {
    case code(String)
    case failure(code: String, description: String)

    static let redirect = "scoo://auth-callback"
    static let scheme = "scoo"

    /// Supabase puts the answer in the query, or for errors sometimes in the fragment.
    init?(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var items = components.queryItems ?? []
        if let fragment = components.fragment, let parsed = URLComponents(string: "?" + fragment)?.queryItems {
            items += parsed
        }
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value.map { $0.replacingOccurrences(of: "+", with: " ") }
        }
        if let error = value("error_code") ?? value("error") {
            self = .failure(code: error, description: value("error_description") ?? "")
        } else if let code = value("code"), !code.isEmpty {
            self = .code(code)
        } else {
            return nil
        }
    }
}

/// Shows a provider's login page in the in-app Safari sheet and hands back the `scoo://` callback.
@MainActor
final class WebLogin: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    /// Thrown when the person closes the sheet; callers stay quiet about it.
    struct Cancelled: Error {}

    static func open(_ url: URL) async throws -> URL {
        let login = WebLogin()
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: OAuthCallback.scheme) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: Cancelled())
                } else {
                    continuation.resume(throwing: error ?? Cancelled())
                }
                login.session = nil
            }
            // Keep the browser's cookies, so the second pass after "this account already exists" is one tap.
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = login
            login.session = session
            if !session.start() {
                login.session = nil
                continuation.resume(throwing: Cancelled())
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
