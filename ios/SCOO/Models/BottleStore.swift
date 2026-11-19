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
    /// Words the new families shared for babies this account sent away; nil on the simulated sea.
    func moments() async throws -> [BottleMoment]?
    /// Nobody came for this bottle in time: marks it settled so the sea can bring a new character instead.
    /// True only once, and only when it is due.
    func settle(_ bottle: Bottle, fast: Bool, now: Date, current: [Bottle]) async throws -> (Bool, [Bottle])
}

extension BottleBackend {
    func moments() async throws -> [BottleMoment]? { nil }
}

/// What came out of an opened bottle.
enum BottleGift: Identifiable, Equatable {
    case baby(Breed)
    case character(Species)
    var id: String {
        switch self {
        case .baby(let baby): return baby.id.uuidString
        case .character(let species): return species.id
        }
    }
}

/// Bottles sent and received. Babies move between this and `BreedStore`: sending removes one, opening adopts one.
@MainActor
final class BottleStore: ObservableObject {
    @Published private(set) var bottles: [Bottle] = [] {
        // Keep the phone's own arrival and letter notifications in step with the bottles.
        didSet { if bottles != oldValue { let current = bottles, real = backend.isOnline; Task { await LocalNotifier.reschedule(current, real: real) } } }
    }
    @Published var message: String?
    @Published private(set) var busy = false
    /// Words for adopted babies' letters (server); nil = the simulated sea makes them up.
    @Published private(set) var moments: [BottleMoment]?
    let backend: BottleBackend

    init(backend: BottleBackend) {
        self.backend = backend
    }

    convenience init(directory: URL = PhotoRepository.directory, ocean: BottleOcean = LocalOcean(),
                     luck: @escaping (UUID) -> Bool = LocalBottleBackend.someoneCame) {
        self.init(backend: LocalBottleBackend(directory: directory, ocean: ocean, luck: luck))
    }

    /// The server when it is configured and the user wants real people, otherwise the simulated sea.
    static func preferred() -> BottleStore {
        let online = UserDefaults.standard.object(forKey: "bottleOnline") as? Bool ?? true
        if online && SupabaseConfig.isConfigured { return BottleStore(backend: SupabaseBottleBackend()) }
        return BottleStore()
    }

    var isOnline: Bool { backend.isOnline }

    func load() async {
        do {
            bottles = try await backend.load()
            // Letters still work without the words, so a failure here only drops them.
            moments = backend.isOnline ? ((try? await backend.moments()) ?? []) : nil
        }
        catch { message = backend.isOnline ? "유리병을 불러오지 못했어요. \(error.localizedDescription)" : "유리병 기록을 읽지 못했어요. 기존 파일은 그대로 두었어요." }
    }

    /// The server applies its own daily limit; offline the rule is checked here.
    func canSend(now: Date = Date(), fast: Bool) -> Bool {
        backend.isOnline || BottleRules.canSend(bottles, now: now, fast: fast)
    }

    /// Whether someone with this many characters and babies may send one: never the last one.
    static func canPart(friends: Int, babies: Int) -> Bool { friends + babies >= 2 }

    /// Puts one of my characters in a bottle (it leaves my list). The last one stays.
    func send(_ friend: OwnedFriend, wantsNews: Bool, from district: String?, friends: FriendStore, babies: Int,
              fast: Bool, now: Date = Date()) async throws {
        guard friend.canTravel else { throw SCOOError.message("이벤트 친구는 유리병을 탈 수 없어요.") }
        guard Self.canPart(friends: friends.friends.count, babies: babies) else {
            throw SCOOError.message("마지막 한 마리는 보낼 수 없어요.")
        }
        guard canSend(now: now, fast: fast) else { throw SCOOError.message("유리병은 하루에 \(BottleRules.dailySends)번 띄울 수 있어요.") }
        busy = true
        defer { busy = false }
        let traveller = Breed(id: friend.id, parentA: friend.species, parentB: friend.species, born: friend.since, bornAtMoment: 0,
                              origin: friend.origin)
        bottles = try await backend.send(traveller, origin: district.flatMap { Regions.resolve($0)?.title } ?? friend.origin ?? "어딘가",
                                         wantsNews: wantsNews, fast: fast, now: now, current: bottles)
        friends.remove(friend.id)
        askForNotifications()
    }

    private func askForNotifications() {
        // The first bottle is the moment to ask: "tell me when it arrives / when the baby writes".
        let current = bottles, real = backend.isOnline
        Task {
            await LocalNotifier.askIfNeeded()
            await LocalNotifier.reschedule(current, real: real)
        }
    }

    /// Bottles I sent that nobody came for by the next day: the sea brings a new character for each, one of the
    /// 5 of the place the bottle was sent from (else `home`), one the user does not have yet if possible.
    /// So sending a bottle while travelling brings that place's friends. Returns what came.
    @discardableResult
    func settleWaiting(home: Region?, friends: FriendStore, fast: Bool, now: Date = Date()) async -> [Species] {
        var came: [Species] = []
        for bottle in bottles where bottle.direction == .outgoing && bottle.isWaitingAtSea && bottle.settled != true
            && bottle.sentAt.addingTimeInterval(BottleRules.travelTime(fast: fast)) <= now {
            guard let result = try? await backend.settle(bottle, fast: fast, now: now, current: bottles) else { continue }
            bottles = result.1
            guard result.0 else { continue }
            var generator = SystemRandomNumberGenerator()
            let place = Regions.resolve(bottle.origin) ?? home
            let species = friends.seaFriend(near: place, using: &generator)
            friends.add(species, how: .sea, origin: place?.title, now: now)
            came.append(species)
        }
        return came
    }

    /// Puts a baby in a bottle.
    func send(_ baby: Breed, wantsNews: Bool, from district: String?, breeds: BreedStore, friends: Int, fast: Bool,
              now: Date = Date()) async throws {
        guard Self.canPart(friends: friends, babies: breeds.breeds.count) else { throw SCOOError.message("마지막 한 마리는 보낼 수 없어요.") }
        guard canSend(now: now, fast: fast) else { throw SCOOError.message("유리병은 하루에 \(BottleRules.dailySends)번 띄울 수 있어요.") }
        busy = true
        defer { busy = false }
        // the bottle leaves from where the user is (that place's friends answer if nobody swaps)
        let origin = district.flatMap { Regions.resolve($0)?.title } ?? baby.origin ?? "어딘가"
        // A baby of bred parents travels as the species it came from, so the other family sees known names.
        let travelling = Breed(id: baby.id, parentA: baby.shapeA ?? baby.parentA, parentB: baby.colorB ?? baby.parentB,
                               born: baby.born, bornAtMoment: baby.bornAtMoment, origin: baby.origin, adopted: baby.adopted)
        bottles = try await backend.send(travelling, origin: origin, wantsNews: wantsNews, fast: fast, now: now, current: bottles)
        try breeds.remove(baby.id)
        askForNotifications()
    }

    /// Opens an arrived bottle: a character joins my friends, a baby joins my babies.
    @discardableResult
    func open(_ bottle: Bottle, breeds: BreedStore, friends: FriendStore, moments: Int, now: Date = Date()) async throws -> BottleGift {
        // Check the stored bottle, not the caller's copy, so a bottle can only be opened once.
        guard let stored = bottles.first(where: { $0.id == bottle.id }),
              stored.direction == .incoming, stored.hasArrived(at: now), !stored.opened else {
            throw SCOOError.message("아직 열 수 없는 유리병이에요.")
        }
        busy = true
        defer { busy = false }
        bottles = try await backend.open(stored, now: now, current: bottles)
        if let species = stored.character {
            friends.add(species, how: .adopted, origin: stored.origin, now: now)
            return .character(species)
        }
        let baby = Breed(id: stored.id, parentA: stored.parentA, parentB: stored.parentB, born: now, bornAtMoment: moments,
                         origin: stored.origin, adopted: true)
        try breeds.adopt(baby)
        return .baby(baby)
    }
}

// MARK: - On the device

/// The simulated sea: bottles.json next to the garden, answered by `LocalOcean`.
struct LocalBottleBackend: BottleBackend {
    let url: URL
    let ocean: BottleOcean
    /// Whether someone on the simulated sea swaps for a given bottle (injectable for tests).
    let luck: (UUID) -> Bool
    var isOnline: Bool { false }

    init(directory: URL, ocean: BottleOcean, luck: @escaping (UUID) -> Bool = LocalBottleBackend.someoneCame) {
        url = directory.appendingPathComponent("bottles.json")
        self.ocean = ocean
        self.luck = luck
    }

    func load() async throws -> [Bottle] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([Bottle].self, from: Data(contentsOf: url))
    }

    func send(_ baby: Breed, origin: String, wantsNews: Bool, fast: Bool, now: Date, current: [Bottle]) async throws -> [Bottle] {
        var outgoing = Bottle(id: UUID(), direction: .outgoing, parentA: baby.parentA, parentB: baby.parentB, origin: origin,
                              sentAt: now, arrivesAt: now.addingTimeInterval(BottleRules.travelTime(fast: fast)), wantsNews: wantsNews)
        // About half the time someone on the simulated sea swaps; otherwise the bottle waits and the sea
        // brings a new character the next day.
        var next = current
        if luck(outgoing.id) {
            next.insert(ocean.bottleInReturn(for: outgoing, fast: fast), at: 0)
        } else {
            outgoing.arrivesAt = .distantFuture
        }
        next.insert(outgoing, at: 0)
        try write(next)
        return next
    }

    /// The same bottle always has the same luck.
    static func someoneCame(_ id: UUID) -> Bool {
        var generator = StableGenerator(seed: StableGenerator.seed(id) &+ 7)
        return Double.random(in: 0..<1, using: &generator) < 0.5
    }

    func settle(_ bottle: Bottle, fast: Bool, now: Date, current: [Bottle]) async throws -> (Bool, [Bottle]) {
        var next = current
        guard let index = next.firstIndex(where: { $0.id == bottle.id }), next[index].settled != true,
              next[index].isWaitingAtSea, next[index].sentAt.addingTimeInterval(BottleRules.travelTime(fast: fast)) <= now else {
            return (false, current)
        }
        // someone on the sea adopts it after all (so its letters can come), and it counts as settled
        next[index].settled = true
        next[index].arrivesAt = now
        try write(next)
        return (true, next)
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
        /// Added with the adoption rework; older servers leave it out.
        let settled: Bool?
    }

    func moments() async throws -> [BottleMoment]? {
        struct Row: Decodable { let bottle_id: UUID; let subject: String; let created_at: Date }
        let rows = try await client.select("bottle_moments?select=bottle_id,subject,created_at&order=created_at.asc", as: [Row].self)
        return rows.map { BottleMoment(bottleID: $0.bottle_id, subject: $0.subject, date: $0.created_at) }
    }

    func load() async throws -> [Bottle] {
        let rows = try await client.select("my_bottles?select=*&order=sent_at.desc", as: [Row].self)
        return rows.map { row in
            // A bottle still waiting at sea for a partner has no arrival time yet.
            Bottle(id: row.id, direction: row.direction == "incoming" ? .incoming : .outgoing,
                   parentA: row.parent_a, parentB: row.parent_b, origin: row.origin, sentAt: row.sent_at,
                   arrivesAt: row.arrives_at ?? .distantFuture, wantsNews: row.wants_news, opened: row.opened, settled: row.settled)
        }
    }

    func settle(_ bottle: Bottle, fast: Bool, now: Date, current: [Bottle]) async throws -> (Bool, [Bottle]) {
        let settled = try await client.rpc("settle_bottle", ["p_id": bottle.id.uuidString, "p_fast": fast], as: Bool.self)
        return (settled, try await load())
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
