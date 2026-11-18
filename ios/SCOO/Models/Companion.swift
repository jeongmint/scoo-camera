import Foundation
import CoreGraphics

/// Any character can float in Mori's place and be photographed together with the user ("같이 찍기"):
/// the picked character's image is composited into the saved photo at the same spot and size.
extension Species {
    /// Event friends open to everyone in the test build (the snowman); empty this list when the event ends.
    static let openEvents = ["happy"]
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
