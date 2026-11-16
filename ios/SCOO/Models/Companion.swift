import Foundation
import CoreGraphics

/// Friends that can be photographed together with the user ("같이 찍기").
/// The picked friend stands in the viewfinder and is composited into the saved photo
/// at the same spot, so what the user sees is what they get.
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

    // MARK: Where they stand

    /// Center of the friend as a fraction of the frame (left of Mori's default spot, above the controls).
    static let center = CGPoint(x: 0.21, y: 0.74)
    /// Width of the friend as a fraction of the frame width. The image is square.
    static let widthRatio: CGFloat = 0.30

    /// Frame of the friend inside a canvas of the given size.
    static func frame(in size: CGSize) -> CGRect {
        let width = size.width * widthRatio
        return CGRect(x: size.width * center.x - width / 2, y: size.height * center.y - width / 2,
                      width: width, height: width)
    }
}
