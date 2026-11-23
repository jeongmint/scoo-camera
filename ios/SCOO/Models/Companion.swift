import Foundation
import CoreGraphics

/// Any character can float in Mori's place and be photographed together with the user ("같이 찍기"):
/// the picked character's image is composited into the saved photo at the same spot and size.
extension Species {
    /// The seasonal friend open to everyone right now in the test build (해피 in winter, 보미 in spring,
    /// 소르 in summer, 도토 in autumn). Return [] to stop handing them out.
    static func openEvents(at date: Date = Date()) -> [String] {
        let season = Season.of(date)
        return all.filter { $0.season == season }.map(\.id)
    }
    /// The regular characters (everything but event friends).
    static var regulars: [Species] { all.filter { !$0.isEvent } }
    var menuTitle: String { isEvent ? "\(name) · 이벤트" : name }
}

/// Where the floating friend sits, independent of screen or photo size: its center as a fraction of the frame
/// and its width as a fraction of the frame width. The friend's image is square.
struct CompanionSpot: Equatable {
    var center: CGPoint
    var width: CGFloat

    /// Width used when the on-screen size is not known (imported photos).
    static let defaultWidth: CGFloat = 0.24

    /// The square the friend occupies inside a canvas of the given size.
    func frame(in size: CGSize) -> CGRect {
        let side = size.width * width
        return CGRect(x: size.width * center.x - side / 2, y: size.height * center.y - side / 2, width: side, height: side)
    }
}

/// Who floats on the camera in Mori's place: a friend or a bred baby (nil = 기본 모리).
/// Stored in UserDefaults "companion" as the species id, or "baby:" + the baby's id.
enum Floater: Equatable {
    case friend(Species)
    case baby(Breed)

    static let babyPrefix = "baby:"

    static func tag(_ baby: Breed) -> String { babyPrefix + baby.id.uuidString }

    /// The baby a stored tag points at, if it is a baby tag.
    static func babyID(_ raw: String) -> UUID? {
        guard raw.hasPrefix(babyPrefix) else { return nil }
        return UUID(uuidString: String(raw.dropFirst(babyPrefix.count)))
    }

    /// Resolves a stored tag against what this user has now; nil (기본 모리) when it left.
    static func resolve(_ raw: String, owns: (String) -> Bool, babies: [Breed]) -> Floater? {
        if let id = babyID(raw) { return babies.first { $0.id == id }.map(Floater.baby) }
        guard let species = Species.find(raw), owns(species.id) else { return nil }
        return .friend(species)
    }

    var tag: String {
        switch self {
        case .friend(let species): return species.id
        case .baby(let baby): return Floater.tag(baby)
        }
    }

    var name: String {
        switch self {
        case .friend(let species): return species.name
        case .baby(let baby): return baby.name
        }
    }

    var species: Species? {
        if case .friend(let species) = self { return species }
        return nil
    }
    var baby: Breed? {
        if case .baby(let baby) = self { return baby }
        return nil
    }
}
