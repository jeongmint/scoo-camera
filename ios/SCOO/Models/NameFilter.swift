import Foundation

/// 이름 짓기 규칙: names for friends, babies, Mori and the nickname friends see.
/// Names stay short and plain, and rude, sexual or hateful words cannot be used at all.
enum NameFilter {
    /// Friend and baby names; the friend nickname allows a little more.
    static let maxLength = 8

    enum Problem: Equatable {
        case empty, tooLong(Int), characters, numbers, word

        var message: String {
            switch self {
            case .empty: return "이름을 한 글자 이상 지어 주세요."
            case .tooLong(let limit): return "이름은 \(limit)글자까지 지을 수 있어요."
            case .characters: return "한글(완성된 글자), 영어, 숫자, 띄어쓰기만 쓸 수 있어요."
            case .numbers: return "숫자가 너무 많아요. 다른 이름으로 지어 주세요."
            case .word: return "쓸 수 없는 말이 들어 있어요. 다른 이름으로 지어 주세요."
            }
        }
    }

    /// Words that cannot appear anywhere in a name, after spaces, digits and marks are taken out
    /// ("시 1 발" is caught as "시발"). Lowercase for English.
    /// Edit shared/blocked_words.txt, not this list; the server checks nicknames with the same words.
    // BEGIN blocked words: generated from shared/blocked_words.txt by scripts/sync_blocked_words.py
    static let blocked: [String] = [
        "시발", "씨발", "씨바", "씨빨", "시빨", "쓰발", "쌍놈", "썅", "병신", "븅신", "빙신", "지랄",
        "개새", "개색", "새끼", "섀끼", "좆", "존나", "졸라", "니미", "느금", "애미", "애비", "엠창",
        "미친", "미췬", "닥쳐", "꺼져", "뒤져", "뒈져", "죽어", "죽일", "자살", "섹스", "쎅스", "섹시",
        "야동", "자지", "보지", "꼬추", "성기", "강간", "창녀", "창놈", "걸레", "화냥", "매춘", "원조교제",
        "한남충", "김치녀", "틀딱", "급식충", "맘충", "정신병", "변태", "노예", "마약", "대마", "필로폰", "운영자",
        "관리자", "fuck", "fck", "shit", "bitch", "sex", "porn", "dick", "cock", "pussy", "cunt", "nigg",
        "fag", "rape", "slut", "whore", "nazi", "hitler",
    ]
    // END blocked words

    /// Trimmed, with runs of spaces made one.
    static func clean(_ raw: String) -> String {
        raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Why this name cannot be used, or nil when it can.
    static func problem(_ raw: String, maxLength: Int = maxLength) -> Problem? {
        let name = clean(raw)
        guard !name.isEmpty else { return .empty }
        guard name.count <= maxLength else { return .tooLong(maxLength) }
        for scalar in name.unicodeScalars {
            let v = scalar.value
            let hangul = (0xAC00...0xD7A3).contains(v)
            let latin = (0x41...0x5A).contains(v) || (0x61...0x7A).contains(v)
            let digit = (0x30...0x39).contains(v)
            guard hangul || latin || digit || scalar == " " else { return .characters }
        }
        let digits = name.filter(\.isNumber).count
        if digits * 2 > name.count || name.contains(where: \.isNumber) && longestDigitRun(name) >= 4 { return .numbers }
        let letters = String(name.lowercased().filter { !$0.isNumber && $0 != " " })
        if blocked.contains(where: { letters.contains($0) }) { return .word }
        return nil
    }

    /// The name to keep, or nil (with the reason) when it cannot be used.
    static func accept(_ raw: String, maxLength: Int = maxLength) -> Result<String, SCOOError> {
        if let problem = problem(raw, maxLength: maxLength) { return .failure(.message(problem.message)) }
        return .success(clean(raw))
    }

    private static func longestDigitRun(_ text: String) -> Int {
        var best = 0, run = 0
        for character in text { run = character.isNumber ? run + 1 : 0; best = max(best, run) }
        return best
    }

    // MARK: Baby names

    /// A name made from the two parents' names, e.g. 멜로 × 루나 → 멜나. Never a character's own name,
    /// never a blocked word.
    static func blend(_ a: String, _ b: String) -> String {
        let first = Array(a.split(separator: " ").last.map(String.init) ?? a)
        let second = Array(b.split(separator: " ").last.map(String.init) ?? b)
        guard let a0 = first.first, let aN = first.last, let b0 = second.first, let bN = second.last else { return a + b }
        let taken = Set(Species.all.map { $0.name.split(separator: " ").last.map(String.init) ?? $0.name })
        for candidate in [String([a0, bN]), String([b0, aN]), String([a0, b0]), String([b0, a0]), String([aN, bN])]
        where !taken.contains(candidate) && problem(candidate) == nil {
            return candidate
        }
        return String(a0) + String(second)
    }
}
