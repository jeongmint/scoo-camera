import Foundation
import Combine

/// My profile as friends see it.
struct MyProfile: Decodable, Equatable {
    let friend_code: String?
    let nickname: String?
    let hero: String?
}

/// A friend or a pending request, with what the inbox shows (from `list_friends()`).
struct FriendRow: Decodable, Identifiable, Equatable {
    let friend_id: UUID
    let nickname: String?
    let friend_code: String?
    let hero: String?
    /// "friend", "sent" (I asked) or "received" (they asked)
    let status: String
    let last_body: String?
    let last_sticker: String?
    let last_at: Date?
    let unread: Int

    var id: UUID { friend_id }
    var name: String { nickname ?? "친구 \(friend_code ?? "")" }
    var heroSpecies: Species? { hero.flatMap(Species.find) }
    var preview: String {
        if let last_body { return last_body }
        if let last_sticker { return "\(Species.find(last_sticker)?.name ?? "캐릭터") 스티커" }
        return status == "friend" ? "첫 편지를 보내 보세요" : ""
    }
}

/// One letter in a conversation (from the `my_messages` view).
struct ChatMessage: Decodable, Identifiable, Equatable {
    let id: UUID
    let friend_id: UUID
    let mine: Bool
    let body: String?
    let sticker: String?
    let created_at: Date
    let read_at: Date?
}

/// Friends and letters on the SCOO server.
@MainActor
final class SocialStore: ObservableObject {
    @Published private(set) var profile: MyProfile?
    @Published private(set) var friends: [FriendRow] = []
    @Published var message: String?
    let client: SupabaseClient

    init(client: SupabaseClient = .shared) {
        self.client = client
    }

    var isAvailable: Bool { SupabaseConfig.isConfigured }
    var unreadTotal: Int { friends.reduce(0) { $0 + $1.unread } }
    var accepted: [FriendRow] { friends.filter { $0.status == "friend" } }
    var received: [FriendRow] { friends.filter { $0.status == "received" } }
    var sent: [FriendRow] { friends.filter { $0.status == "sent" } }

    func refresh() async {
        guard isAvailable else { return }
        do {
            profile = try await client.rpc("my_profile", [:], as: [MyProfile].self).first
            friends = try await client.rpc("list_friends", [:], as: [FriendRow].self)
        } catch {
            message = error.localizedDescription
        }
    }

    /// Asks someone by friend code. Returns a line for the user.
    func add(code: String) async -> String {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard clean.count == 6 else { return "친구 코드는 6자리예요." }
        do {
            let result = try await client.rpc("request_friend", ["p_code": clean], as: String.self)
            await refresh()
            switch result {
            case "friends": return "친구가 됐어요! 이제 편지를 보낼 수 있어요."
            case "already": return "이미 친구예요."
            default: return "친구 요청을 보냈어요. 상대가 받아 주면 친구가 돼요."
            }
        } catch {
            return error.localizedDescription
        }
    }

    func respond(_ friend: FriendRow, accept: Bool) async {
        do {
            _ = try await client.rpc("respond_friend", ["p_requester": friend.friend_id.uuidString, "p_accept": accept], as: Bool.self)
            await refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    func conversation(with friend: FriendRow) async throws -> [ChatMessage] {
        try await client.select("my_messages?friend_id=eq.\(friend.friend_id.uuidString)&order=created_at.asc&limit=300",
                                as: [ChatMessage].self)
    }

    func send(to friend: FriendRow, body: String?, sticker: String?) async throws {
        var params: [String: Any] = ["p_to": friend.friend_id.uuidString]
        params["p_body"] = body ?? NSNull()
        params["p_sticker"] = sticker ?? NSNull()
        _ = try await client.rpc("send_message", params, as: UUID.self)
    }

    func markRead(_ friend: FriendRow) async {
        _ = try? await client.rpc("mark_read", ["p_friend": friend.friend_id.uuidString], as: Int.self)
    }

    func setNickname(_ name: String) async throws {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(12))
        guard !clean.isEmpty else { throw SCOOError.message("이름을 한 글자 이상 적어 주세요.") }
        let me = try await client.signIn().userID
        try await client.update("profiles?id=eq.\(me)", ["nickname": clean])
        await refresh()
    }

    /// The character friends see next to my letters (the one floating in my camera).
    func setHero(_ id: String) async {
        guard isAvailable, profile?.hero != id, let me = try? await client.signIn().userID else { return }
        try? await client.update("profiles?id=eq.\(me)", ["hero": id])
    }
}
