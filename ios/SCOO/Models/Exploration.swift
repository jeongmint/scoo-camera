import Foundation

/// 동네 탐험: the first photo taken in a 시군구 you have not visited yet stamps it in the collection.
/// Characters are no longer met this way; they come from glass bottles. Kept on the device (UserDefaults).
struct Exploration: Codable, Equatable {
    /// Friends met while exploring, from before exploring only stamped (kept so they can move to the friend list).
    struct Meeting: Codable, Equatable {
        let species: String
        /// Region id ("서울 마포구"); records from the Seoul-only days hold just "마포구".
        let district: String
        let date: Date

        var place: String { Regions.resolve(district)?.title ?? district }
    }

    /// Region id → first visit.
    var visited: [String: Date] = [:]
    var met: [Meeting] = []

    /// Records a photo in `region`. True when it is the first visit (a new stamp).
    mutating func visit(_ region: Region, now: Date) -> Bool {
        guard visited[region.id] == nil else { return false }
        visited[region.id] = now
        return true
    }

    /// Visited places counted per province, for the collection screen.
    func visits(in province: Province) -> Int {
        visited.keys.compactMap(Regions.resolve).filter { $0.province == province }.count
    }

    // MARK: Storage

    static let key = "exploration"

    static func load(from defaults: UserDefaults = .standard) -> Exploration {
        guard let data = defaults.data(forKey: key), var value = try? JSONDecoder().decode(Exploration.self, from: data) else {
            return Exploration()
        }
        value.migrateSeoulNames()
        return value
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }

    /// Visits a place and saves the result. True when it was a new stamp.
    @discardableResult
    static func record(_ region: Region, defaults: UserDefaults = .standard, now: Date = Date()) -> Bool {
        var state = load(from: defaults)
        let stamped = state.visit(region, now: now)
        state.save(to: defaults)
        return stamped
    }

    /// Before regions went nationwide, places were stored as bare Seoul district names ("마포구").
    mutating func migrateSeoulNames() {
        var moved: [String: Date] = [:]
        for (key, date) in visited { moved[Regions.resolve(key)?.id ?? key] = date }
        visited = moved
        met = met.map { Meeting(species: $0.species, district: Regions.resolve($0.district)?.id ?? $0.district, date: $0.date) }
    }
}
