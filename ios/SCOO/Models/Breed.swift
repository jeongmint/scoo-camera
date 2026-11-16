import Foundation

/// A baby born from two parents. Parent A gives the shape and face, parent B the main color and one feature.
/// It grows into an adult (with a daisy) after the user takes enough photos.
struct Breed: Identifiable, Codable, Equatable {
    let id: UUID
    let parentA: String
    let parentB: String
    let born: Date
    /// The garden's photo count when it hatched; photos after this make it grow.
    let bornAtMoment: Int
    /// Where it came from, for babies that arrived in a glass bottle (e.g. "마포구"). Older records decode with nil.
    var origin: String? = nil
    /// True for babies taken in from a glass bottle.
    var adopted: Bool? = nil

    var key: String { "\(parentA)-\(parentB)" }
    /// Drawn baby, made with tools/breeding (`cutout --to-assets`).
    var babyAsset: String { "Breed-\(key)" }
    /// Optional drawn adult (`adult --to-assets`); otherwise the app pins the daisy itself.
    var adultAsset: String { "Adult-\(key)" }
    var mother: Species? { Species.find(parentA) }
    var father: Species? { Species.find(parentB) }
    var title: String { "\(mother?.name ?? parentA) × \(father?.name ?? parentB)" }

    func photosSinceBirth(moments: Int) -> Int { max(0, moments - bornAtMoment) }
    func isAdult(moments: Int) -> Bool { photosSinceBirth(moments: moments) >= BreedRules.photosToGrow }
    func photosLeft(moments: Int) -> Int { max(0, BreedRules.photosToGrow - photosSinceBirth(moments: moments)) }
}

enum BreedRules {
    /// Photos to take after hatching before a baby becomes an adult. Provisional.
    static let photosToGrow = 10

    enum Problem: Equatable {
        case missingParent, sameParent, notOwned

        var message: String {
            switch self {
            case .missingParent: "부모 A와 부모 B를 골라 주세요."
            case .sameParent: "서로 다른 두 친구를 골라 주세요."
            case .notOwned: "아직 만나지 않은 친구예요."
            }
        }
    }

    /// Why two picks cannot be bred, or nil when they can. Babies do not breed again yet.
    static func problem(a: String?, b: String?, owned: [Species]) -> Problem? {
        guard let a, let b else { return .missingParent }
        if a == b { return .sameParent }
        let ids = Set(owned.map(\.id))
        guard ids.contains(a), ids.contains(b) else { return .notOwned }
        return nil
    }
}
