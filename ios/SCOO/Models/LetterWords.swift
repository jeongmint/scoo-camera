import Foundation

/// A photo subject the new family shared for an adopted baby's letters (no photo, only the word).
struct BottleMoment: Equatable, Codable {
    let bottleID: UUID
    /// One of `LetterWords.words`' keys.
    let subject: String
    let date: Date
}

/// Words in adopted babies' letters instead of photos (입양 편지에 사진 대신 단어).
/// Strangers never see each other's photos: the new family's phone turns a photo into one of a few fixed
/// subjects (the same Vision labels as 오늘의 미션), and only that word travels.
enum LetterWords {
    /// Subject id (as the server allows them) → the word a baby writes.
    static let words: [String: String] = [
        "sky": "하늘", "cat": "고양이", "flower": "꽃", "dog": "강아지", "green": "나무랑 풀",
        "sweet": "달콤한 디저트", "sign": "알록달록 간판", "water": "물가", "coffee": "커피", "book": "책",
        "food": "맛있는 음식",
    ]

    /// The subjects a photo shows, from its Vision labels and the food guess.
    static func subjects(labels: [String], isFood: Bool) -> [String] {
        var found = DailyMission.all.filter { $0.matches(labels) }.map(\.id)
        if isFood { found.append("food") }
        return found.filter { words[$0] != nil }
    }

    /// The word with 을/를, chosen by whether its last syllable ends in a consonant.
    static func withObjectParticle(_ word: String) -> String {
        guard let last = word.unicodeScalars.last, (0xAC00...0xD7A3).contains(last.value) else { return word + "을(를)" }
        return word + ((last.value - 0xAC00) % 28 == 0 ? "를" : "을")
    }

    /// A letter line built around what the new family photographed.
    static func line(word: String, index: Int) -> String {
        switch index % 3 {
        case 0: return "오늘 새 가족이랑 \(withObjectParticle(word)) 봤어! 너도 좋아했을 거야."
        case 1: return "새 보호자가 \(word) 사진을 찍어 줬어. 나도 옆에서 같이 봤다!"
        default: return "여기선 \(withObjectParticle(word)) 자주 봐. 그때마다 네 생각 나."
        }
    }

    /// Sends today's subjects for the babies this account adopted (the server keeps only those whose first
    /// family asked for news, once per subject per day). Quiet on failure; never creates an account.
    static func share(_ subjects: [String]) async {
        let defaults = UserDefaults.standard
        guard !subjects.isEmpty,
              defaults.object(forKey: "shareMoments") as? Bool ?? true,
              defaults.object(forKey: "bottleOnline") as? Bool ?? true,
              SupabaseConfig.isConfigured,
              await SupabaseClient.shared.currentUserID != nil else { return }
        _ = try? await SupabaseClient.shared.rpc("share_moment", ["p_subjects": subjects], as: Int.self)
    }
}
