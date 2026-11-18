import Foundation
import CoreGraphics

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
    /// Set when a parent was itself a bred baby (재교배). Older records decode with nil.
    /// The species whose shape and daisy spot the baby inherits (parent A's root), and whose color (parent B's).
    var shapeA: String? = nil
    var colorB: String? = nil
    /// Names shown for bred parents, and their picture keys (to draw the new baby from).
    var nameA: String? = nil
    var nameB: String? = nil
    var artA: String? = nil
    var artB: String? = nil
    /// 1 for a baby of two species, 2 when a parent was a bred baby, and so on.
    var generation: Int? = nil

    var key: String { "\(parentA)-\(parentB)" }
    /// Drawn baby, made with tools/breeding (`cutout --to-assets`).
    var babyAsset: String { "Breed-\(key)" }
    /// Optional drawn adult (`adult --to-assets`); otherwise the app pins the daisy itself.
    var adultAsset: String { "Adult-\(key)" }
    var mother: Species? { Species.find(shapeA ?? parentA) }
    var father: Species? { Species.find(colorB ?? parentB) }
    var title: String { "\(nameA ?? mother?.name ?? parentA) × \(nameB ?? father?.name ?? parentB)" }
    /// How this baby is named when it becomes a parent itself.
    var parentID: String { "b_" + id.uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(12) }

    func stage(moments: Int) -> GrowthStage { GrowthStage.of(photos: photosSinceBirth(moments: moments)) }

    func photosSinceBirth(moments: Int) -> Int { max(0, moments - bornAtMoment) }
    func isAdult(moments: Int) -> Bool { photosSinceBirth(moments: moments) >= BreedRules.photosToGrow }
    func photosLeft(moments: Int) -> Int { max(0, BreedRules.photosToGrow - photosSinceBirth(moments: moments)) }
}

/// 성장 3단계: a baby grows with the photos taken after it hatched, and blooms (gets its daisy) at the end.
enum GrowthStage: Int, Comparable {
    case baby, growing, bloom

    var title: String {
        switch self {
        case .baby: return "아기"
        case .growing: return "성장"
        case .bloom: return "만개"
        }
    }

    /// How big the portrait is drawn at this stage.
    var scale: CGFloat {
        switch self {
        case .baby: return 0.78
        case .growing: return 0.9
        case .bloom: return 1
        }
    }

    static func of(photos: Int) -> GrowthStage {
        if photos >= BreedRules.photosToGrow { return .bloom }
        if photos >= BreedRules.photosToGrowing { return .growing }
        return .baby
    }

    /// Photos still needed for the next stage (0 once in bloom).
    static func photosToNext(after photos: Int) -> Int {
        switch of(photos: photos) {
        case .baby: return BreedRules.photosToGrowing - photos
        case .growing: return BreedRules.photosToGrow - photos
        case .bloom: return 0
        }
    }

    static func < (lhs: GrowthStage, rhs: GrowthStage) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Someone who can be a parent: a species, or a bred baby in bloom (재교배).
struct BreedParent: Identifiable, Equatable {
    let id: String
    let name: String
    /// The species the shape comes from, and the species the color comes from.
    let shape: String
    let color: String
    /// The bred parent's picture key, nil for a species.
    let art: String?
    let generation: Int

    init(_ species: Species) {
        id = species.id
        name = species.name
        shape = species.id
        color = species.id
        art = nil
        generation = 0
    }

    init(_ breed: Breed) {
        id = breed.parentID
        name = breed.title
        shape = breed.shapeA ?? breed.parentA
        color = breed.colorB ?? breed.parentB
        art = breed.key
        generation = breed.generation ?? 1
    }

    var isBreed: Bool { art != nil }
    var species: Species? { Species.find(shape) }
}

enum BreedRules {
    /// Photos to take after hatching before a baby becomes an adult. Provisional.
    static let photosToGrow = 10
    /// Photos after hatching to reach the middle stage (성장).
    static let photosToGrowing = 5
    /// Bred babies can breed again up to this generation.
    static let maxGeneration = 3

    enum Problem: Equatable {
        case missingParent, sameParent, notOwned, tooDeep

        var message: String {
            switch self {
            case .missingParent: "부모 A와 부모 B를 골라 주세요."
            case .sameParent: "서로 다른 두 친구를 골라 주세요."
            case .notOwned: "아직 만나지 않은 친구예요."
            case .tooDeep: "\(BreedRules.maxGeneration)세대까지만 교배할 수 있어요."
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

    /// The same check for parents that may be bred babies in bloom.
    static func problem(a: BreedParent?, b: BreedParent?, available: [BreedParent]) -> Problem? {
        guard let a, let b else { return .missingParent }
        if a.id == b.id { return .sameParent }
        let ids = Set(available.map(\.id))
        guard ids.contains(a.id), ids.contains(b.id) else { return .notOwned }
        if max(a.generation, b.generation) + 1 > maxGeneration { return .tooDeep }
        return nil
    }

    /// Who can be a parent now: the species a user has, then their babies in bloom.
    static func parents(species: [Species], breeds: [Breed], moments: Int) -> [BreedParent] {
        species.map(BreedParent.init) + breeds.filter { $0.stage(moments: moments) == .bloom }.map(BreedParent.init)
    }
}
