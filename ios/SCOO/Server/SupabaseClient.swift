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
}

/// A small REST client for Supabase: anonymous accounts (kept in the Keychain) and PostgREST calls.
actor SupabaseClient {
    static let shared = SupabaseClient()

    struct Session: Codable, Equatable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var userID: String
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

    /// Calls a Postgres function (`/rest/v1/rpc/<name>`).
    func rpc<T: Decodable>(_ name: String, _ params: [String: Any], as type: T.Type) async throws -> T {
        let data = try await call("rest/v1/rpc/\(name)", method: "POST", body: params)
        return try Self.decoder.decode(T.self, from: data)
    }

    /// Reads rows (`/rest/v1/<pathAndQuery>`).
    func select<T: Decodable>(_ pathAndQuery: String, as type: T.Type) async throws -> T {
        let data = try await call("rest/v1/\(pathAndQuery)", method: "GET", body: nil)
        return try Self.decoder.decode(T.self, from: data)
    }

    /// Calls an Edge Function (`/functions/v1/<name>`) as the signed-in user.
    func invoke(_ name: String, _ body: [String: Any]) async throws -> Data {
        try await call("functions/v1/\(name)", method: "POST", body: body)
    }

    // MARK: Plumbing

    private func authenticate(path: String, body: [String: Any]) async throws -> Session {
        guard let key = SupabaseConfig.anonKey else { throw ServerError.notConfigured }
        var request = URLRequest(url: URL(string: "auth/v1/\(path)", relativeTo: SupabaseConfig.url)!)
        request.httpMethod = "POST"
        // Publishable keys (sb_publishable_...) go in the apikey header only; they are not JWTs.
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await urlSession.data(for: request)
        try Self.check(response, data)
        struct Answer: Decodable {
            struct User: Decodable { let id: String }
            let access_token: String
            let refresh_token: String
            let expires_in: Double
            let user: User
        }
        let answer = try JSONDecoder().decode(Answer.self, from: data)
        let fresh = Session(accessToken: answer.access_token, refreshToken: answer.refresh_token,
                            expiresAt: Date().addingTimeInterval(answer.expires_in), userID: answer.user.id)
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
