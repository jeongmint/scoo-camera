import Foundation
import Combine

/// Where bottles come from: the device alone (simulated sea) or the SCOO server (real people).
protocol BottleBackend {
    var isOnline: Bool { get }
    func load() async throws -> [Bottle]
    /// Sends a baby; returns the updated list.
    func send(_ baby: Breed, origin: String, wantsNews: Bool, fast: Bool, now: Date, current: [Bottle]) async throws -> [Bottle]
    /// Marks an arrived bottle opened; returns the updated list.
    func open(_ bottle: Bottle, now: Date, current: [Bottle]) async throws -> [Bottle]
}

/// Bottles sent and received. Babies move between this and `BreedStore`: sending removes one, opening adopts one.
@MainActor
final class BottleStore: ObservableObject {
    @Published private(set) var bottles: [Bottle] = []
    @Published var message: String?
    @Published private(set) var busy = false
    let backend: BottleBackend

    init(backend: BottleBackend) {
        self.backend = backend
    }

    convenience init(directory: URL = PhotoRepository.directory, ocean: BottleOcean = LocalOcean()) {
        self.init(backend: LocalBottleBackend(directory: directory, ocean: ocean))
    }

    /// The server when it is configured and the user wants real people, otherwise the simulated sea.
    static func preferred() -> BottleStore {
        let online = UserDefaults.standard.object(forKey: "bottleOnline") as? Bool ?? true
        if online && SupabaseConfig.isConfigured { return BottleStore(backend: SupabaseBottleBackend()) }
        return BottleStore()
    }

    var isOnline: Bool { backend.isOnline }

    func load() async {
        do { bottles = try await backend.load() }
        catch { message = backend.isOnline ? "유리병을 불러오지 못했어요. \(error.localizedDescription)" : "유리병 기록을 읽지 못했어요. 기존 파일은 그대로 두었어요." }
    }

    /// The server applies its own daily limit; offline the rule is checked here.
    func canSend(now: Date = Date(), fast: Bool) -> Bool {
        backend.isOnline || BottleRules.canSend(bottles, now: now, fast: fast)
    }

    /// Puts a baby in a bottle.
    func send(_ baby: Breed, wantsNews: Bool, from district: String?, breeds: BreedStore, fast: Bool, now: Date = Date()) async throws {
        guard canSend(now: now, fast: fast) else { throw SCOOError.message("유리병은 하루에 \(BottleRules.dailySends)번 띄울 수 있어요.") }
        busy = true
        defer { busy = false }
        let origin = baby.origin ?? district ?? "서울 어딘가"
        bottles = try await backend.send(baby, origin: origin, wantsNews: wantsNews, fast: fast, now: now, current: bottles)
        try breeds.remove(baby.id)
    }

    /// Opens an arrived bottle and takes the baby in.
    @discardableResult
    func open(_ bottle: Bottle, breeds: BreedStore, moments: Int, now: Date = Date()) async throws -> Breed {
        // Check the stored bottle, not the caller's copy, so a bottle can only be opened once.
        guard let stored = bottles.first(where: { $0.id == bottle.id }),
              stored.direction == .incoming, stored.hasArrived(at: now), !stored.opened else {
            throw SCOOError.message("아직 열 수 없는 유리병이에요.")
        }
        busy = true
        defer { busy = false }
        bottles = try await backend.open(stored, now: now, current: bottles)
        let baby = Breed(id: stored.id, parentA: stored.parentA, parentB: stored.parentB, born: now, bornAtMoment: moments,
                         origin: stored.origin, adopted: true)
        try breeds.adopt(baby)
        return baby
    }
}

// MARK: - On the device

/// The simulated sea: bottles.json next to the garden, answered by `LocalOcean`.
struct LocalBottleBackend: BottleBackend {
    let url: URL
    let ocean: BottleOcean
    var isOnline: Bool { false }

    init(directory: URL, ocean: BottleOcean) {
        url = directory.appendingPathComponent("bottles.json")
        self.ocean = ocean
    }

    func load() async throws -> [Bottle] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([Bottle].self, from: Data(contentsOf: url))
    }

    func send(_ baby: Breed, origin: String, wantsNews: Bool, fast: Bool, now: Date, current: [Bottle]) async throws -> [Bottle] {
        let outgoing = Bottle(id: UUID(), direction: .outgoing, parentA: baby.parentA, parentB: baby.parentB, origin: origin,
                              sentAt: now, arrivesAt: now.addingTimeInterval(BottleRules.travelTime(fast: fast)), wantsNews: wantsNews)
        let incoming = ocean.bottleInReturn(for: outgoing, fast: fast)
        let next = [incoming, outgoing] + current
        try write(next)
        return next
    }

    func open(_ bottle: Bottle, now: Date, current: [Bottle]) async throws -> [Bottle] {
        var next = current
        guard let index = next.firstIndex(where: { $0.id == bottle.id }) else { return current }
        next[index].opened = true
        try write(next)
        return next
    }

    private func write(_ next: [Bottle]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: url, options: .atomic)
    }
}

// MARK: - On the server

/// Real people, through the SCOO Supabase project (see supabase/migrations).
struct SupabaseBottleBackend: BottleBackend {
    var client: SupabaseClient = .shared
    var isOnline: Bool { true }

    /// A row of the `my_bottles` view.
    private struct Row: Decodable {
        let id: UUID
        let direction: String
        let parent_a: String
        let parent_b: String
        let origin: String
        let wants_news: Bool
        let sent_at: Date
        let arrives_at: Date?
        let opened: Bool
    }

    func load() async throws -> [Bottle] {
        let rows = try await client.select("my_bottles?select=*&order=sent_at.desc", as: [Row].self)
        return rows.map { row in
            // A bottle still waiting at sea for a partner has no arrival time yet.
            Bottle(id: row.id, direction: row.direction == "incoming" ? .incoming : .outgoing,
                   parentA: row.parent_a, parentB: row.parent_b, origin: row.origin, sentAt: row.sent_at,
                   arrivesAt: row.arrives_at ?? .distantFuture, wantsNews: row.wants_news, opened: row.opened)
        }
    }

    func send(_ baby: Breed, origin: String, wantsNews: Bool, fast: Bool, now: Date, current: [Bottle]) async throws -> [Bottle] {
        _ = try await client.rpc("send_bottle", ["p_parent_a": baby.parentA, "p_parent_b": baby.parentB, "p_origin": origin,
                                                 "p_wants_news": wantsNews, "p_fast": fast], as: UUID.self)
        return try await load()
    }

    func open(_ bottle: Bottle, now: Date, current: [Bottle]) async throws -> [Bottle] {
        let opened = try await client.rpc("open_bottle", ["p_id": bottle.id.uuidString], as: Bool.self)
        guard opened else { throw SCOOError.message("아직 열 수 없는 유리병이에요.") }
        return try await load()
    }
}

extension Bottle {
    /// Sent, but no one has sent a bottle back yet (server only).
    var isWaitingAtSea: Bool { arrivesAt == .distantFuture }
}
