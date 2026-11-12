import Foundation

/// Viewport-independent placement. Insets keep Mori away from camera controls.
struct MoriPlacement: Equatable {
    var x: Double
    var y: Double

    static let initial = MoriPlacement(x: 0.5, y: 0.74)

    func clamped(width: Double, height: Double, top: Double, bottom: Double, radius: Double) -> MoriPlacement {
        guard width > 0, height > 0 else { return .initial }
        let horizontal = min(width / 2, radius + 12)
        let lower = min(height / 2, top + radius + 16)
        let upper = max(lower, height - bottom - radius - 20)
        return MoriPlacement(
            x: min(max(x.isFinite ? x : Self.initial.x, horizontal / width), 1 - horizontal / width),
            y: min(max(y.isFinite ? y : Self.initial.y, lower / height), upper / height)
        )
    }
}
