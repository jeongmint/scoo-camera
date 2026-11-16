import Foundation
import CoreGraphics

/// Friends that can be photographed together with the user ("같이 찍기").
/// The picked friend takes Mori's place as the floating shutter and is composited into the saved photo
/// at the same spot and size, so what the user sees is what they get.
enum Companion: String, CaseIterable, Codable, Identifiable {
    case gwiyo, kuru, mori, nyamo, happy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gwiyo: "귀요"
        case .kuru: "쿠르"
        case .mori: "모리"
        case .nyamo: "냐모"
        case .happy: "해피"
        }
    }

    /// Event friends (the snowman) are not part of the random draw.
    var isEvent: Bool { self == .happy }
    var menuTitle: String { isEvent ? "\(title) · 이벤트" : title }

    /// Name of the image set in Assets.xcassets.
    var assetName: String { "Companion-\(rawValue)" }

    // MARK: Who a user gets

    /// Every user is handed exactly one of these at random.
    static var regulars: [Companion] { allCases.filter { !$0.isEvent } }

    /// Event friends that are open to everyone. The test build lets users hold the snowman
    /// together with their own friend; empty this list when the event ends.
    static let openEvents: [Companion] = [.happy]

    static func assign<G: RandomNumberGenerator>(using generator: inout G) -> Companion {
        regulars.randomElement(using: &generator) ?? .mori
    }

    static func assign() -> Companion {
        var generator = SystemRandomNumberGenerator()
        return assign(using: &generator)
    }

    /// The user's own friend first, then any open event friends.
    static func owned(assigned: Companion) -> [Companion] {
        [assigned] + openEvents.filter { $0 != assigned }
    }
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
