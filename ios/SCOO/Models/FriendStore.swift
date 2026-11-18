import Foundation
import Combine

/// A character this user has (babies from breeding live in `BreedStore`).
struct OwnedFriend: Codable, Identifiable, Equatable {
    enum How: String, Codable {
        /// The first friend, one of the 5 of the place the user started in.
        case starter
        /// Came in a glass bottle from someone else.
        case adopted
        /// The sea brought it the day after a bottle found nobody.
        case sea
        /// Event friend (the snowman in the test build).
        case event
        /// Met while exploring, before exploring only stamped visits.
        case explored
    }

    let id: UUID
    let species: String
    let how: How
    let since: Date
    var origin: String? = nil

    var character: Species? { Species.find(species) }
    /// Event friends stay; everything else can be sent in a bottle.
    var canTravel: Bool { how != .event }
}

/// The characters this user has, on this device. Shared by every screen.
@MainActor
final class FriendStore: ObservableObject {
    static let shared = FriendStore()

    @Published private(set) var friends: [OwnedFriend] = []
    /// Every character this user has ever had (the collection keeps them after they leave).
    @Published private(set) var seen: Set<String> = []

    private let defaults: UserDefaults
    static let key = "ownedFriends"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    /// Distinct characters, in the order they came.
    var species: [Species] {
        var ids: [String] = []
        for friend in friends where !ids.contains(friend.species) { ids.append(friend.species) }
        return ids.compactMap(Species.find)
    }

    var starter: OwnedFriend? { friends.first { $0.how == .starter } }
    var hasStarter: Bool { starter != nil }

    func owns(_ speciesID: String) -> Bool { friends.contains { $0.species == speciesID } }

    /// Replaces the first friend (testing tools re-draw it). Other friends stay.
    func setStarter(_ species: Species, origin: String?, now: Date = Date()) {
        friends.removeAll { $0.how == .starter }
        friends.insert(OwnedFriend(id: UUID(), species: species.id, how: .starter, since: now, origin: origin), at: 0)
        save()
    }

    @discardableResult
    func add(_ species: Species, how: OwnedFriend.How, origin: String?, now: Date = Date()) -> OwnedFriend {
        let friend = OwnedFriend(id: UUID(), species: species.id, how: how, since: now, origin: origin)
        friends.append(friend)
        save()
        return friend
    }

    func remove(_ id: UUID) {
        friends.removeAll { $0.id == id }
        save()
    }

    /// A random new character from the sea: one of the 5 of the user's place they do not have yet if possible.
    func seaFriend<G: RandomNumberGenerator>(near region: Region?, using generator: inout G) -> Species {
        let local = region?.candidateSpecies ?? []
        let everyone = Species.all.filter { !$0.isEvent }
        let pool = [local.filter { !owns($0.id) }, everyone.filter { !owns($0.id) }, local, everyone].first { !$0.isEmpty } ?? everyone
        return pool.randomElement(using: &generator)!
    }

    // MARK: Storage

    private struct Saved: Codable {
        var friends: [OwnedFriend]
        var seen: [String]
    }

    private func load() {
        if let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            friends = saved.friends
            seen = Set(saved.seen).union(saved.friends.map(\.species))
            return
        }
        migrate()
    }

    /// Before characters could travel, a user had the drawn friend, the snowman and friends met exploring.
    private func migrate() {
        var start: [OwnedFriend] = []
        let now = Date()
        if let raw = defaults.string(forKey: "assignedCompanion"), Species.find(raw) != nil {
            start.append(OwnedFriend(id: UUID(), species: raw, how: .starter, since: now))
            start.append(OwnedFriend(id: UUID(), species: "happy", how: .event, since: now))
        }
        for meeting in Exploration.load(from: defaults).met where !start.contains(where: { $0.species == meeting.species }) {
            start.append(OwnedFriend(id: UUID(), species: meeting.species, how: .explored, since: meeting.date, origin: meeting.place))
        }
        friends = start
        seen = Set(start.map(\.species))
        if !start.isEmpty { save() }
    }

    private func save() {
        seen.formUnion(friends.map(\.species))
        if let data = try? JSONEncoder().encode(Saved(friends: friends, seen: Array(seen))) { defaults.set(data, forKey: Self.key) }
        // the camera friend (`companion`) must be one the user still has
        if let picked = defaults.string(forKey: "companion"), !picked.isEmpty, !owns(picked) { defaults.set("", forKey: "companion") }
        WidgetBridge.refresh()
    }
}
