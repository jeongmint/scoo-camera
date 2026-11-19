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
    var arrivesAt: Date
    /// Outgoing: "가끔 소식 전해줘" was ticked, so letters come back.
    var wantsNews = false
    /// Incoming: the user opened it and took the baby in.
    var opened = false
    /// Outgoing: its sender already got their one thing back (a swapped bottle, or a new friend from the sea).
    /// Older records decode with nil.
    var settled: Bool? = nil

    /// A character travelling by itself (not a bred baby): both parents are the same species.
    var isCharacter: Bool { parentA == parentB }
    var character: Species? { isCharacter ? Species.find(parentA) : nil }
    var title: String {
        if isCharacter { return Species.find(parentA)?.name ?? parentA }
        return "\(Species.find(parentA)?.name ?? parentA) × \(Species.find(parentB)?.name ?? parentB)"
    }
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
    /// `moments`: words the new families shared (server); nil = the simulated sea makes some up.
    static func letters(for bottles: [Bottle], now: Date, fast: Bool, moments: [BottleMoment]? = nil) -> [BottleLetter] {
        bottles.filter { $0.direction == .outgoing && $0.wantsNews }.flatMap { bottle -> [BottleLetter] in
            (0..<maxLetters).compactMap { index in
                let date = letterDate(bottle, index: index, fast: fast)
                guard date <= now else { return nil }
                let word = self.word(for: bottle, index: index, fast: fast, moments: moments)
                return BottleLetter(id: "\(bottle.id)-\(index)", bottle: bottle, date: date, text: letterText(bottle, index: index, word: word))
            }
        }
        .sorted { $0.date > $1.date }
    }

    /// When letter `index` (0..<maxLetters) of an adopted baby comes back: a few hours after arrival, then every gap.
    static func letterDate(_ bottle: Bottle, index: Int, fast: Bool) -> Date {
        bottle.arrivesAt.addingTimeInterval(letterGap(fast: fast) * Double(index) + (fast ? 30 : 6 * 60 * 60))
    }

    /// What letter `index` talks about: a subject the new family photographed since the previous letter.
    /// On the simulated sea a made-up family photographs something about two letters in three.
    static func word(for bottle: Bottle, index: Int, fast: Bool, moments: [BottleMoment]?) -> String? {
        let end = letterDate(bottle, index: index, fast: fast)
        let start = index == 0 ? bottle.arrivesAt : letterDate(bottle, index: index - 1, fast: fast)
        guard let moments else {
            var generator = StableGenerator(seed: StableGenerator.seed(bottle.id) &+ UInt64(index + 1) &* 0x2545F4914F6CDD1D)
            guard Double.random(in: 0..<1, using: &generator) < 0.66 else { return nil }
            return LetterWords.words.keys.sorted().randomElement(using: &generator).flatMap { LetterWords.words[$0] }
        }
        return moments.first { $0.bottleID == bottle.id && $0.date > start && $0.date <= end }
            .flatMap { LetterWords.words[$0.subject] }
    }

    /// The same bottle always tells the same story, in the same order; `word` (what the new family
    /// photographed) replaces the line when there is one.
    static func letterText(_ bottle: Bottle, index: Int, word: String? = nil) -> String {
        if let word { return LetterWords.line(word: word, index: index) }
        var generator = StableGenerator(seed: StableGenerator.seed(bottle.id))
        let place = Regions.all.randomElement(using: &generator)?.title ?? "어딘가"
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
        let origin = Regions.all.randomElement(using: &generator)?.title ?? "어딘가"
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
