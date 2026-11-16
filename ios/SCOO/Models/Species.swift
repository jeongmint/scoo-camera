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
}

extension Species {
    static let all: [Species] = [
        Species(id: "gwiyo", name: "귀요", assetName: "Companion-gwiyo"),
        Species(id: "kuru", name: "쿠르", assetName: "Companion-kuru"),
        Species(id: "mori", name: "모리", assetName: "Companion-mori"),
        Species(id: "nyamo", name: "냐모", assetName: "Companion-nyamo", daisy: DaisySpot(x: 0.26, belowEars: true, drop: 0.25)),
        Species(id: "happy", name: "해피", assetName: "Companion-happy", isEvent: true),
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
    ]

    static func find(_ id: String) -> Species? { all.first { $0.id == id } }

    /// The species matching a camera friend (귀요·쿠르·모리·냐모·해피 share their ids).
    init?(_ companion: Companion) {
        guard let match = Species.find(companion.rawValue) else { return nil }
        self = match
    }

    /// Who a user can breed with: the friend they were handed plus open event friends.
    /// The test switch opens the whole family so every pair can be tried.
    static func owned(assigned: Companion?, unlockAll: Bool) -> [Species] {
        if unlockAll { return all }
        guard let assigned else { return [] }
        return Companion.owned(assigned: assigned).compactMap { Species($0) }
    }
}
