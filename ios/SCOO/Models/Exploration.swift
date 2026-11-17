import Foundation

/// 동네 탐험: the first photo taken in a Seoul district you have not visited yet meets a new friend.
/// Kept on the device (UserDefaults) for now.
struct Exploration: Codable, Equatable {
    struct Meeting: Codable, Equatable {
        let species: String
        let district: String
        let date: Date
    }

    /// District name → first visit.
    var visited: [String: Date] = [:]
    /// Friends met by exploring, in the order they were met.
    var met: [Meeting] = []

    var collected: Set<String> { Set(met.map(\.species)) }

    /// Records a photo in `district`. Returns the friend met, if this was a first visit and someone new was there.
    /// `others` are species already owned another way (the drawn friend, event friends), so they are not met twice.
    mutating func visit<G: RandomNumberGenerator>(_ district: SeoulDistrict, owned others: Set<String>, now: Date,
                                                  using generator: inout G) -> Species? {
        guard visited[district.rawValue] == nil else { return nil }
        visited[district.rawValue] = now
        let known = collected.union(others)
        let pick: Species?
        if let local = district.special, !known.contains(local.id) {
            pick = local
        } else {
            // no local friend (or already met): someone from the family nobody here has met yet
            pick = Species.all.filter { !$0.isEvent && !known.contains($0.id) }.randomElement(using: &generator)
        }
        if let pick { met.append(Meeting(species: pick.id, district: district.rawValue, date: now)) }
        return pick
    }

    // MARK: Storage

    static let key = "exploration"

    static func load(from defaults: UserDefaults = .standard) -> Exploration {
        guard let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(Exploration.self, from: data) else {
            return Exploration()
        }
        return value
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }

    /// Visits a district and saves the result. Returns the friend met, if any.
    @discardableResult
    static func record(_ district: SeoulDistrict, owned others: Set<String>, defaults: UserDefaults = .standard,
                       now: Date = Date()) -> Species? {
        var state = load(from: defaults)
        var generator = SystemRandomNumberGenerator()
        let met = state.visit(district, owned: others, now: now, using: &generator)
        state.save(to: defaults)
        return met
    }
}
