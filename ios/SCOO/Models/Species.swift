import Foundation
import CoreGraphics

/// Where an adult's daisy goes: the horizontal spot on the silhouette (0...1 of its width),
/// whether to skip ears/stems and pin it where they meet the head, and how much lower to go
/// (in flower heights). Mirrors `tools/breeding/characters.json`.
struct DaisySpot: Hashable {
    var x: CGFloat = 0.27
    var belowEars = false
    var drop: CGFloat = 0
}

/// Every character in the SCOO family that can be a breeding parent.
struct Species: Identifiable, Hashable {
    let id: String
    let name: String
    let assetName: String
    var isEvent = false
    var daisy = DaisySpot()
    /// Seasonal event friends (해피 겨울, 보미 봄, 소르 여름, 도토 가을).
    var season: Season? = nil
}

/// The four seasons by month (봄 3–5, 여름 6–8, 가을 9–11, 겨울 12–2).
enum Season: String, CaseIterable {
    case spring, summer, autumn, winter

    var title: String {
        switch self {
        case .spring: return "봄"
        case .summer: return "여름"
        case .autumn: return "가을"
        case .winter: return "겨울"
        }
    }

    static func of(_ date: Date, calendar: Calendar = .current) -> Season {
        switch calendar.component(.month, from: date) {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .autumn
        default: return .winter
        }
    }
}

extension Species {
    static let all: [Species] = [
        Species(id: "gwiyo", name: "귀요", assetName: "Companion-gwiyo"),
        Species(id: "kuru", name: "쿠르", assetName: "Companion-kuru"),
        Species(id: "mori", name: "모리", assetName: "Companion-mori"),
        Species(id: "nyamo", name: "냐모", assetName: "Companion-nyamo", daisy: DaisySpot(x: 0.26, belowEars: true, drop: 0.25)),
        Species(id: "happy", name: "해피", assetName: "Companion-happy", isEvent: true, season: .winter),
        Species(id: "huu", name: "후우", assetName: "Species-huu"),
        Species(id: "chiko", name: "치코", assetName: "Species-chiko", daisy: DaisySpot(x: 0.26, belowEars: true, drop: 0.25)),
        Species(id: "dochi", name: "도치", assetName: "Species-dochi"),
        Species(id: "luna", name: "루나", assetName: "Species-luna"),
        Species(id: "toto", name: "토토", assetName: "Species-toto"),
        Species(id: "sunny", name: "써니", assetName: "Species-sunny"),
        Species(id: "suri", name: "수리", assetName: "Species-suri"),
        Species(id: "mellu", name: "멜루", assetName: "Species-mellu"),
        Species(id: "riru", name: "리루", assetName: "Species-riru"),
        Species(id: "popo", name: "포포", assetName: "Species-popo"),
        Species(id: "tangerine", name: "귤", assetName: "Species-tangerine"),
        Species(id: "baseball", name: "야구공", assetName: "Species-baseball"),
        Species(id: "otter", name: "튜브를 한 수달", assetName: "Species-otter"),
        Species(id: "yarn", name: "실타래", assetName: "Species-yarn"),
        Species(id: "tori", name: "토리", assetName: "Species-tori", daisy: DaisySpot(x: 0.33, belowEars: true)),
        Species(id: "mupu", name: "무푸", assetName: "Species-mupu"),
        Species(id: "deogi", name: "더기", assetName: "Species-deogi"),
        Species(id: "hechi", name: "헤치", assetName: "Species-hechi"),
        Species(id: "sia", name: "시아", assetName: "Species-sia"),
        Species(id: "dia", name: "디아", assetName: "Species-dia"),
        Species(id: "komi", name: "코미", assetName: "Species-komi"),
        Species(id: "mello", name: "멜로", assetName: "Species-mello"),
        Species(id: "bandi", name: "반디", assetName: "Species-bandi"),
        Species(id: "lumi", name: "루미", assetName: "Species-lumi"),
        // 서울 한정 동네 친구 (2026-11-18)
        Species(id: "bosong", name: "보송", assetName: "Species-bosong"),
        Species(id: "cabi", name: "캐비", assetName: "Species-cabi"),
        Species(id: "chiru", name: "치루", assetName: "Species-chiru", daisy: DaisySpot(x: 0.26, belowEars: true, drop: 0.25)),
        Species(id: "sena", name: "세나", assetName: "Species-sena"),
        Species(id: "inky", name: "잉키", assetName: "Species-inky"),
        Species(id: "momo", name: "모모", assetName: "Species-momo"),
        Species(id: "mumu", name: "무무", assetName: "Species-mumu"),
        Species(id: "pico", name: "피코", assetName: "Species-pico"),
        Species(id: "posil", name: "포실", assetName: "Species-posil"),
        Species(id: "rora", name: "로라", assetName: "Species-rora"),
        Species(id: "bomi", name: "보미", assetName: "Species-bomi", isEvent: true, season: .spring),
        Species(id: "soru", name: "소르", assetName: "Species-soru", isEvent: true, season: .summer),
        Species(id: "doto", name: "도토", assetName: "Species-doto", isEvent: true,
                daisy: DaisySpot(x: 0.26, belowEars: true, drop: 0.25), season: .autumn),
    ]

    static func find(_ id: String) -> Species? { all.first { $0.id == id } }

    /// Who a user can breed with: the characters they have. The test switch opens the whole family.
    static func owned(_ friends: [Species], unlockAll: Bool) -> [Species] {
        unlockAll ? all : friends
    }
}
