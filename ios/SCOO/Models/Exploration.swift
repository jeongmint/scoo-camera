import Foundation

/// 동네 탐험: the first photo taken in a 시군구 you have not visited yet meets the friend who lives there,
/// if you have not met it before. Each friend lives in several places, so rare friends need a trip.
/// Kept on the device (UserDefaults).
struct Exploration: Codable, Equatable {
    struct Meeting: Codable, Equatable {
        let species: String
        /// Region id ("서울 마포구"); records from the Seoul-only days hold just "마포구".
        let district: String
        let date: Date

        var place: String { Regions.resolve(district)?.title ?? district }
    }

    /// What a photo in a place brought.
    enum Visit: Equatable {
        /// First time here, and its friend is new.
        case met(Species)
        /// First time here, but its friend was met before (somewhere else, or it is the user's own friend).
        case stamped(Species?)
        /// Been here before.
        case again
    }

    /// Region id → first visit.
    var visited: [String: Date] = [:]
    /// Friends met by exploring, in the order they were met.
    var met: [Meeting] = []

    var collected: Set<String> { Set(met.map(\.species)) }

    /// Records a photo in `region`. `others` are species already owned another way (the drawn friend, event
    /// friends), so they are not met twice.
    mutating func visit(_ region: Region, owned others: Set<String>, now: Date) -> Visit {
        guard visited[region.id] == nil else { return .again }
        visited[region.id] = now
        guard let local = region.friend else { return .stamped(nil) }
        if collected.union(others).contains(local.id) { return .stamped(local) }
        met.append(Meeting(species: local.id, district: region.id, date: now))
        return .met(local)
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

    /// Visits a place and saves the result.
    @discardableResult
    static func record(_ region: Region, owned others: Set<String>, defaults: UserDefaults = .standard,
                       now: Date = Date()) -> Visit {
        var state = load(from: defaults)
        let result = state.visit(region, owned: others, now: now)
        state.save(to: defaults)
        return result
    }

    /// Before regions went nationwide, places were stored as bare Seoul district names ("마포구").
    mutating func migrateSeoulNames() {
        var moved: [String: Date] = [:]
        for (key, date) in visited { moved[Regions.resolve(key)?.id ?? key] = date }
        visited = moved
        met = met.map { Meeting(species: $0.species, district: Regions.resolve($0.district)?.id ?? $0.district, date: $0.date) }
    }
}
