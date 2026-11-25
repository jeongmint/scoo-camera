import Foundation
import Security

/// Where the SCOO server lives. The publishable (anon) key is meant to ship inside apps; row level security
/// on the server decides what each signed-in account may do. Never put a secret / service_role key here.
enum SupabaseConfig {
    static let url = URL(string: "https://ofwexbasbwumfvswkixb.supabase.co")!
    /// The publishable key, set through the SUPABASE_ANON_KEY build setting (Info.plist key SupabaseAnonKey).
    static var anonKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !key.isEmpty, !key.hasPrefix("$(") else { return nil }
        return key
    }
    static var isConfigured: Bool { anonKey != nil }
    /// Kakao through the `kakao-login` function (email only, needs OpenID Connect at Kakao) instead of Supabase's
    /// own Kakao login (which also asks for nickname and photo, so those consent items must be set). Off: the
    /// Kakao app has all three consent items.
    static let kakaoEmailOnly = false
    /// Sign in with Apple needs a paid Apple Developer team (see `generate_xcodeproj.py --paid-team`).
    static var appleSignInAvailable: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "SCOOPaidTeam") as? String) == "YES"
    }
}

/// A small REST client for Supabase: anonymous accounts (kept in the Keychain) and PostgREST calls.
actor SupabaseClient {
    static let shared = SupabaseClient()

    struct Session: Codable, Equatable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var userID: String
        /// Added later; older stored sessions decode with nil (they were anonymous).
        var isAnonymous: Bool? = nil
        var email: String? = nil
        /// The login attached to the account ("apple", "google", "kakao"); nil while anonymous or for older sessions.
        var provider: String? = nil
    }

    /// What a login (Apple, Google, Kakao) did to the account on this device.
    enum LinkResult: Equatable {
        /// The anonymous account now has the login attached: same friends, bottles and letters, kept for good.
        case linked
        /// That login already had an account (e.g. after reinstalling): this device now uses it.
        case switched
    }

    enum ServerError: LocalizedError, Equatable {
        case notConfigured
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "서버 키가 아직 설정되지 않았어요."
            case .http(_, let body) where body.contains("daily limit reached"):
                return "유리병은 하루에 한 번 띄울 수 있어요."
            case .http(_, let body) where body.contains("no such code"):
                return "그 코드를 가진 친구를 찾지 못했어요."
            case .http(_, let body) where body.contains("your own code"):
                return "내 친구 코드예요. 친구의 코드를 넣어 주세요."
            case .http(_, let body) where body.contains("not friends"):
                return "친구가 된 뒤에 편지를 보낼 수 있어요."
            case .http(_, let body) where body.contains("suspended until"):
                // 신고 처리로 보내기가 잠시 멈춘 계정 (the server says until which day).
                let day = body.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression).map { String(body[$0]) }
                return "운영 규칙을 어긴 편지가 있어서 \(day.map { "\($0)까지 " } ?? "잠시 ")편지와 친구 요청을 보낼 수 없어요."
            case .http(_, let body) where body.contains("operators only"):
                return "운영자만 할 수 있어요."
            case .http(_, let body) where body.contains("slow down"):
                return "편지를 너무 빨리 보내고 있어요. 잠시 뒤에 보내 주세요."
            case .http(_, let body) where body.lowercased().contains("provider is not enabled") || body.contains("provider_disabled"):
                return "서버에서 이 로그인 방식이 아직 꺼져 있어요. Supabase의 Sign In / Providers에서 켜 주세요."
            case .http(_, let body) where body.lowercased().contains("manual linking"):
                return "서버에서 계정 연결(manual linking)이 꺼져 있어요."
            case .http(_, let body) where body.contains("kakao_oidc_off"):
                return "카카오 앱에서 OpenID Connect를 켜 주세요. (카카오 로그인 → 고급)"
            case .http(_, let body) where body.lowercased().contains("user email"):
                return "로그인한 계정에서 이메일을 받지 못했어요. 이메일 제공에 동의해 주세요."
            case .http(_, let body) where body.contains("photo limit reached"):
                return "사진은 하루 50장까지 보낼 수 있어요."
            case .http(_, let body) where body.contains("photo not found"):
                return "사진을 올리지 못했어요. 다시 보내 주세요."
            case .http(_, let body) where body.contains("\"22023\""):
                // The server refused a name (닉네임 거르기): its message is already written for people.
                let json = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any]
                return json?["message"] as? String ?? "쓸 수 없는 이름이에요. 다른 이름으로 지어 주세요."
            case .http(429, _):
                return "오늘은 새 그림을 충분히 그렸어요. 내일 또 그려 줄게요."
            case .http(_, let body) where body.lowercased().contains("anonymous sign-ins are disabled"):
                return "서버에서 익명 로그인이 꺼져 있어요. Supabase 설정에서 켜 주세요."
            case .http(let code, _):
                return "서버와 통신하지 못했어요. (\(code))"
            }
        }
    }

    private let keychain = KeychainItem(account: "supabase-session")
    private var session: Session?
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        session = keychain.read().flatMap { try? JSONDecoder().decode(Session.self, from: $0) }
    }

    var currentUserID: String? { session?.userID }
    /// True while the account exists only on this device (no Apple ID attached).
    var isAnonymous: Bool { session?.isAnonymous ?? true }
    var email: String? { session?.email }
    var provider: String? { session?.provider }

    /// Login errors that mean "this Apple/Google/Kakao account already belongs to another SCOO account".
    static func isAlreadyTaken(_ text: String) -> Bool {
        text.contains("identity_already_exists") || text.lowercased().contains("already linked")
    }

    /// Sign in with Apple: attaches Apple to the current anonymous account, or, if that Apple ID already
    /// belongs to an account, switches this device to it. `nonce` is the raw nonce whose SHA-256 went to Apple.
    func signInWithApple(idToken: String, nonce: String) async throws -> LinkResult {
        try await signIn(provider: "apple", idToken: idToken, nonce: nonce)
    }

    /// An OpenID id_token from Apple or Kakao: linked to the anonymous account, or signed in to the account
    /// that login already has.
    private func signIn(provider: String, idToken: String, nonce: String) async throws -> LinkResult {
        let current = try await signIn()
        let body: [String: Any] = ["provider": provider, "id_token": idToken, "nonce": nonce]
        if current.isAnonymous ?? true {
            var linking = body
            linking["link_identity"] = true
            do {
                _ = try await authenticate(path: "token?grant_type=id_token", body: linking, bearer: current.accessToken)
                return .linked
            } catch ServerError.http(_, let text) where Self.isAlreadyTaken(text) {
                // This login already has an account (e.g. made before reinstalling): fall through and sign in to it.
                // Any other failure (linking switched off, bad token) is thrown, so the anonymous account is never left behind by accident.
            }
        }
        _ = try await authenticate(path: "token?grant_type=id_token", body: body)
        return .switched
    }

    /// Kakao goes through the `kakao-login` function, which asks Kakao only for the email (OpenID Connect).
    /// Supabase's own Kakao login always asks for nickname and photo too, which Kakao refuses (KOE205)
    /// unless those consent items are set up.
    private func signInWithKakao(browser: @Sendable (URL) async throws -> URL) async throws -> LinkResult {
        let nonce = AppleNonce.make(), state = AppleNonce.make()
        var components = URLComponents(url: SupabaseConfig.url.appendingPathComponent("functions/v1/kakao-login"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "nonce", value: AppleNonce.sha256(nonce)), URLQueryItem(name: "state", value: state)]
        let callback = try await browser(components.url!)
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        if let error = value("error") {
            if error == "access_denied" { throw WebLogin.Cancelled() }
            throw ServerError.http(400, "\(error) \(value("error_description") ?? "")")
        }
        guard value("state") == state, let idToken = value("id_token") else {
            throw ServerError.http(0, "kakao login callback without a token")
        }
        return try await signIn(provider: "kakao", idToken: idToken, nonce: nonce)
    }

    /// Google or Kakao through the Supabase web login (PKCE). Like Apple: attaches the login to the anonymous
    /// account, or signs in to the account that login already has. `browser` shows a URL and returns the
    /// `scoo://auth-callback` it ends on (see `WebLogin.open`).
    func signIn(with provider: OAuthProvider, browser: @Sendable (URL) async throws -> URL) async throws -> LinkResult {
        if provider == .kakao && SupabaseConfig.kakaoEmailOnly { return try await signInWithKakao(browser: browser) }
        let current = try await signIn()
        if current.isAnonymous ?? true {
            let pkce = PKCE()
            let start = try await authorizeURL("user/identities/authorize", provider: provider, pkce: pkce, bearer: current.accessToken)
            do {
                try await exchange(try await browser(start), pkce: pkce)
                return .linked
            } catch ServerError.http(_, let text) where Self.isAlreadyTaken(text) {
                // Same as Apple: that login already has an account, so sign in to it below.
            }
        }
        let pkce = PKCE()
        let start = try await authorizeURL("authorize", provider: provider, pkce: pkce, bearer: nil)
        try await exchange(try await browser(start), pkce: pkce)
        return .switched
    }

    /// Asks Supabase for the provider's login page before opening it, so a provider that is switched off
    /// (or linking that is off) shows up as an error here rather than as a dead web page.
    /// Linking answers `{url}`; plain sign-in answers with a redirect, which is read but not followed.
    private func authorizeURL(_ path: String, provider: OAuthProvider, pkce: PKCE, bearer: String?) async throws -> URL {
        guard let key = SupabaseConfig.anonKey else { throw ServerError.notConfigured }
        var components = URLComponents(url: SupabaseConfig.url.appendingPathComponent("auth/v1/\(path)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "provider", value: provider.rawValue),
            URLQueryItem(name: "redirect_to", value: OAuthCallback.redirect),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256"),
            URLQueryItem(name: "skip_http_redirect", value: "true"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(key, forHTTPHeaderField: "apikey")
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await urlSession.data(for: request, delegate: NoRedirects())
        if let http = response as? HTTPURLResponse, (300..<400).contains(http.statusCode),
           let location = http.value(forHTTPHeaderField: "Location"), let url = URL(string: location) {
            return url
        }
        try Self.check(response, data)
        struct Answer: Decodable { let url: URL }
        return try JSONDecoder().decode(Answer.self, from: data).url
    }

    /// Turns the `scoo://auth-callback?code=…` into a session.
    private func exchange(_ callback: URL, pkce: PKCE) async throws {
        switch OAuthCallback(callback) {
        case .code(let code):
            _ = try await authenticate(path: "token?grant_type=pkce", body: ["auth_code": code, "code_verifier": pkce.verifier])
        case .failure(let code, let description):
            throw ServerError.http(400, "\(code) \(description)")
        case nil:
            throw ServerError.http(0, "login callback without a code")
        }
    }

    /// The signed-in session, creating an anonymous account on first use and refreshing an expiring token.
    @discardableResult
    func signIn() async throws -> Session {
        if let session, session.expiresAt.timeIntervalSinceNow > 60 { return session }
        if let session, let refreshed = try? await authenticate(path: "token?grant_type=refresh_token",
                                                                 body: ["refresh_token": session.refreshToken]) {
            return refreshed
        }
        return try await authenticate(path: "signup", body: ["data": [String: String]()])
    }

    func signOut() {
        session = nil
        keychain.delete()
    }

    /// Deletes this account and everything of it on the server (bottles already given to someone stay theirs),
    /// then forgets the session on this phone. Photos in the app album are not touched.
    func deleteAccount() async throws {
        guard session != nil else { return }
        _ = try await call("rest/v1/rpc/delete_my_account", method: "POST", body: [:])
        signOut()
    }

    /// Calls a Postgres function (`/rest/v1/rpc/<name>`).
    func rpc<T: Decodable>(_ name: String, _ params: [String: Any], as type: T.Type) async throws -> T {
        let data = try await call("rest/v1/rpc/\(name)", method: "POST", body: params)
        return try Self.decoder.decode(T.self, from: data)
    }

    /// Calls a Postgres function that returns nothing.
    func call(rpc name: String, _ params: [String: Any]) async throws {
        _ = try await call("rest/v1/rpc/\(name)", method: "POST", body: params)
    }

    /// Reads rows (`/rest/v1/<pathAndQuery>`).
    func select<T: Decodable>(_ pathAndQuery: String, as type: T.Type) async throws -> T {
        let data = try await call("rest/v1/\(pathAndQuery)", method: "GET", body: nil)
        return try Self.decoder.decode(T.self, from: data)
    }

    /// Updates rows (`PATCH /rest/v1/<pathAndQuery>`); row level security decides which rows.
    func update(_ pathAndQuery: String, _ body: [String: Any]) async throws {
        _ = try await call("rest/v1/\(pathAndQuery)", method: "PATCH", body: body)
    }

    /// Uploads a file to Storage (`/storage/v1/object/<bucket>/<path>`) as the signed-in user; policies decide where.
    func upload(bucket: String, path: String, data: Data, contentType: String) async throws {
        guard let key = SupabaseConfig.anonKey else { throw ServerError.notConfigured }
        let session = try await signIn()
        var request = URLRequest(url: URL(string: "storage/v1/object/\(bucket)/\(path)", relativeTo: SupabaseConfig.url)!)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        let (answer, response) = try await urlSession.data(for: request)
        try Self.check(response, answer)
    }

    /// Reads a private Storage file the signed-in user may see.
    func download(bucket: String, path: String) async throws -> Data {
        guard let key = SupabaseConfig.anonKey else { throw ServerError.notConfigured }
        let session = try await signIn()
        var request = URLRequest(url: URL(string: "storage/v1/object/authenticated/\(bucket)/\(path)", relativeTo: SupabaseConfig.url)!)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await urlSession.data(for: request)
        try Self.check(response, data)
        return data
    }

    /// Calls an Edge Function (`/functions/v1/<name>`) as the signed-in user.
    func invoke(_ name: String, _ body: [String: Any]) async throws -> Data {
        try await call("functions/v1/\(name)", method: "POST", body: body)
    }

    // MARK: Plumbing

    private func authenticate(path: String, body: [String: Any], bearer: String? = nil) async throws -> Session {
        guard let key = SupabaseConfig.anonKey else { throw ServerError.notConfigured }
        var request = URLRequest(url: URL(string: "auth/v1/\(path)", relativeTo: SupabaseConfig.url)!)
        request.httpMethod = "POST"
        // Publishable keys (sb_publishable_...) go in the apikey header only; they are not JWTs.
        request.setValue(key, forHTTPHeaderField: "apikey")
        // Linking an identity acts on the signed-in user.
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await urlSession.data(for: request)
        try Self.check(response, data)
        struct Answer: Decodable {
            struct User: Decodable {
                let id: String
                let is_anonymous: Bool?
                let email: String?
                struct Identity: Decodable { let provider: String }
                let identities: [Identity]?
            }
            let access_token: String
            let refresh_token: String
            let expires_in: Double
            let user: User
        }
        let answer = try JSONDecoder().decode(Answer.self, from: data)
        let fresh = Session(accessToken: answer.access_token, refreshToken: answer.refresh_token,
                            expiresAt: Date().addingTimeInterval(answer.expires_in), userID: answer.user.id,
                            isAnonymous: answer.user.is_anonymous ?? false, email: answer.user.email,
                            provider: answer.user.identities?.first { $0.provider != "anonymous" }?.provider)
        session = fresh
        if let stored = try? JSONEncoder().encode(fresh) { keychain.write(stored) }
        return fresh
    }

    private func call(_ path: String, method: String, body: [String: Any]?) async throws -> Data {
        guard let key = SupabaseConfig.anonKey else { throw ServerError.notConfigured }
        let session = try await signIn()
        var request = URLRequest(url: URL(string: path, relativeTo: SupabaseConfig.url)!)
        request.httpMethod = method
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await urlSession.data(for: request)
        try Self.check(response, data)
        return data
    }

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ServerError.http(0, "") }
        guard (200..<300).contains(http.statusCode) else {
            throw ServerError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }

    /// Postgres timestamps come with 0–6 fractional digits and an offset.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = parseTimestamp(text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "날짜 형식: \(text)"))
        }
        return decoder
    }()

    static func parseTimestamp(_ text: String) -> Date? {
        // Postgres sends 0–6 fractional digits (e.g. ".08426"); normalise them to milliseconds first.
        var value = text
        if let dot = value.firstIndex(of: ".") {
            let start = value.index(after: dot)
            let end = value[start...].firstIndex(where: { !$0.isNumber }) ?? value.endIndex
            let millis = String((String(value[start..<end]) + "000").prefix(3))
            value = String(value[..<start]) + millis + String(value[end...])
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

/// Stops URLSession from following a redirect, so its Location can be read.
private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? { nil }
}

/// One generic-password Keychain item, readable after the first unlock.
struct KeychainItem {
    let account: String
    private let service = "com.jeongmint.scoo"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    func read() -> Data? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        return SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
    }

    func write(_ data: Data) {
        let update: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, update as CFDictionary) == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
