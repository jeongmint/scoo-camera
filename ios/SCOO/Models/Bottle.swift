import Foundation

/// A glass bottle carrying a baby to someone else ("유리병 입양").
/// In this test build the other side is simulated on the device (`LocalOcean`); a server can take its place later.
struct Bottle: Identifiable, Codable, Equatable {
    enum Direction: String, Codable { case outgoing, incoming }

    let id: UUID
    let direction: Direction
    /// The baby inside (parent A gives the shape, parent B the color).
    let parentA: String
    let parentB: String
    /// Where the baby comes from, e.g. "마포구".
    let origin: String
    let sentAt: Date
    let arrivesAt: Date
    /// Outgoing: "가끔 소식 전해줘" was ticked, so letters come back.
    var wantsNews = false
    /// Incoming: the user opened it and took the baby in.
    var opened = false

    var title: String { "\(Species.find(parentA)?.name ?? parentA) × \(Species.find(parentB)?.name ?? parentB)" }
    /// The baby as it would look in the family list (for portraits).
    var baby: Breed { Breed(id: id, parentA: parentA, parentB: parentB, born: sentAt, bornAtMoment: 0, origin: origin) }

    func hasArrived(at now: Date) -> Bool { now >= arrivesAt }
}

/// A letter from a baby that was sent away, in the baby's own voice.
struct BottleLetter: Identifiable, Equatable {
    let id: String
    let bottle: Bottle
    let date: Date
    let text: String
}

enum BottleRules {
    /// Normal travel time, and the quick one for testing.
    static func travelTime(fast: Bool) -> TimeInterval { fast ? 60 : 24 * 60 * 60 }
    /// Gap between letters from an adopted baby.
    static func letterGap(fast: Bool) -> TimeInterval { fast ? 120 : 2 * 24 * 60 * 60 }
    static let maxLetters = 6
    /// Bottles a user may send per day (no limit in fast test mode).
    static let dailySends = 1

    static func canSend(_ bottles: [Bottle], now: Date, fast: Bool, calendar: Calendar = .current) -> Bool {
        if fast { return true }
        let today = bottles.filter { $0.direction == .outgoing && calendar.isDate($0.sentAt, inSameDayAs: now) }
        return today.count < dailySends
    }

    /// Letters that have arrived by `now` for every outgoing bottle that asked for news.
    static func letters(for bottles: [Bottle], now: Date, fast: Bool) -> [BottleLetter] {
        bottles.filter { $0.direction == .outgoing && $0.wantsNews }.flatMap { bottle -> [BottleLetter] in
            (0..<maxLetters).compactMap { index in
                let date = letterDate(bottle, index: index, fast: fast)
                guard date <= now else { return nil }
                return BottleLetter(id: "\(bottle.id)-\(index)", bottle: bottle, date: date, text: letterText(bottle, index: index))
            }
        }
        .sorted { $0.date > $1.date }
    }

    /// When letter `index` (0..<maxLetters) of an adopted baby comes back: a few hours after arrival, then every gap.
    static func letterDate(_ bottle: Bottle, index: Int, fast: Bool) -> Date {
        bottle.arrivesAt.addingTimeInterval(letterGap(fast: fast) * Double(index) + (fast ? 30 : 6 * 60 * 60))
    }

    /// The same bottle always tells the same story, in the same order.
    static func letterText(_ bottle: Bottle, index: Int) -> String {
        var generator = StableGenerator(seed: StableGenerator.seed(bottle.id))
        let place = SeoulDistrict.allCases.randomElement(using: &generator)?.rawValue ?? "어딘가"
        let friend = Species.all.filter { $0.id != bottle.parentA && !$0.isEvent }.randomElement(using: &generator)?.name ?? "새 친구"
        let lines = [
            "잘 도착했어! 여기는 \(place)야. 바람 냄새가 달라.",
            "여기서 \(friend)라는 친구가 생겼어.",
            "새 보호자가 맛있는 걸 잔뜩 찍어 줬어. 나 조금 컸다!",
            "\(bottle.origin) 출신이라고 다들 신기해해.",
            "오늘은 처음 보는 하늘을 봤어. 너도 같은 하늘 보고 있어?",
            "나 이만큼 컸다! 잘 지내지? 가끔 네 생각 나.",
        ]
        return lines[index % lines.count]
    }
}

/// The other side of the sea. The local one invents a bottle from somewhere in Seoul for every bottle sent;
/// a server-backed one would hand back a real bottle from another user.
protocol BottleOcean {
    func bottleInReturn(for sent: Bottle, fast: Bool) -> Bottle
}

struct LocalOcean: BottleOcean {
    func bottleInReturn(for sent: Bottle, fast: Bool) -> Bottle {
        var generator = SystemRandomNumberGenerator()
        return LocalOcean.make(after: sent, fast: fast, using: &generator)
    }

    static func make<G: RandomNumberGenerator>(after sent: Bottle, fast: Bool, using generator: inout G) -> Bottle {
        let family = Species.all.filter { !$0.isEvent }
        let a = family.randomElement(using: &generator) ?? Species.all[0]
        let b = family.filter { $0.id != a.id }.randomElement(using: &generator) ?? Species.all[1]
        let origin = SeoulDistrict.allCases.randomElement(using: &generator)?.rawValue ?? "어딘가"
        // It sets off a little after ours, so it arrives a little after ours too.
        let delay = Double.random(in: 0.1...0.5, using: &generator) * BottleRules.travelTime(fast: fast)
        let sentAt = sent.sentAt.addingTimeInterval(delay)
        return Bottle(id: UUID(), direction: .incoming, parentA: a.id, parentB: b.id, origin: origin,
                      sentAt: sentAt, arrivesAt: sentAt.addingTimeInterval(BottleRules.travelTime(fast: fast)))
    }
}

/// SplitMix64: a small generator whose output depends only on its seed.
struct StableGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// A seed taken from a UUID's bytes (unlike `hashValue`, the same on every launch).
    static func seed(_ id: UUID) -> UInt64 {
        withUnsafeBytes(of: id.uuid) { bytes in bytes.prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) } }
    }
}
