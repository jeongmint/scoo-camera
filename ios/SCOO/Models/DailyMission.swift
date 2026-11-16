import Foundation

/// 오늘의 미션: one subject a day (the same for everyone). A photo that shows it earns a bonus once that day.
/// Whether a photo shows it is decided on the device from Apple Vision's scene labels.
struct DailyMission: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    /// Vision label words that count as this subject.
    let terms: [String]

    static let bonus = 15

    static let all: [DailyMission] = [
        DailyMission(id: "sky", title: "하늘", systemImage: "cloud", terms: ["sky", "cloud", "cloudy", "sunset", "sunrise", "blue_sky"]),
        DailyMission(id: "cat", title: "고양이", systemImage: "cat", terms: ["cat", "kitten", "feline"]),
        DailyMission(id: "flower", title: "꽃", systemImage: "camera.macro", terms: ["flower", "blossom", "rose", "tulip", "daisy", "sunflower", "petal", "bouquet"]),
        DailyMission(id: "dog", title: "강아지", systemImage: "dog", terms: ["dog", "puppy", "canine"]),
        DailyMission(id: "green", title: "초록 식물", systemImage: "leaf", terms: ["plant", "tree", "grass", "leaf", "foliage", "moss", "houseplant", "forest"]),
        DailyMission(id: "sweet", title: "달콤한 디저트", systemImage: "birthday.cake", terms: ["dessert", "cake", "cookie", "ice_cream", "pastry", "donut", "chocolate", "candy"]),
        DailyMission(id: "sign", title: "간판", systemImage: "signpost.right", terms: ["sign", "signage", "signboard", "billboard", "storefront", "shop", "text"]),
        DailyMission(id: "water", title: "물가", systemImage: "water.waves", terms: ["water", "sea", "ocean", "lake", "river", "beach", "waterfront"]),
        DailyMission(id: "coffee", title: "커피 한 잔", systemImage: "cup.and.saucer", terms: ["coffee", "latte", "cappuccino", "espresso", "cafe"]),
        DailyMission(id: "book", title: "책", systemImage: "book", terms: ["book", "bookshelf", "library", "magazine"]),
    ]

    /// The day's mission: everyone sees the same one, and it changes at local midnight.
    static func of(_ date: Date, calendar: Calendar = .current) -> DailyMission {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = (parts.year ?? 0) * 372 + (parts.month ?? 0) * 31 + (parts.day ?? 0)
        // step by 7 (coprime with 10) so neighbouring days get different subjects
        return all[(day * 7) % all.count]
    }

    /// A key for "already done today".
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Whether any of the photo's labels names this subject.
    func matches(_ labels: [String]) -> Bool {
        labels.contains { raw in
            let label = raw.lowercased().replacingOccurrences(of: " ", with: "_")
            return terms.contains { term in label == term || label.hasPrefix(term + "_") || label.hasSuffix("_" + term) }
        }
    }
}
