import Foundation
import CoreGraphics

/// Friends that can be photographed together with the user ("같이 찍기").
/// The picked friend floats on the viewfinder and is composited into the saved photo
/// at the same spot, so what the user sees is what they get.
enum Companion: String, CaseIterable, Codable, Identifiable {
    case nyamo, happy, kuru, gwiyo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nyamo: "냐모"
        case .happy: "해피"
        case .kuru: "쿠르"
        case .gwiyo: "귀요"
        }
    }

    /// Name of the image set in Assets.xcassets.
    var assetName: String { "Companion-\(rawValue)" }

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
